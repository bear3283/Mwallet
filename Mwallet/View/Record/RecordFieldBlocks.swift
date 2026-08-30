//
//  RecordFieldBlocks.swift
//  Mwallet
//
//  직접 기록 화면(ManualRecordView)의 세 덩어리.
//
//    금액   얼마를 어떤 통화로 썼나 · 녹음 다시 듣기
//    말     말로 채워지는 것들 — 소비 내역 · 카테고리 · 결제 수단
//    직접   말에 없어 직접 고르는 것들 — 여행 · 인원 · 일시 · 위치
//
//  한 화면 안에 있던 것을 세 벌로 나눴다. 셋은 서로를 부르지 않고 같은
//  뷰모델만 본다. 화면이 700줄을 넘기면 어디를 고쳐야 하는지 찾는 데
//  시간이 들고, 고친 자리가 다른 곳에 닿는지도 알기 어렵다.
//

import SwiftUI

// MARK: - 금액

struct RecordAmountBlock: View {

    @ObservedObject var viewModel: ManualRecordViewModel

    private var convertedAmountText: String? {
        let code = CurrencyInfoModel.shared.currencyResult[viewModel.currency]?.isoCodeNm
        guard code != ExpenseCode.baseCurrency else { return nil }

        guard viewModel.payAmount != -1,
              let formatted = viewModel.payAmountInWon.getStringFraction0() else {
            return String(localized: "환산 전")
        }
        return "≈ " + String(localized: "\(formatted)원")
    }

    var body: some View {
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
                                    Text(CurrencyInfoModel.shared.currencyResult[currency]?.displayLabel
                                         ?? String(localized: "알 수 없음"))
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
                                Text(CurrencyInfoModel.shared.currencyResult[viewModel.currency]?.displayLabel
                                     ?? String(localized: "알 수 없음"))
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
}

// MARK: - 말로 채워지는 항목

struct RecordSpokenFields: View {

    @ObservedObject var viewModel: ManualRecordViewModel

    var body: some View {
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
}

// MARK: - 직접 고르는 항목

struct RecordManualFields: View {

    @ObservedObject var viewModel: ManualRecordViewModel
    @EnvironmentObject var mainVM: MainViewModel

    var body: some View {
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
}
