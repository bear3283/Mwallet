//
//  CompleteAddTravelView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/17.
//

import PhotosUI
import SwiftUI

struct CompleteAddTravelView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mainVM: MainViewModel
    @ObservedObject var viewModel = CompleteAddTravelViewModel()
    @ObservedObject var addViewModel: AddTravelViewModel
    @ObservedObject var memberViewModel: AddMemberViewModel
    @Binding var travelID: UUID
    @State var travelNM: String
    @State var participantArr: [String]
    @State var selectedTravel: [Travel]?

    // 여행 대표 사진. 고르면 카드 배경이 되고 여행 상세 머리말에도 쓰인다.
    @State private var pickedCover: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var isLoadingCover = false

    var body: some View {
        VStack(spacing: 0) {
            
            Spacer()
            
            Text("여행 생성 완료 !")
                .font(.title3)
                .padding(.bottom, 21)
            
            travelSquareView
                .padding(.bottom, 100)
            
            Spacer()
            
            HStack {
                MediumButtonStroke(title: "여행 확인하기", action: {
                    // 선택값 초기화
                    applyEdits()
                    viewModel.saveTravel()
                    NavigationUtil.popToRootView()
                    addViewModel.startDate = Date()
                    addViewModel.endDate = nil
                })
                
                MediumButtonActive(title: "지출 기록하기", action: {
                    applyEdits()
                    viewModel.saveTravel()
                    NavigationUtil.popToRootView()
                    mainVM.navigationToRecordView()
                })
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchTravel()
            self.selectedTravel = viewModel.filterTravelByID(selectedTravelID: travelID)
            self.travelNM = memberViewModel.travelName ?? "제목 미정"
            self.participantArr = memberViewModel.participantArr ?? ["me"]
        }
        .onAppear(perform: UIApplication.shared.hideKeyboard)
        .onChange(of: pickedCover) { _, item in loadCover(item) }
        .navigationTitle("새로운 여행 생성")
        .navigationBarBackButtonHidden(true)
    }
    
    // 고른 값을 여행에 옮긴다. 두 버튼이 같은 일을 하므로 한곳에 모은다.
    private func applyEdits() {
        selectedTravel?.first?.name = travelNM
        selectedTravel?.first?.participants = participantArr
        selectedTravel?.first?.coverImageData = coverImageData
        mainVM.selectedTravel = selectedTravel?.first
    }

    // 원본을 그대로 넣으면 건당 몇 MB 라 저장소가 급격히 커지고
    // CloudKit 레코드 제한에도 걸린다. 영수증 사진과 같은 규격으로 줄인다.
    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingCover = true
        Task {
            let raw = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                if let raw { coverImageData = ReceiptImageProcessor.process(raw) }
                isLoadingCover = false
            }
        }
    }

    // 고른 사진이 있으면 그것을, 없으면 기본 이미지를 쓴다.
    @ViewBuilder
    private var coverBackground: some View {
        Group {
            if let coverImageData, let image = UIImage(data: coverImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("DefaultImage")
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 243, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 15.16129))
        // 날짜 글씨가 사진 위에서도 읽히도록 아래쪽을 눌러 준다.
        .overlay(
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45)],
                           startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 15.16129))
        )
    }

    private var coverPickerButton: some View {
        // PhotosPicker 의 label 클로저는 메인 액터에 묶여 있지 않다.
        // 화면 상태를 안에서 읽지 않도록 값을 미리 뽑아 둔다.
        let icon = coverImageData == nil ? "photo" : "arrow.triangle.2.circlepath"
        let title = pickerTitle

        return PhotosPicker(selection: $pickedCover, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption2)
            .foregroundStyle(Color.mainAccent)
        }
        .disabled(isLoadingCover)
    }

    private var pickerTitle: String {
        if isLoadingCover { return "불러오는 중…" }
        return coverImageData == nil ? "대표 사진 고르기" : "사진 바꾸기"
    }

    private var travelSquareView: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 243, height: 176)
                    .background(coverBackground)

                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            
                            Text(viewModel.dateToString(in: selectedTravel?.first?.startDate ?? Date()) + " ~")
                            
                            if let endDate = selectedTravel?.first?.endDate {
                                Text(endDate, formatter: PreviousTravelViewModel.dateFormatter)
                            } else {
                                Text("미정")
                            }
                        }
                        .font(.custom(FontsManager.WantedSans.medium, size: 20))
                        .padding(.top, 90)
                        .padding(.leading, 16)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.75))
                        
                        Spacer()
                    }
                    .frame(width: 243, height: 176)
                    .padding(16)
                }
            }
            .frame(width: 243, height: 176)

            coverPickerButton
                .padding(.top, 12)

            HStack {
                Spacer()
                
                TextField(String(viewModel.travelName ?? ""), text: $travelNM)
                    .modifier(ClearTextFieldButton(text: $travelNM))
                    .font(.display1)
                    .textFieldStyle(CustomTextFieldStyle())
                    .onChange(of: travelNM) { _, newValue in
                        let maxLengthInKorean = 18
                        let maxLengthInEnglish = 28
                        
                        let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
                        let isEnglish = newValue.rangeOfCharacter(from: characterSet.inverted) == nil
                        
                        let maxLength = isEnglish ? maxLengthInEnglish : maxLengthInKorean
                        
                        if newValue.count > maxLength {
                            travelNM = String(newValue.prefix(maxLength))
                        }
                    }
                    .layoutPriority(-1)
                
                Spacer()
            }
            .padding(.top, 20)
            .frame(width: 243)
        }
    }
    
    struct ClearTextFieldButton: ViewModifier {
        
        @Binding var text: String
        
        public func body(content: Content) -> some View {
            ZStack(alignment: .trailing) {
                content
                
                if !text.isEmpty || text.isEmpty {
                    Button {
                        self.text = ""
                    } label: {
                        Image("xmark_circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .padding(.trailing, 8)
                    }
                }
            }
        }
    }
    
    struct CustomTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding(10)
                .foregroundColor(.black)
                .frame(height: 32)
                .background(Color.gray100)
                .cornerRadius(6)
        }
    }
}

// #Preview {
//     CompleteAddTravelView()
// }
