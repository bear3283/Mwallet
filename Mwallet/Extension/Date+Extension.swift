//
//  Date+Extension.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/17/23.
//

import Foundation

extension Date {
    func toString(dateFormat: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        //        dateFormatter.timeZone = ...
        return dateFormatter.string(from: self)
    }
    
    /// 그날의 00:00:00. 여행 시작일을 하루의 처음으로 맞출 때 쓴다.
    func local000() -> Date {
        settingTime(hour: 0, minute: 0, second: 0)
    }

    /// 그날의 23:59:59. 여행 종료일을 하루의 끝으로 맞출 때 쓴다.
    func local235959() -> Date {
        settingTime(hour: 23, minute: 59, second: 59)
    }

    // 위치와 무관한 순수 날짜 계산이라 DateGapHandler 에서 옮겨 왔다.
    // 거기 있었던 탓에 시간대 보정을 지운 뒤에도 위치 핸들러에 묶여 있었다.
    private func settingTime(hour: Int, minute: Int, second: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components) ?? self
    }
    
    func isTimeEqual(to otherDate: Date) -> Bool {
        let calendar = Calendar.current
        let componentsA = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        let componentsB = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: otherDate)
        
        return componentsA.year == componentsB.year &&
        componentsA.month == componentsB.month &&
        componentsA.day == componentsB.day &&
        componentsA.hour == componentsB.hour &&
        componentsA.minute == componentsB.minute
    }
}
