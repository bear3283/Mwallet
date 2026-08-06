//
//  ManualRecordView.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/16/23.
//

import OSLog
import SwiftUI
import CoreLocation

struct ManualRecordView: View {
    @StateObject var viewModel = ManualRecordViewModel()
    @EnvironmentObject var mainVM: MainViewModel
    @Environment(\.dismiss) var dismiss
    let viewContext = PersistenceController.shared.container.viewContext
    let exchangeHandler = ExchangeRateHandler.shared
    
    let given_wantToActivateAutoSaveTimer: Bool
    let given_payAmount: Double
    let given_info: String?
    let given_infoCategory: ExpenseInfoCategory
    let given_paymentMethod: PaymentMethod
    let given_soundRecordFileName: URL?
    
    var body: some View {
        ZStack {
            Color(.white)
                .ignoresSafeArea()
            
            // 입력 블록을 화면 세로 가운데에 둔다.
            // 예전에는 위 50 / 아래 150 짜리 고정 여백이라 내용이 아래로 처져 보였다.
            // 내용이 화면보다 길어지면 minHeight 를 넘겨 평소처럼 스크롤된다.
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        payAmountBlockView
                        Spacer()
                            .frame(height: 64)
                        inSentencePropertyBlockView
                        Divider()
                            .foregroundStyle(.gray200)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 20)
                        notInSentencePropertyBlockView
                    }
                    // 하단 저장 버튼이 마지막 항목을 가리지 않도록 비워 둔다.
                    .padding(.bottom, 120)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    autoSaveTextView
                    doneTextView
                }
                saveButtonView
            }
            .ignoresSafeArea()
            
            Color(.white)
                .opacity(0.0000001)
                .allowsHitTesting(viewModel.savingIsDone)
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.white, for: .navigationBar)
        .navigationTitle("기록 완료")
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButtonView)
        .sheet(isPresented: $viewModel.travelChoiceModalIsShown) {
            TravelChoiceInRecordModal(chosenTravel: $mainVM.chosenTravelInManualRecord, updateIsSameDataStateClosure: { return true }, isSameData: .constant(true))
                .presentationDetents([.height(289 - 34)])
        }
        .sheet(isPresented: $viewModel.categoryChoiceModalIsShown) {
            CategoryChoiceModal(chosenCategory: $viewModel.category)
                .presentationDetents([.height(289 - 34)])
        }
        .sheet(isPresented: $viewModel.countryChoiceModalIsShown) {
            CountryChoiceModal(chosenCountry: $viewModel.country, countryIsModified: $viewModel.countryIsModified, countryArray: viewModel.otherCountryCandidateArray, currentCountry: viewModel.currentCountry)
                .presentationDetents([.height(289 - 34)])
        }
        .sheet(isPresented: $viewModel.dateChoiceModalIsShown) {
            DateChoiceModal(date: $viewModel.payDate, startDate: mainVM.chosenTravelInManualRecord?.startDate ?? Date.distantPast, endDate: mainVM.chosenTravelInManualRecord?.endDate ?? Date.distantFuture)
                .presentationDetents([.height(289 - 34)])
        }
        .alert(Text("저장하지 않고 나가기"), isPresented: $viewModel.backButtonAlertIsShown) {
            Button {
                viewModel.backButtonAlertIsShown = false
            } label: {
                Text("취소")
            }
            Button {
                dismiss()
                viewModel.backButtonAlertIsShown = false
            } label: {
                Text("나가기")
            }
        } message: {
            Text("현재 화면의 정보를 모두 초기화하고 이전 화면으로 돌아갈까요?")
        }
        .onAppear {
            // 수기 입력에도 결제 위치가 저장되므로 이 화면에서 위치 권한을 요청한다.
            DateGapHandler.shared.requestAuthorization()

            viewModel.wantToActivateAutoSaveTimer = given_wantToActivateAutoSaveTimer
            
            if given_wantToActivateAutoSaveTimer { // 녹음 버튼으로 진입한 경우
                                
                if given_payAmount == -1 {
                    viewModel.visiblePayAmount = ""
                } else {
                    if abs((given_payAmount - floor(given_payAmount))) < 0.0000001 {
                        viewModel.visiblePayAmount = String(format: "%.0f", given_payAmount)
                    } else {
                        viewModel.visiblePayAmount = String(given_payAmount)
                    }
                }
                
                viewModel.visibleInfo = given_info == nil ? "" : given_info!
                viewModel.category = given_infoCategory
                viewModel.paymentMethod = given_paymentMethod
                
                viewModel.soundRecordFileName = given_soundRecordFileName
            }
            
            DispatchQueue.main.async {
                MainViewModel.shared.chosenTravelInManualRecord = MainViewModel.shared.selectedTravel
            }
            
            // MARK: - timer
            
            if viewModel.wantToActivateAutoSaveTimer && (viewModel.payAmount != -1 || viewModel.info != nil) {
                viewModel.secondCounter = 8
                // Timer 는 Sendable 이 아니라 클로저 파라미터를 격리 블록 안으로
                // 넘길 수 없다. VM 에 저장해 둔 참조로 무효화한다.
                viewModel.autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    // 메인 런루프에 걸린 타이머라 항상 메인에서 깨어난다.
                    // 클로저 타입은 @Sendable 이라 컴파일러가 그걸 알 수 없어 명시한다.
                    MainActor.assumeIsolated {
                        guard let secondCounter = viewModel.secondCounter else { return }

                        guard secondCounter <= 1 else {
                            viewModel.secondCounter = secondCounter - 1
                            return
                        }

                        viewModel.secondCounter = nil
                        viewModel.autoSaveTimer?.invalidate()

                        guard viewModel.payAmount != -1 || viewModel.info != nil else { return }

                        viewModel.save()
                        if mainVM.chosenTravelInManualRecord != nil {
                            mainVM.selectedTravel = mainVM.chosenTravelInManualRecord
                        }
                        viewModel.deleteUselessAudioFiles()
                        viewModel.savingIsDone = true
                        viewModel.afterSavingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                            MainActor.assumeIsolated {
                                dismiss()
                                viewModel.afterSavingTimer?.invalidate()
                            }
                        }
                    }
                }
            }
            
            // MARK: - get location
            
            viewModel.getLocation {
                viewModel.setInitialCurrency()
            }
        }
        .onAppear(perform: UIApplication.shared.hideKeyboard)
        .onDisappear {
            viewModel.autoSaveTimer?.invalidate()
            viewModel.secondCounter = nil
        }
    }
    
    private var backButtonView: some View {
        Button {
            viewModel.autoSaveTimer?.invalidate()
            viewModel.secondCounter = nil
            viewModel.backButtonAlertIsShown = true
        } label: {
            Image(systemName: "chevron.left")
                .imageScale(.large)
                .foregroundColor(Color.black)
        }
    }
    
    // 원화 환산은 참고값이다. 원화로 적고 있으면 같은 숫자라 보여 줄 이유가 없다.
    private var convertedAmountText: String? {
        let code = CurrencyInfoModel.shared.currencyResult[viewModel.currency]?.isoCodeNm
        guard code != ExpenseCode.baseCurrency else { return nil }

        guard viewModel.payAmount != -1,
              let formatted = viewModel.payAmountInWon.getStringFraction0() else {
            return "환산 전"
        }
        return "≈ \(formatted)원"
    }

    private var payAmountBlockView: some View {
        HStack {
            Spacer()
                .frame(width: 20)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Text(viewModel.visiblePayAmount == "" ? "금액 입력" : viewModel.visiblePayAmount + "  ")
                                .lineLimit(1)
                                .font(.display4)
                                .hidden()
                            
                            TextField("금액 입력", text: $viewModel.visiblePayAmount)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.black)
                                .font(.display4)
                                .keyboardType(.decimalPad)
                                .layoutPriority(-1)
                                .tint(.mainAccent)
                                .onTapGesture {
                                    viewModel.autoSaveTimer?.invalidate()
                                    viewModel.secondCounter = nil
                                }
                        }
                        
                        ZStack {
                            Picker("화폐", selection: $viewModel.currency) {
                                ForEach(viewModel.currencyCandidateArray, id: \.self) { currency in
                                    Text((CurrencyInfoModel.shared.currencyResult[currency]?.koreanNm ?? "알 수 없음") + " " + (CurrencyInfoModel.shared.currencyResult[currency]?.symbol ?? "-"))
                                }
                            }
                            .onTapGesture {
                                viewModel.autoSaveTimer?.invalidate()
                                viewModel.secondCounter = nil
                            }
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.gray100)
                                    .layoutPriority(-1)
                                // 통화는 금액을 읽는 단위일 뿐이라 조용히 둔다.
                                // display2 로 두면 금액(display4)과 크기가 붙어 경쟁한다.
                                Text((CurrencyInfoModel.shared.currencyResult[viewModel.currency]?.koreanNm ?? "알 수 없음") + " " + (CurrencyInfoModel.shared.currencyResult[viewModel.currency]?.symbol ?? "-"))
                                    .foregroundStyle(.gray400)
                                    .font(.subhead2_1)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    
                    if let convertedAmountText {
                        Text(convertedAmountText)
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
                Spacer()
                
                Group {
                    if viewModel.soundRecordFileName == nil {
                        ZStack {
                            Circle()
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .shadow(color: .gray200, radius: 3)
                            
                            Circle()
                                .strokeBorder(.gray200, lineWidth: 1)
                            
                            HStack(spacing: 3) {
                                Capsule()
                                    .foregroundStyle(.gray200)
                                    .frame(width: 1.5, height: 9)
                                Capsule()
                                    .foregroundStyle(.gray200)
                                    .frame(width: 1.5, height: 14)
                                Capsule()
                                    .foregroundStyle(.gray200)
                                    .frame(width: 1.5, height: 19)
                                Capsule()
                                    .foregroundStyle(.gray200)
                                    .frame(width: 1.5, height: 14)
                                Capsule()
                                    .foregroundStyle(.gray200)
                                    .frame(width: 1.5, height: 9)
                            }
                        }
                    } else {
                        if viewModel.playingRecordSound {
                            PlayngRecordSoundView()
                        } else {
                            ZStack {
                                Circle()
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .gray200, radius: 3)
                                
                                Circle()
                                    .strokeBorder(.gray300, lineWidth: 1)
                                
                                HStack(spacing: 3) {
                                    Capsule()
                                        .foregroundStyle(.black)
                                        .frame(width: 1.5, height: 9)
                                    Capsule()
                                        .foregroundStyle(.black)
                                        .frame(width: 1.5, height: 14)
                                    Capsule()
                                        .foregroundStyle(.black)
                                        .frame(width: 1.5, height: 19)
                                    Capsule()
                                        .foregroundStyle(.black)
                                        .frame(width: 1.5, height: 14)
                                    Capsule()
                                        .foregroundStyle(.black)
                                        .frame(width: 1.5, height: 9)
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.gray200)
                .frame(width: 54, height: 54)
                .onTapGesture {
                    viewModel.autoSaveTimer?.invalidate()
                    viewModel.secondCounter = nil
                    
                    if viewModel.soundRecordFileName != nil {
                        if !viewModel.playingRecordSound {
                            if let soundRecordFileName = viewModel.soundRecordFileName {
                                viewModel.startPlayingAudio(url: soundRecordFileName)
                                viewModel.playingRecordSound = true
                            }
                        } else {
                            viewModel.stopPlayingAudio()
                            viewModel.playingRecordSound = false
                        }
                    }
                }
            }
            Spacer()
                .frame(width: 20)
        }
    }
    
    private var inSentencePropertyBlockView: some View {
        HStack {
            Spacer()
                .frame(width: 20)
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        
                        Text("소비 내역")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    ZStack(alignment: .leading) {
//                        높이 설정용 히든 뷰
                        ZStack {
                            Text("금")
                                .foregroundStyle(.black)
                                .font(.subhead2_1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .hidden()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .foregroundStyle(.gray100)
                            .layoutPriority(-1)
                        
                        TextField("소비 내역을 입력해주세요", text: $viewModel.visibleInfo)
                            .lineLimit(nil)
                            .foregroundStyle(.black)
                            .font(.body3)
                            .tint(.mainAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .onTapGesture {
                                viewModel.autoSaveTimer?.invalidate()
                                viewModel.secondCounter = nil
                            }
                    }
                }
                
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        Text("카테고리")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    Group {
                        ZStack {
                            // 높이 설정용 히든 뷰
                            ZStack {
                                Text("금")
                                    .foregroundStyle(.black)
                                    .font(.subhead2_1)
                                    .padding(.vertical, 6)
                            }
                            .hidden()
                            
                            HStack(spacing: 8) {
                                Image(viewModel.category.manualRecordImageString)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                Text(viewModel.category.visibleDescription)
                                    .foregroundStyle(.black)
                                    .font(.body3)
                            }
                        }
                        Spacer()
                        Image("manualRecordDownChevron")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .onTapGesture {
                        viewModel.autoSaveTimer?.invalidate()
                        viewModel.secondCounter = nil
                        viewModel.categoryChoiceModalIsShown = true
                    }
                    
                }
                
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        Text("결제 수단")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    
                    Group {
                        if viewModel.paymentMethod == .cash {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.black, lineWidth: 1.0)
                                    .layoutPriority(-1)
                                
                                Text("현금")
                                    .foregroundStyle(.black)
                                    .font(.subhead2_1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.gray200, lineWidth: 1.0)
                                    .layoutPriority(-1)
                                
                                Text("현금")
                                    .foregroundStyle(Color(0xbfbfbf)) // 색상 디자인 시스템 형식으로 고치기 ^^^
                                    .font(.subhead2_1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .onTapGesture {
                        viewModel.autoSaveTimer?.invalidate()
                        viewModel.secondCounter = nil
                        if viewModel.paymentMethod == .cash {
                            viewModel.paymentMethod = .unknown
                        } else {
                            viewModel.paymentMethod = .cash
                        }
                    }
                    
                    Spacer()
                        .frame(width: 6)
                    
                    Group {
                        if viewModel.paymentMethod == .card {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.black, lineWidth: 1.0)
                                    .layoutPriority(-1)
                                
                                Text("카드")
                                    .foregroundStyle(.black)
                                    .font(.subhead2_1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.gray200, lineWidth: 1.0)
                                    .layoutPriority(-1)
                                
                                Text("카드")
                                    .foregroundStyle(Color(0xbfbfbf)) // 색상 디자인 시스템 형식으로 고치기 ^^^
                                    .font(.subhead2_1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .onTapGesture {
                        viewModel.autoSaveTimer?.invalidate()
                        viewModel.secondCounter = nil
                        if viewModel.paymentMethod == .card {
                            viewModel.paymentMethod = .unknown
                        } else {
                            viewModel.paymentMethod = .card
                        }
                    }
                    
                    Spacer()
                }
            }
            Spacer()
                .frame(width: 20)
        }
    }
    
    private var notInSentencePropertyBlockView: some View {
        HStack {
            Spacer()
                .frame(width: 20)
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        Text("여행 제목")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    Group {
                        ZStack {
                            // 높이 설정용 히든 뷰
                            ZStack {
                                Text("금")
                                    .foregroundStyle(.black)
                                    .font(.subhead2_1)
                                    .padding(.vertical, 6)
                            }
                            .hidden()
                            
                            Text(mainVM.chosenTravelInManualRecord?.isUserCreated == true ? mainVM.chosenTravelInManualRecord?.name ?? "-" : "여행 선택")
                                .lineLimit(nil)
                                .foregroundStyle(mainVM.chosenTravelInManualRecord?.isUserCreated == true ? .black : .gray400)
                                .font(.subhead2_1)
                        }
                        Spacer()
                        
                        Image("manualRecordDownChevron")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .onTapGesture {
                        viewModel.autoSaveTimer?.invalidate()
                        viewModel.secondCounter = nil
                        viewModel.travelChoiceModalIsShown = true
                    }
                    
                }
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        Text("결제 인원")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            if viewModel.participantTupleArray.count > 0 {
                                ParticipantArrayView(participantTupleArray: $viewModel.participantTupleArray, autoSaveTimer: $viewModel.autoSaveTimer, secondCounter: $viewModel.secondCounter)
                            } else {
                                EmptyView()
                            }
                        }
                    }
                    .scrollIndicators(.never)

                }
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Spacer()
                            .frame(width: 116, height: 1)
                        Text("지출 일시")
                            .foregroundStyle(.gray300)
                            .font(.caption2)
                    }
                    Group {
                        ZStack {
                            // 높이 설정용 히든 뷰
                            Text("금")
                                .lineLimit(1)
                                .font(.subhead2_2)
                                .padding(.vertical, 6)
                                .hidden()
                            
                            Text(viewModel.payDate.toString(dateFormat: "yy.MM.dd(E) HH:mm"))
                                .foregroundStyle(.black)
                                .font(.subhead2_2)
                        }
                        Spacer()
                        
                        Image("manualRecordDownChevron")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .onTapGesture {
                        viewModel.autoSaveTimer?.invalidate()
                        viewModel.secondCounter = nil
                        viewModel.dateChoiceModalIsShown = true
                    }
                }
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            Spacer()
                                .frame(width: 116, height: 1)
                            Text("지출 위치")
                                .foregroundStyle(.gray300)
                                .font(.caption2)
                        }
                        Group {
                            ZStack {
                                // 높이 설정용 히든 뷰
                                Text("금")
                                    .lineLimit(1)
                                    .font(.subhead2_2)
                                    .padding(.vertical, 6)
                                    .hidden()
                                
                                HStack(spacing: 8) {
                                    ZStack {
                                        if viewModel.country != -1 {
                                            Image(CountryInfoModel.shared.countryResult[viewModel.country]?.flagString ?? "DefaultFlag")
                                                .resizable()
                                                .scaledToFit()
                                        } else {
                                            Image("DefaultFlag")
                                                .resizable()
                                                .scaledToFit()
                                        }
                                        
                                        Circle()
                                            .strokeBorder(.gray200, lineWidth: 1.0)
                                    }
                                    .frame(width: 24, height: 24)
                                    
                                    if !viewModel.countryIsModified {
                                        Text(viewModel.countryExpression + " " + viewModel.locationExpression)
                                            .foregroundStyle(.black)
                                            .font(.subhead2_2)
                                    } else {
                                        Text(viewModel.countryExpression)
                                            .foregroundStyle(.black)
                                            .font(.subhead2_2)
                                    }
                                    
                                }
                            }
                            Spacer()
                            Image("manualRecordDownChevron")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        .onTapGesture {
                            viewModel.autoSaveTimer?.invalidate()
                            viewModel.secondCounter = nil
                            viewModel.countryChoiceModalIsShown = true
                        }
                    }
                    
                    if viewModel.countryIsModified {
                        HStack(spacing: 0) {
                            ZStack(alignment: .leading) {
                                Spacer()
                                    .frame(width: 116, height: 1)
                                
                                Text(" ")
                                    .foregroundStyle(.gray300)
                                    .font(.caption2)
                            }
                            ZStack(alignment: .leading) {
                                //                        높이 설정용 히든 뷰
                                ZStack {
                                    Text("금")
                                        .foregroundStyle(.black)
                                        .font(.subhead2_1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
                                .hidden()
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.gray100)
                                    .layoutPriority(-1)
                                
                                TextField("상세 위치를 입력해주세요", text: $viewModel.locationExpression)
                                    .lineLimit(nil)
                                    .foregroundStyle(.black)
                                    .font(.body3)
                                    .tint(.mainAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .onTapGesture {
                                        viewModel.autoSaveTimer?.invalidate()
                                        viewModel.secondCounter = nil
                                    }
                            }
                        }
                    }
                }
                
            }
            Spacer()
                .frame(width: 20)
        }
    }
    
    private var autoSaveTextView: some View {
        Group {
            if let secondCounter = viewModel.secondCounter {
                if secondCounter > 0 && secondCounter <= 3 {
                    Text("\(secondCounter)초 후 자동 저장")
                        .foregroundStyle(.gray300)
                        .font(.body2)
                } else {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            Color(.white)
        }
    }
    
    private var doneTextView: some View {
        Group {
            if viewModel.savingIsDone {
                HStack(spacing: 6) {
                    Image("recordMainPinkCheck")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("저장되었습니다")
                        .foregroundStyle(.gray300)
                        .font(.body2)
                }
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            Color(.white)
        }
    }
    
    private var saveButtonView: some View {
        ZStack {
            LargeButtonActive(title: "저장하기") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.save()
                // 여행을 고르지 않았으면 기본함으로 돌려 둔다.
                mainVM.selectedTravel = mainVM.chosenTravelInManualRecord
                    ?? Travel.fetchDefault(in: viewContext)
                viewModel.deleteUselessAudioFiles()
                viewModel.savingIsDone = true
                viewModel.afterSavingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        dismiss()
                        viewModel.afterSavingTimer?.invalidate()
                    }
                }
            }
            .opacity((viewModel.payAmount != -1 || viewModel.info != nil) ? 1 : 0.0000001)
            .allowsHitTesting(viewModel.payAmount != -1 || viewModel.info != nil)
            
            LargeButtonUnactive(title: "저장하기") { }
                .opacity((viewModel.payAmount != -1 || viewModel.info != nil) ? 0.0000001 : 1)
                .allowsHitTesting(!(viewModel.payAmount != -1 || viewModel.info != nil))
        }
    }
}

