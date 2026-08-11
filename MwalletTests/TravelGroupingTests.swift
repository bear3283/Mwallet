//
//  TravelGroupingTests.swift
//  MwalletTests
//
//  여행 목록을 연도로 나누는 셈.
//  해가 바뀌는 자리와 차례가 흔들리지 않는지 지킨다.
//

import XCTest
@testable import Mwallet

final class TravelGroupingTests: CoreDataTestCase {

    private var seoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    // MARK: - 나누기

    func test_해마다_나눈다() {
        makeTravel(name: "방콕", start: date("2026-03-02 09:00"))
        makeTravel(name: "마닐라", start: date("2025-11-04 09:00"))
        makeTravel(name: "다낭", start: date("2025-08-01 09:00"))

        let groups = TravelGrouping.byYear(allTravels(), calendar: seoul)

        XCTAssertEqual(groups.map(\.year), [2026, 2025])
        XCTAssertEqual(groups.map { $0.travels.count }, [1, 2])
    }

    func test_최근_해가_먼저_온다() {
        makeTravel(name: "옛것", start: date("2019-05-01 09:00"))
        makeTravel(name: "새것", start: date("2026-05-01 09:00"))

        let groups = TravelGrouping.byYear(allTravels(), calendar: seoul)

        XCTAssertEqual(groups.first?.year, 2026)
        XCTAssertEqual(groups.last?.year, 2019)
    }

    func test_한_해_안에서는_최근에_떠난_것이_먼저다() {
        makeTravel(name: "3월", start: date("2026-03-01 09:00"))
        makeTravel(name: "9월", start: date("2026-09-01 09:00"))
        makeTravel(name: "6월", start: date("2026-06-01 09:00"))

        let group = TravelGrouping.byYear(allTravels(), calendar: seoul).first

        XCTAssertEqual(group?.travels.map(\.displayName), ["9월", "6월", "3월"])
    }

    // Dictionary 는 차례를 지켜 주지 않는다. 이름으로 가르지 않으면
    // 같은 날 떠난 여행들의 자리가 볼 때마다 바뀐다.
    func test_같은_날_떠났으면_이름_순서로_둔다() {
        let sameDay = date("2026-03-01 09:00")
        makeTravel(name: "다낭", start: sameDay)
        makeTravel(name: "가나", start: sameDay)
        makeTravel(name: "나트랑", start: sameDay)

        let group = TravelGrouping.byYear(allTravels(), calendar: seoul).first

        XCTAssertEqual(group?.travels.map(\.displayName), ["가나", "나트랑", "다낭"])
    }

    // MARK: - 해가 바뀌는 자리

    // 여행은 시간대가 다른 곳으로 간다. 달력을 안에서 만들어 쓰면
    // 1월 1일에 떠난 여행이 지난해 묶음으로 밀린다.
    func test_시간대에_따라_해가_갈린다() {
        // 한국에서 2024-01-01 01:00. 세계표준시로는 아직 2023-12-31 16:00 이다.
        let travel = makeTravel(name: "새해", start: date("2024-01-01 01:00"))

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        XCTAssertEqual(TravelGrouping.year(of: travel, calendar: seoul), 2024)
        XCTAssertEqual(TravelGrouping.year(of: travel, calendar: utc), 2023,
                       "달력을 받아 쓰지 않으면 이 차이가 조용히 묻힙니다")
    }

    func test_섣달_그믐과_설날은_다른_해다() {
        makeTravel(name: "그믐", start: date("2025-12-31 23:00"))
        makeTravel(name: "설날", start: date("2026-01-01 01:00"))

        let groups = TravelGrouping.byYear(allTravels(), calendar: seoul)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.travels.map(\.displayName), ["설날"])
        XCTAssertEqual(groups.last?.travels.map(\.displayName), ["그믐"])
    }

    // MARK: - 날짜 미정

    func test_시작일이_없으면_따로_모아_맨_뒤에_둔다() {
        makeTravel(name: "언젠가", start: date("2026-03-01 09:00")).startDate = nil
        makeTravel(name: "방콕", start: date("2026-03-02 09:00"))
        makeTravel(name: "옛것", start: date("2019-05-01 09:00"))

        let groups = TravelGrouping.byYear(allTravels(), calendar: seoul)

        XCTAssertEqual(groups.map(\.year), [2026, 2019, nil])
        XCTAssertEqual(groups.last?.title, "날짜 미정")
    }

    func test_모두_날짜가_없으면_묶음이_하나다() {
        makeTravel(name: "가").startDate = nil
        makeTravel(name: "나").startDate = nil

        let groups = TravelGrouping.byYear(allTravels(), calendar: seoul)

        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups.first?.year)
        XCTAssertEqual(groups.first?.travels.count, 2)
    }

    // MARK: - 연도 목록

    func test_여행이_있는_해만_최근_순으로_모은다() {
        makeTravel(name: "가", start: date("2026-03-01 09:00"))
        makeTravel(name: "나", start: date("2026-09-01 09:00"))
        makeTravel(name: "다", start: date("2024-01-05 09:00"))

        XCTAssertEqual(TravelGrouping.years(in: allTravels(), calendar: seoul), [2026, 2024],
                       "같은 해가 두 번 나오면 안 됩니다")
    }

    func test_날짜가_없는_여행은_연도_목록에_없다() {
        makeTravel(name: "언젠가").startDate = nil

        XCTAssertTrue(TravelGrouping.years(in: allTravels(), calendar: seoul).isEmpty)
    }

    // MARK: - 거르기

    func test_고른_해만_남긴다() {
        makeTravel(name: "올해", start: date("2026-03-01 09:00"))
        makeTravel(name: "지난해", start: date("2025-03-01 09:00"))

        let kept = TravelGrouping.filter(allTravels(), year: 2026, calendar: seoul)

        XCTAssertEqual(kept.map(\.displayName), ["올해"])
    }

    func test_고른_해가_없으면_거르지_않는다() {
        makeTravel(name: "올해", start: date("2026-03-01 09:00"))
        makeTravel(name: "언젠가").startDate = nil

        XCTAssertEqual(TravelGrouping.filter(allTravels(), year: nil, calendar: seoul).count, 2)
    }

    // MARK: - 빈 경우

    func test_여행이_없으면_묶음도_없다() {
        XCTAssertTrue(TravelGrouping.byYear([], calendar: seoul).isEmpty)
        XCTAssertTrue(TravelGrouping.years(in: [], calendar: seoul).isEmpty)
    }

    // MARK: -

    private func allTravels() -> [Travel] {
        (try? context.fetch(Travel.fetchRequest())) ?? []
    }
}
