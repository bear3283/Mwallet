//
//  TravelGrouping.swift
//  Mwallet
//
//  여행 목록을 연도로 나눈다.
//
//  왜 연도인가 — 여행은 하루가 아니라 기간이라, 날짜 단위로 나누면 여행
//  하나에 머리글 하나가 붙어 나누는 뜻이 없어진다. 단기사역은 한 해에 몇
//  번이라 실제로 묶이는 단위가 해다.
//
//  달력은 반드시 받아서 쓴다. 기본 달력을 안에서 쓰면 시간대가 다른 곳에서
//  1월 1일 여행이 지난해로 밀린다. 여행은 시간대가 다른 곳으로 가는 일이
//  잦아서 이 자리가 특히 위험하다.
//

import Foundation

/// 한 해에 묶인 여행들.
struct TravelYearGroup: Identifiable {

    /// 시작일이 없는 여행이 모이는 묶음은 연도가 없다.
    let year: Int?
    let travels: [Travel]

    var id: Int { year ?? Int.min }

    var title: String {
        guard let year else { return String(localized: "날짜 미정") }
        return "\(year)년"
    }
}

enum TravelGrouping {

    /// 시작일이 든 해. 시작일이 없으면 nil 이다.
    static func year(of travel: Travel, calendar: Calendar) -> Int? {
        guard let start = travel.startDate else { return nil }
        return calendar.component(.year, from: start)
    }

    /// 연도로 나눈다. 최근 해가 먼저 오고, '날짜 미정' 은 맨 뒤다.
    static func byYear(_ travels: [Travel], calendar: Calendar = .current) -> [TravelYearGroup] {
        let buckets = Dictionary(grouping: travels) { year(of: $0, calendar: calendar) }

        return buckets
            .map { TravelYearGroup(year: $0.key, travels: $0.value.sorted(by: order)) }
            .sorted { lhs, rhs in
                // 연도 없는 묶음은 언제나 맨 뒤. 둘 다 없을 수는 없다(키가 하나뿐이므로).
                guard let left = lhs.year else { return false }
                guard let right = rhs.year else { return true }
                return left > right
            }
    }

    /// 여행이 하나라도 있는 해만, 최근 순으로. 달력 버튼의 목록이다.
    static func years(in travels: [Travel], calendar: Calendar = .current) -> [Int] {
        Set(travels.compactMap { year(of: $0, calendar: calendar) }).sorted(by: >)
    }

    /// 한 해만 남긴다. nil 이면 거르지 않는다.
    static func filter(_ travels: [Travel], year: Int?, calendar: Calendar = .current) -> [Travel] {
        guard let year else { return travels }
        return travels.filter { TravelGrouping.year(of: $0, calendar: calendar) == year }
    }

    /// 한 해 안에서의 차례. 최근에 떠난 것이 먼저다.
    ///
    /// 시작일이 같으면 이름으로 가른다. 그러지 않으면 볼 때마다 자리가 바뀐다
    /// (Dictionary 는 차례를 지켜 주지 않는다).
    private static func order(_ lhs: Travel, _ rhs: Travel) -> Bool {
        let left = lhs.startDate ?? .distantPast
        let right = rhs.startDate ?? .distantPast
        if left != right { return left > right }
        return lhs.displayName < rhs.displayName
    }
}
