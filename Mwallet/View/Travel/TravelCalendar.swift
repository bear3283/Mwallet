//
//  TravelCalendar.swift
//  Mwallet
//
//  여행을 만들 때 쓰는 달력. 시작일과 종료일을 한 판에서 고른다.
//
//  AddTravelView 에서 떼어 냈다. 한 화면이 400줄 가까이 되면 어디를 고쳐야
//  하는지 찾는 데 시간이 들고, 고친 자리가 다른 곳에 닿는지도 알기 어렵다.
//  달력은 그 자체로 완결된 조각이라 가장 먼저 떨어져 나온다.
//

import SwiftUI

struct TravelCalendar: View {

    @ObservedObject var viewModel: AddTravelViewModel

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            dayGrid
        }
    }

private var monthHeader: some View {
    
    let koreanWeekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    
    return VStack(spacing: 30) {
        HStack {
            Button {
                viewModel.changeMonth(by: -1)
            } label: {
                Image("calendar_left")
            }
            
            Spacer()
            
            Text(viewModel.year, formatter: AddTravelViewModel.dateYearFormatter)
                .font(.calendar1_fixed)
                .foregroundStyle(Color(0x333333))
            +
            Text(".")
                .font(.calendar1_fixed)
                .foregroundStyle(Color(0x333333))
            +
            Text(viewModel.month, formatter: AddTravelViewModel.dateFormatter)
                .font(.calendar1_fixed)
                .foregroundStyle(Color(0x333333))
            
            Spacer()
            
            Button {
                viewModel.changeMonth(by: 1)
            } label: {
                Image("calendar_right")
            }
        }
        .padding(.horizontal, 30)

        HStack {
            ForEach(koreanWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(Color.gray300)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
    }
    .padding(.top, 24)
}

private var dayGrid: some View {

    let daysInMonth: Int = viewModel.numberOfDays(in: viewModel.month)
    let firstWeekday: Int = viewModel.firstWeekdayOfMonth(in: viewModel.month) - 1
    let maxNumOfCalendar = viewModel.calculateGridItemCount(daysInMonth: daysInMonth, firstWeekday: firstWeekday)
    
    return VStack {
        LazyVGrid(columns: Array(repeating: GridItem(), count: 7)) {
            ForEach(0 ..< maxNumOfCalendar, id: \.self) { index in
                if index < firstWeekday {

                    let total = viewModel.numberOfDays(in: viewModel.prevMonth)
                    let date = viewModel.getDate(for: index - firstWeekday + 1)
                    let day = total - (firstWeekday - index - 1)
                    
                    TravelCalendarCell(day: day, viewModel: viewModel, date: date, textColor: Color.gray200)
                        .disabled(true)
                    
                } else if (index >= firstWeekday) && (index < daysInMonth + firstWeekday) {
                    
                    let date = viewModel.getDate(for: index - firstWeekday + 1)
                    let day = index - firstWeekday + 1
                    
                    TravelCalendarCell(day: day, viewModel: viewModel, date: date, textColor: Color.black)
                    
                } else {
                    
                    let maxNum = maxNumOfCalendar
                    let tmp = maxNum - index
                    let date = viewModel.getDate(for: index - firstWeekday + 1)
                    let day = maxNum - (daysInMonth + firstWeekday) - tmp + 1
                    
                    TravelCalendarCell(day: day, viewModel: viewModel, date: date, textColor: Color.gray200)
                        .disabled(true)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
}

// MARK: - 날짜 한 칸

struct TravelCalendarCell: View {
    
    private var day: Int
    private var date: Date?
    private var textColor: Color
    @ObservedObject private var viewModel: AddTravelViewModel
    
    init(day: Int, viewModel: AddTravelViewModel, date: Date?, textColor: Color) {
        self.day = day
        self.viewModel = viewModel
        self.date = date
        self.textColor = textColor
    }
    
    // 시작일과 종료일 사이
    private func isSelected(date: Date) -> Bool {
        if date > viewModel.startDate ?? Date() && viewModel.endDate != nil && viewModel.endDate! > date {
            return true
        } else {
            return false
        }
    }
    
    // 시작일과 종료일이 같을 경우
    private func isSameDate(date: Date) -> Bool {
        if let startDate = viewModel.startDate, let endDate = viewModel.endDate,
            viewModel.startDateToString(in: self.date! - 1) == viewModel.startDateToString(in: startDate) &&
            viewModel.startDateToString(in: self.date! - 1) == viewModel.startDateToString(in: endDate) {
            return true
        } else {
            return false
        }
    }
    
    private func isEndDateSelected(date: Date?) -> Bool {
        if date == nil {
            return false
        } else {
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                let result = viewModel.startDateEndDate(in: viewModel.startDate, endDate: viewModel.endDate, selectDate: date!-1)
                viewModel.startDate = result[0]
                viewModel.endDate = result[1]
                
                viewModel.selectDate = date! - 1
                viewModel.isSelectedStartDate = true
            } label: {
                Text(String(day))
                    .padding(9.81)
                    .font(.calendar2)
                    .frame(width: 50) // 45
                    .foregroundStyle(textColor)
                    .overlay {
                        if isSameDate(date: self.date!) {
                            ZStack {
                                Circle()
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(Color.mainAccent)
                                
                                Circle()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.white)
                                
                                Circle()
                                    .frame(width: 33, height: 33)
                                    .foregroundStyle(Color.mainAccent)
                                
                                Text(String(day))
                                    .font(.calendar2)
                                    .padding(9.81)
                                    .frame(width: 45, height: 41)
                                    .foregroundStyle(Color.white)
                            }
                        } else if viewModel.startDateToString(in: viewModel.startDate ?? Date(timeIntervalSinceReferenceDate: 8)) == viewModel.startDateToString(in: self.date! - 1) {
                            ZStack {
                                Rectangle()
                                    .frame(width: 28, height: 33)
                                    .foregroundStyle(isEndDateSelected(date: viewModel.endDate) ? Color(0xFFCCD5) : Color.clear)
                                    .offset(x: 15)
                                
                                Circle()
                                    .frame(width: 33, height: 33)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white)
                                            .fill(Color.mainAccent)
                                    )
                                
                                Text(String(day))
                                    .padding(9.81)
                                    .font(.calendar2)
                                    .frame(width: 45, height: 41)
                                    .foregroundStyle(Color.white)
                            }
                        } else if isSelected(date: self.date!) {
                            ZStack {
                                
                                Text(String(day))
                                    .padding(9.81)
                                    .font(.calendar2)
                                    .foregroundStyle(Color.white)
                                    .frame(width: 47) // 45
                                    .background(
                                        Rectangle()
                                            .foregroundStyle(Color(0xFFCCD5))
                                            .frame(width: 50, height: 33)
                                    )
                                    .foregroundStyle(textColor)
                            }
                        } else if viewModel.endDateToString(in: viewModel.endDate ?? Date(timeIntervalSinceReferenceDate: 8)) == viewModel.endDateToString(in: self.date! - 1) {
                            ZStack {
                                Rectangle()
                                    .frame(width: 28, height: 33)
                                    .foregroundStyle(Color(0xFFCCD5))
                                    .offset(x: -15)
                                
                                Circle()
                                    .frame(width: 33, height: 33)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white)
                                            .fill(Color.mainAccent)
                                    )
                                
                                Text(String(day))
                                    .font(.calendar2)
                                    .padding(9.81)
                                    .frame(width: 45, height: 41)
                                    .foregroundStyle(Color.white)
                            }
                        }
                    }
            }
        }
    }
}
