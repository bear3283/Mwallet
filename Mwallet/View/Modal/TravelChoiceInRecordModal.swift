//
//  TravelChoiceInRecordModal.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/16/23.
//

import OSLog
import SwiftUI

struct TravelChoiceInRecordModal: View {
    @Binding var chosenTravel: Travel?
    @State private var travelArray = [Travel]()
    @State private var flagNameArrayDict: [UUID: [String]] = [:]
    @State private var defaultImageStringDict: [UUID: String] = [:]
    var updateIsSameDataStateClosure: () -> Bool
    @Binding var isSameData: Bool
    
    var body: some View {
        ZStack {
            Color(.white)
                .ignoresSafeArea()
            VStack {
                Spacer()
                    .frame(height: 32)
                titleView
                Spacer()
                    .frame(height: 24)
                travelScrollView
            }
        }
        .onAppear {
            do {
                // '임시 기록'은 여행을 안 고를 때 자동으로 저장되는 기본함이라
                // 사용자에게는 보이지 않는다. 선택 목록에서 뺀다.
                try travelArray = PersistenceController.shared.container.viewContext.fetch(Travel.fetchRequest())
                    .filter { $0.isUserCreated }
                    .sorted(by: travelModalSortRule)
            } catch {
                Logger.data.error("여행 목록 조회 실패: \(error.localizedDescription, privacy: .public)")
            }
            updateFlagNameArrayDictAndDefaultImageStringDict()
        }
    }
    
    private var titleView: some View {
        HStack {
            Spacer()
                .frame(width: 20)
            Text("여행 선택")
                .foregroundStyle(.black)
                .font(.display1)
            Spacer()
        }
    }
    
    private var travelScrollView: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                Spacer()
                    .frame(width: 20)
                ForEach(travelArray, id: \.self) { travel in
                    HStack(spacing: 0) {
                        TravelBlockView(travel: travel, chosenTravel: chosenTravel, flagNameArray: flagNameArrayDict[travel.id ?? UUID()] ?? [], defaultImageString: defaultImageStringDict[travel.id ?? UUID()] ?? "DefaultImage")
                            .onTapGesture {
                                chosenTravel = travel
                                isSameData = updateIsSameDataStateClosure()
                            }
                        Spacer()
                            .frame(width: 10)
                    }
                }
                Spacer()
                    .frame(width: 10)
            }
        }
    }
    
    private func updateFlagNameArrayDictAndDefaultImageStringDict() {
        for travel in travelArray {
            var expenseArray = (travel.expenseArray!.allObjects as? [Expense]) ?? []
            var includedCountryArray: [Int] = []
            
            expenseArray
                .sort {
                    if let date0 = $0.payDate, let date1 = $1.payDate {
                        return date0 >= date1
                    } else {
                        return true
                    }
                }
                        
            for expense in expenseArray {
                if !includedCountryArray.contains(Int(expense.country)) {
                    includedCountryArray.append(Int(expense.country))
                }
                if includedCountryArray.count >= 4 {
                    break
                }
            }
                        
            if let travelId = travel.id {
                flagNameArrayDict[travelId] = includedCountryArray.map { CountryInfoModel.shared.countryResult[$0]?.flagString ?? "DefaultFlag" }
                
                defaultImageStringDict[travelId] = CountryInfoModel.shared.countryResult[includedCountryArray.first ?? -1]?.defaultImageString ?? "DefaultImage"
            }
        }
    }
}

struct TravelBlockView: View {
    let travel: Travel
    let chosenTravel: Travel?
    let now = Date()
    let flagNameArray: [String]
    let defaultImageString: String
    
