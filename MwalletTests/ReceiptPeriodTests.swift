//
//  ReceiptPeriodTests.swift
//  MwalletTests
//
//  '언제 쓴 것만 볼지'.
//  경계에서 하루가 밀리면 어제 것이 오늘로 세어지므로 그 자리를 고정한다.
//

import XCTest
@testable import Mwallet

final class ReceiptPeriodTests: CoreDataTestCase {

    // 기준 시각을 못 박는다. Date() 를 쓰면 자정 언저리에 돌 때 결과가 달라진다.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-15 07:13 KST
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func days(_ value: Int) -> Date {
        calendar.date(byAdding: .day, value: value, to: now)!
    }

    // MARK: - 전체

    func test_전체_기간은_아무것도_거르지_않는다() {
        XCTAssertNil(ReceiptPeriod.all.start(from: now, calendar: calendar))
        XCTAssertTrue(ReceiptPeriod.all.contains(days(-3650), now: now, calendar: calendar))
    }

    // MARK: - 오늘

    func test_오늘은_그날_0시부터다() {
        let start = ReceiptPeriod.today.start(from: now, calendar: calendar)

        XCTAssertEqual(start, calendar.startOfDay(for: now))
    }

    func test_오늘_이른_시각도_오늘에_든다() {
        let dawn = calendar.startOfDay(for: now)

        XCTAssertTrue(ReceiptPeriod.today.contains(dawn, now: now, calendar: calendar))
    }

    // 자정을 한 번 넘으면 어제다. 여기가 밀리면 어제 것이 오늘로 세어진다.
    func test_어제_늦은_시각은_오늘이_아니다() {
        let justBefore = calendar.startOfDay(for: now).addingTimeInterval(-1)

        XCTAssertFalse(ReceiptPeriod.today.contains(justBefore, now: now, calendar: calendar))
    }

    // MARK: - 최근 7일

    // 오늘을 포함해 7일이므로 6일 전 0시부터다.
    func test_최근_7일은_오늘을_포함해_이레다() {
        let start = ReceiptPeriod.lastWeek.start(from: now, calendar: calendar)

        XCTAssertEqual(start, calendar.startOfDay(for: days(-6)))
        XCTAssertTrue(ReceiptPeriod.lastWeek.contains(days(-6), now: now, calendar: calendar))
    }

    func test_이레를_넘긴_것은_빠진다() {
        let tooOld = calendar.startOfDay(for: days(-6)).addingTimeInterval(-1)

        XCTAssertFalse(ReceiptPeriod.lastWeek.contains(tooOld, now: now, calendar: calendar))
    }

    // MARK: - 이번 달

    func test_이번_달은_1일_0시부터다() {
        let start = ReceiptPeriod.thisMonth.start(from: now, calendar: calendar)
        let components = calendar.dateComponents([.day, .hour, .minute], from: start!)

        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    func test_지난달_마지막_날은_빠진다() {
        let start = ReceiptPeriod.thisMonth.start(from: now, calendar: calendar)!

        XCTAssertFalse(ReceiptPeriod.thisMonth.contains(start.addingTimeInterval(-1),
                                                        now: now, calendar: calendar))
    }

    // MARK: - 앞날

    // 시간대 차이로 앞날에 적힌 지출이 생길 수 있다. 걸러 내면 '왜 안 보이지' 가 된다.
    func test_앞날에_적힌_것도_보여_준다() {
        for period in ReceiptPeriod.allCases {
            XCTAssertTrue(period.contains(days(3), now: now, calendar: calendar), period.title)
        }
    }

    // MARK: - 필터와 함께

    func test_기간과_검색어를_함께_건다() {
        var filter = ReceiptFilter()
        filter.period = .today
        filter.searchText = "커피"

        let todayCoffee = makeExpense(merchant: "커피", paidAt: now)
        let todayMeal = makeExpense(merchant: "국밥", paidAt: now)
        let oldCoffee = makeExpense(merchant: "커피", paidAt: days(-30))

        XCTAssertTrue(filter.matches(todayCoffee, now: now))
        XCTAssertFalse(filter.matches(todayMeal, now: now), "검색어가 걸려야 합니다")
        XCTAssertFalse(filter.matches(oldCoffee, now: now), "기간이 걸려야 합니다")
    }

    func test_기본값은_전체_기간이다() {
        let filter = ReceiptFilter()

        XCTAssertEqual(filter.period, .all)
        XCTAssertTrue(filter.matches(makeExpense(paidAt: days(-3650)), now: now))
    }
}
