//
//  travelModalSortRule.swift
//  Mwallet
//
//  Created by Wonil Lee on 11/14/23.
//

import Foundation

// 전역 let 클로저는 Swift 6 에서 공유 가변 상태로 잡힌다. 함수로 둔다.
func travelListSortRule(_ lhs: Travel, _ rhs: Travel) -> Bool {
    guard let s0 = lhs.startDate, let s1 = rhs.startDate else { return true }
    return s0 < s1
}

func travelModalSortRule(_ lhs: Travel, _ rhs: Travel) -> Bool {
    let nowDate = Date()
    
    if lhs.isUserCreated && rhs.isDefault {
        return false
    } else if lhs.isDefault && rhs.isUserCreated {
        return true
    }
    
    let s0 = lhs.startDate ?? Date.distantPast
    let e0 = lhs.endDate ?? Date.distantFuture
    let s1 = rhs.startDate ?? Date.distantPast
    let e1 = rhs.endDate ?? Date.distantFuture
    
    enum TravelTimeState: Int {
        case current
        case past
        case coming
    }
    
    var state0 = TravelTimeState.current
    var state1 = TravelTimeState.current
    
    if s0 <= nowDate && nowDate <= e0 {
        state0 = .current
    } else if s0 > nowDate {
        state0 = .coming
    } else {
        state0 = .past
    }
    
    if s1 <= nowDate && nowDate <= e1 {
        state1 = .current
    } else if s1 > nowDate {
        state1 = .coming
    } else {
        state1 = .past
    }
    
    if state0 != state1 {
        return state0.rawValue < state1.rawValue
    } else { // 같은 상태의 두 여행
        if state0 == .current { // 진행 중 여행
            return s0 >= s1 // 시작일이 최신인 여행 먼저
        } else if state0 == .past { // 지난 여행
            return e0 >= e1 // 종료일이 최신인 여행 먼저
        } else { // 다가오는 여행
            return s0 <= s1 // 시작일이 과거인(가까운) 여행 먼저
        }
    }
}