    var body: some View {
        VStack(spacing: 0) { // ^^^
            
            Group {
                if travel.isDefault {
                    ZStack {
                        Group {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundStyle(.white)
                                .layoutPriority(-1)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.gray300, lineWidth: 1)
                                .layoutPriority(-1)
                            
                            // 뷰 크기 조정용 히든 뷰
                            Text("00.00.00 ~\n00.00.00")
                                .lineSpacing(2)
                                .font(.caption2)
                                .padding(.top, 41) // figma: 41
                                .padding(.bottom, 8) // figma: 8
                                .padding(.leading, 8) // figma: 8
                                .padding(.trailing, 41) // figma: 31
                                .hidden()
                            
                            VStack(spacing: 0) {
                                Spacer()
                                HStack(spacing: 0) {
                                    Spacer()
                                    Text("임시 기록")
                                        .foregroundStyle(.gray400)
                                        .font(.subhead1)
                                    Spacer()
                                        .frame(width: 11)
                                }
                                Spacer()
                                    .frame(height: 10)
                            }
                            .layoutPriority(-1)
                        }
                        .opacity(travel.id == (chosenTravel?.id ?? UUID()) ? 1 : 0.6)
                        
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: 10)
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: 10)
                                CheckStickerView(travel: travel, chosenTravel: chosenTravel)
                                Spacer()
                            }
                            Spacer()
                        }
                        .layoutPriority(-1)
                    }
                } else {
                    ZStack {
                        Group {
                            ZStack {
                                Image(defaultImageString)
                                    .resizable()
                                    .scaledToFill()
                                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                            }
                            .layoutPriority(-1)
                            
                            ZStack {
                                // 뷰 크기 조정용 히든 뷰
                                Text("00.00.00 ~\n00.00.00")
                                    .padding(.top, 41) // figma: 41
                                    .padding(.bottom, 8) // figma: 8
                                    .padding(.leading, 8) // figma: 8
                                    .padding(.trailing, 41) // figma: 31
                                    .lineSpacing(2)
                                    .font(.caption2)
                                    .hidden()
                                
                                Group {
                                    if let startDate = travel.startDate {
                                        if let endDate = travel.endDate {
                                            Text(startDate.toString(dateFormat: "YY.MM.dd") + " " + "~" + "\n" + endDate.toString(dateFormat: "YY.MM.dd"))
                                                .foregroundStyle(.white)
                                                .lineSpacing(2)
                                                .font(.caption2)
                                                .opacity(0.75)
                                        } else {
                                            Text(startDate.toString(dateFormat: "YY.MM.dd") + " " + "~" + "\n" + "미정")
                                                .foregroundStyle(.white)
                                                .lineSpacing(2)
                                                .font(.caption2)
                                                .opacity(0.75)
                                        }
                                    } else {
                                        Text(" ")
                                            .foregroundStyle(.white)
                                            .lineSpacing(2)
                                            .font(.caption2)
                                            .opacity(0.75)
                                    }
                                }
                                .padding(.top, 41) // figma: 41
                                .padding(.bottom, 8) // figma: 8
                                .padding(.leading, 8) // figma: 8
                                .padding(.trailing, 41) // figma: 31
                            }
                            
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: 8)
                                HStack(spacing: 0) {
                                    Spacer()
                                    ZStack {
                                        ForEach((0..<flagNameArray.count).reversed(), id: \.self) { i in
                                            Image(flagNameArray[i])
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .shadow(color: .gray400, radius: 4) // 임의로 넣은 값 ^^^
                                                .offset(x: -13 * CGFloat(flagNameArray.count - 1 - Int(i)))
                                        }
                                    }
                                    Spacer()
                                        .frame(width: 8)
                                }
                                Spacer()
                            }
                            .layoutPriority(-1)
                        }
                        
                        Color(.white)
                            .opacity(travel.id == (chosenTravel?.id ?? UUID()) ? 0.0 : 0.4)
                            .layoutPriority(-1)
                        
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: 10)
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: 10)
                                CheckStickerView(travel: travel, chosenTravel: chosenTravel)
                                Spacer()
                            }
                            Spacer()
                        }
                        .layoutPriority(-1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            Spacer()
                .frame(height: 6)
            
            Text(travel.isUserCreated ? travel.name ?? "-" : " ")
                .lineLimit(1)
                .foregroundStyle(travel.isUserCreated ? .black : .gray400)
                .font(.subhead1)
                .opacity(travel.id == (chosenTravel?.id ?? UUID()) ? 1 : 0.6)
                .padding(.horizontal, 10)
                .layoutPriority(-1)
                .frame(maxWidth: 120) // 상수로 했다 ^^^
            
            Spacer()
                .frame(height: 2) // 눈으로 보기에 비슷하게 적당히 수정했음 ^^^
            
            Group {
                if travel.isDefault {
                    EmptyView()
                } else {
                    if (travel.startDate ?? Date.distantPast) < now && (travel.endDate ?? Date.distantFuture) > now {
                        Text("여행 중")
                            .foregroundStyle(.mainAccent)
                            .font(.caption1)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    } else if (travel.startDate ?? Date.distantPast) > now {
                        Text("다가오는 여행")
                            .foregroundStyle(.black)
                            .font(.caption1)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    } else {
                        Text("지난 여행")
                            .foregroundStyle(.gray300)
                            .font(.caption1)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }
}

struct CheckStickerView: View {
    let travel: Travel
    let chosenTravel: Travel?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(travel.id == (chosenTravel?.id ?? UUID()) ? Color(.mainAccent) : .black)
                .frame(width: 20, height: 20)
                .opacity(travel.id == (chosenTravel?.id ?? UUID()) ? 1.0 : 0.25)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.0)
                )
            if travel.id == (chosenTravel?.id ?? UUID()) {
                Image("circleLabelCheck")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            }
        }
    }
}

//    #Preview {
//        TravelChoiceInRecordModal(chosenTravel: .constant(Travel()))
//    }
