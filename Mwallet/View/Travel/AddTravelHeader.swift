//
//  AddTravelHeader.swift
//  Mwallet
//
//  여행 만들기 화면의 윗부분. 이름·기간·국가를 받는다.
//
//  달력 위로 이어지는 입력 묶음이라 AddTravelView 에서 떼어 냈다.
//  날짜 모달을 여닫는 두 깃발만 밖에서 받는다.
//

import SwiftUI

struct AddTravelHeader: View {

    @ObservedObject var viewModel: AddTravelViewModel
    @Binding var showStartModal: Bool
    @Binding var showEndModal: Bool

    /// 모달이 열려 있는 동안 굴리는 날짜. 확인을 눌러야 뷰모델에 옮긴다.
    @State private var modalDate = Date()

    var body: some View {

        return VStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
        
                HStack {
                    Text("기간을 선택해주세요")
                        .font(.custom(FontsManager.WantedSans.semiBold, size: 24))
            
                    Spacer()
                }
                .padding(.bottom, 10)
        
                HStack {
                    Text("여행의 시작일과 종료일을 설정해주세요.")
                        .font(.custom(FontsManager.WantedSans.medium, size: 16))
                        .foregroundStyle(Color.gray300)
            
                    Spacer()
                }
        
                Spacer()
            }
            .padding(.horizontal, 20)
    
            Spacer()
    
            VStack {
                HStack {
                    HStack {
                        Text("시작일")
                            .font(.subhead1)
                        +
                        Text("*")
                            .font(.subhead1)
                            .foregroundStyle(Color.mainAccent)
                    }
            
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1)
                        .frame(width: 104, height: 1)
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [Color.mainAccent, viewModel.endDate != nil ? Color.mainAccent : Color.white]),
                                           startPoint: .leading, endPoint: .trailing)
                        )
            
                    Text("종료일")
                        .font(.subhead1)
                }
        
                HStack {
                    Button {
                        self.showStartModal = true
                    } label: {
                        ZStack {
            
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 132, height: 28, alignment: .leading)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .inset(by: 0.5)
                                        .stroke(viewModel.startDate != nil ? LinearGradient(gradient: Gradient(colors: [Color.mainAccent, Color.mainOrange]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.gray200, Color.gray200]), startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: viewModel.startDate != nil ? 2.0 : 1.0)
                                )
                    
                            HStack {
                                Text(viewModel.startDateToString(in: viewModel.startDate))
                                    .font(.custom(FontsManager.WantedSans.regular, size: 16))
                                    .foregroundStyle(Color.black)
                                    .padding(.leading, 20)
                                    .padding(.vertical, 6)
                        
                                Spacer()
                            }
                    
                        }
                    }
                    .sheet(isPresented: $showStartModal) {
                        datePickerModal(initial: viewModel.startDate) { picked in
                            showStartModal = false
                            viewModel.startDate = picked
                        }
                            .presentationDetents([.height(354), .height(354)])
                    }
            
                    Spacer()
            
                    Button {
                        self.showEndModal = true
                    } label: {
                        ZStack {
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 132, height: 28, alignment: .leading)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .inset(by: 0.5)
                                        .stroke(viewModel.endDate != nil ? LinearGradient(gradient: Gradient(colors: [Color.mainAccent, Color.mainOrange]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.gray200, Color.gray200]), startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: viewModel.endDate != nil ? 2.0 : 1.0)
                                )
                    
                            HStack {
                                Text(viewModel.endDateToString(in: viewModel.endDate))
                                    .font(.custom(FontsManager.WantedSans.regular, size: 16))
                                    .foregroundStyle(viewModel.endDate == nil ? Color.gray300 : Color.black)
                                    .padding(.leading, 20)
                                    .padding(.vertical, 6)
                                Spacer()
                            }
                        }
                    }
                    .sheet(isPresented: $showEndModal) {
                        datePickerModal(initial: viewModel.endDate, in: endDateRange) { picked in
                            showEndModal = false
                            viewModel.endDate = picked
                        }
                            .presentationDetents([.height(354), .height(354)])
                    }
                }
                .padding(.horizontal, 40)
            }
    
            Spacer()
        }
    }

    // MARK: - 날짜 고르기

    // 시작일과 종료일 모달은 고르는 범위와 어디에 넣는지만 달랐다. 나머지가
    // 같아 한쪽만 고치면 다른 쪽이 조용히 어긋나므로 한 벌로 합쳤다.
    private func datePickerModal(initial: Date?,
                                 in range: ClosedRange<Date>? = nil,
                                 onConfirm: @escaping (Date) -> Void) -> some View {
        VStack {
            Group {
                if let range {
                    DatePicker("", selection: $modalDate, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: $modalDate, displayedComponents: .date)
                }
            }
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()

            LargeButtonActive(title: String(localized: "확인")) {
                onConfirm(modalDate)
            }
        }
        .onAppear {
            modalDate = initial ?? Date()
        }
    }

    /// 종료일은 시작일보다 앞설 수 없다.
    private var endDateRange: ClosedRange<Date> {
        (viewModel.startDate ?? .distantPast)...(.distantFuture)
    }
}