struct ParticipantArrayView: View {
    @Binding var participantTupleArray: [(name: String, isOn: Bool)]
    @Binding var autoSaveTimer: Timer?
    @Binding var secondCounter: Int?
    
    let buttonCountInARow = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<((participantTupleArray.count - 1) / buttonCountInARow + 1), id: \.self) { rowNum in
                let diff = participantTupleArray.count - 1 - rowNum * buttonCountInARow
                if diff == 0 {
                    HStack(spacing: 6) {
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow)
                    }
                } else if diff == 1 {
                    HStack(spacing: 6) {
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow)
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow + 1)
                    }
                } else {
                    HStack(spacing: 6) {
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow)
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow + 1)
                        ParticipantToggleView(participantTupleArray: $participantTupleArray, autoSaveTimer: $autoSaveTimer, secondCounter: $secondCounter, index: rowNum *  buttonCountInARow + 2)
                    }
                }
            }
        }
    }
}

struct ParticipantToggleView: View {
    @Binding var participantTupleArray: [(name: String, isOn: Bool)]
    @Binding var autoSaveTimer: Timer?
    @Binding var secondCounter: Int?
    let index: Int
    
    var body: some View {
        if index < participantTupleArray.count {
            let tuple = participantTupleArray[index]
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(tuple.isOn ? Color(0x333333) : .gray100) // 색상 디자인 시스템 형식으로 고치기 ^^^
                    .layoutPriority(-1)
                
                // 높이 설정용 히든 뷰
                Text("금")
                    .lineLimit(1)
                    .font(.subhead2_2)
                    .padding(.vertical, 6)
                    .hidden()
                
                HStack(spacing: 4) {
                    if tuple.name == "나" {
                        Text("me")
                            .lineLimit(1)
                            .foregroundStyle(tuple.isOn ? .gray200 : .gray300)
                            .font(.subhead2_1)
                    }
                    Text(tuple.0)
                        .lineLimit(1)
                        .foregroundStyle(tuple.isOn ? .white : .gray300)
                        .font(.subhead2_2)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            .onTapGesture {
                autoSaveTimer?.invalidate()
                secondCounter = nil
                participantTupleArray[index].isOn.toggle()
            }
        } else {
            EmptyView()
        }
    }
}

struct PlayngRecordSoundView: View {
    
