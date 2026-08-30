//
//  AddTravelView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/10.
//

import SwiftUI

struct AddTravelView: View {
    
    @ObservedObject var viewModel = AddTravelViewModel(currentMonth: Date(), currentYear: Date())
    @Environment(\.dismiss) private var dismiss
    @State private var showStartModal = false
    @State private var showEndModal = false
    @State private var isButtonOn = false
   
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    
                    Spacer()
                    
                    AddTravelHeader(viewModel: viewModel,
                                    showStartModal: $showStartModal,
                                    showEndModal: $showEndModal)
                    
                    Spacer()
                    
                    VStack {
                        
                        TravelCalendar(viewModel: viewModel)
                        
                        Spacer()
                    }
                    .frame(width: UIScreen.main.bounds.size.width-40, height: 423)
                    .padding(20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .inset(by: 0.5)
                            .stroke(Color.gray200, lineWidth: 1)
                            .frame(width: UIScreen.main.bounds.size.width-40, height: 423)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        if viewModel.startDate != nil {
                            NextButtonActive(title: String(localized: "다음"), action: {
                                isButtonOn = true
                            })
                            .ignoresSafeArea()
                        } else {
                            NextButtonUnactive(title: String(localized: "다음"), action: {
                                
                            })
                            .disabled(true)
                            .ignoresSafeArea(edges: .bottom)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationDestination(isPresented: $isButtonOn) {
            AddMemberView(addViewModel: viewModel, participantArr: [""], startDate: $viewModel.startDate, endDate: $viewModel.endDate)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("새로운 여행 생성")
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
    }

    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .imageScale(.large)
                .foregroundColor(Color.black)
        }
    }
}

// #Preview {
//     AddTravelView()
// }
