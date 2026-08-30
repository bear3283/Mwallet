//
//  AddMemberView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/14.
//

import SwiftUI

struct AddMemberView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSelectedAlone = true
    @State private var isSelectedTogether = false
    
    @ObservedObject private var viewModel = AddMemberViewModel()
    @ObservedObject var addViewModel: AddTravelViewModel
    
    @State var participantArr: [String]
    
    @State var travelName: String?
    @State var travelID = UUID()
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @State private var isBackButton = false
    @State var isDisappear = false

    var body: some View {
        VStack {
            
            headerView
                .padding(.bottom, 45)
            
            AddMemberSelectBox(isSelectedAlone: $isSelectedAlone,
                                       isSelectedTogether: $isSelectedTogether)
                .padding(.bottom, 12)
            
            AddMemberTogetherSection(isSelectedTogether: $isSelectedTogether,
                                             participantArr: $participantArr)
            
            Spacer()
            
            doneButton
            
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            isBackButton = false
        }
        .onAppear(perform: UIApplication.shared.hideKeyboard)
        .navigationDestination(isPresented: $isDisappear) {
            
            CompleteAddTravelView(addViewModel: addViewModel,
                                  memberViewModel: viewModel,
                                  travelID: $travelID,
                                  travelNM: travelName ?? "", 
                                  participantArr: participantArr)
        }
        .navigationTitle("새로운 여행 생성")
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            
            HStack {
                Text("이 여행은 누구와 함께하나요?")
                    .font(.title3)
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, 10)
            
            HStack {
                Text("가계부에 표시할 여행 인원의 이름을 알려주세요. ")
                    .font(.subhead2_2)
                    .foregroundStyle(Color.gray300)
                
                Spacer()
            }
            .padding(.leading, 20)
        }
        .padding(.top, 36)
    }

    private var doneButton: some View {
        HStack {
            Spacer()
            
            if isSelectedTogether == true && participantArr.count == 1 && participantArr[0] == "" {
                DoneButtonUnactive(title: String(localized: "완료"), action: {
                    
                })
                .disabled(true)
                
            } else {
                DoneButtonActive(title: String(localized: "완료"), action: {
                    isBackButton = false
                    if !isBackButton {
                        
                        viewModel.startDate = startDate?.local000()
                        viewModel.endDate = endDate?.local235959()
                        
                        // 1. 빈칸 제거
                        participantArr = viewModel.filterEmptyStrings(participantArr)
                        // 2. '나' 제거
                        participantArr = viewModel.filterMeFromStrings(participantArr)
                        // 3. 중복 제거
                        participantArr = viewModel.filterDuplicates(participantArr)
                        
                        if participantArr.count == 1 && self.isSelectedTogether == true {
                            viewModel.travelName = String(localized: "\(participantArr[0])님과의 여행")
                            viewModel.participantArr = participantArr
                        } else if participantArr.count == 0 && self.isSelectedAlone == true {
                            viewModel.participantArr = participantArr
                            viewModel.travelName = String(localized: "나의 여행")
                        } else if participantArr.count == 0 {
                            viewModel.travelName = String(localized: "나의 여행")
                            viewModel.participantArr = participantArr
                        } else {
                            viewModel.travelName = String(localized: "\(participantArr[0]) 외 \(participantArr.count)명의 여행")
                            viewModel.participantArr = participantArr
                        }
                        
                        viewModel.travelID = travelID
                        viewModel.addTravel()
                        viewModel.saveTravel()
                        viewModel.updateSelectedTravels()
                    }
                    isDisappear = true
                })
            }
        }
    }
    
    var backButton: some View {
        Button {
            isBackButton = true
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .imageScale(.large)
                .foregroundColor(Color.black)
        }
    }
}

// #Preview {
//     AddMemberView()
// }