    @State var timer: Timer?
    @State var level = 0
    @State var flicker = true
    
    let stepLength = 0.5
    
    func levelUp() {
        level = (level + 1) % 3
    }
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .onAppear {
                    timer = Timer.scheduledTimer(withTimeInterval: stepLength, repeats: true) { _ in
                        MainActor.assumeIsolated { levelUp() }
                    }
                }
                .onDisappear {
                    timer?.invalidate()
                }
                .shadow(color: .mainAccent, radius: 3)
            
            Circle()
                .strokeBorder(.mainAccent, lineWidth: 1)
            
            HStack(spacing: 3) {
                Capsule()
                    .foregroundStyle(.mainAccent)
                    .frame(width: 1.5, height: level == 2 ? 10 : 7)
                Capsule()
                    .foregroundStyle(.mainAccent)
                    .frame(width: 1.5, height: level == 1 ? 15 : 12)
                Capsule()
                    .foregroundStyle(.mainAccent)
                    .frame(width: 1.5, height: level == 0 ? 20 : 17)
                Capsule()
                    .foregroundStyle(.mainAccent)
                    .frame(width: 1.5, height: level == 1 ? 15 : 12)
                Capsule()
                    .foregroundStyle(.mainAccent)
                    .frame(width: 1.5, height: level == 2 ? 10 : 7)
            }
            .animation(.bouncy(duration: stepLength * 1.25), value: level)
        }
    }
}

//    #Preview {
//        ManualRecordView()
//    }
