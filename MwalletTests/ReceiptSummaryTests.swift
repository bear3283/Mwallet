//
//  ReceiptSummaryTests.swift
//  MwalletTests
//
//  영수증 목록의 필터와 집계. 통계 차트와 CSV 도 같은 결과를 쓴다.
//

import XCTest
@testable import Mwallet

final class ReceiptSummaryTests: CoreDataTestCase {

    // MARK: - 집계

    func test_원화_합계와_건수를_센다() {
        let expenses = [
            makeExpense(amount: 10_000, category: .food),
            makeExpense(amount: 5_000, category: .transportation)
        ]

        let summary = ReceiptSummary(expenses: expenses)

        XCTAssertEqual(summary.totalInKRW, 15_000)
        XCTAssertEqual(summary.convertibleCount, 2)
        XCTAssertEqual(summary.totalCount, 2)
    }

    func test_환산_못_한_건은_합계에서_빼고_건수만_남긴다() {
        let expenses = [
            makeExpense(amount: 10_000, category: .food),
            makeExpense(amount: 50, currency: "USD", rate: Expense.unknownExchangeRate)
        ]

        let summary = ReceiptSummary(expenses: expenses)

        XCTAssertEqual(summary.totalInKRW, 10_000)
        XCTAssertEqual(summary.unconvertibleCount, 1)
        XCTAssertEqual(summary.totalCount, 2)
    }

    // 하나도 환산 못 했으면 0원이 아니라 "-" 다. 0원은 실제로 0원 쓴 것으로 읽힌다.
    func test_환산_가능한_건이_없으면_합계를_대시로_적는다() {
        let summary = ReceiptSummary(expenses: [
            makeExpense(amount: 50, currency: "USD", rate: Expense.unknownExchangeRate)
        ])

        XCTAssertEqual(ReceiptFormat.krwOrDash(summary), "-")
    }

    func test_환산_가능한_건이_있으면_금액을_적는다() {
        let summary = ReceiptSummary(expenses: [makeExpense(amount: 12_000)])

        XCTAssertEqual(ReceiptFormat.krwOrDash(summary), "12,000원")
    }

    func test_사진이_없는_건수를_센다() {
        let expenses = [
            makeExpense(amount: 1_000, hasPhoto: true),
            makeExpense(amount: 2_000, hasPhoto: false),
            makeExpense(amount: 3_000, hasPhoto: false)
        ]

        let summary = ReceiptSummary(expenses: expenses)

        XCTAssertEqual(summary.missingPhotoCount, 2)
        XCTAssertTrue(summary.hasMissingPhoto)
    }

    func test_카테고리별_합계를_금액_내림차순으로_준다() {
        let expenses = [
            makeExpense(amount: 5_000, category: .food),
            makeExpense(amount: 30_000, category: .room),
            makeExpense(amount: 5_000, category: .food)
        ]

        let summary = ReceiptSummary(expenses: expenses)

        XCTAssertEqual(summary.byCategory.map(\.category), ["숙소", "식비"])
        XCTAssertEqual(summary.byCategory.first?.amountInKRW, 30_000)
        XCTAssertEqual(summary.byCategory.last?.count, 2)
    }

    // 통화별 합계는 환산 전 금액이라, 환율을 못 받은 건도 들어간다.
    func test_통화별_합계는_환산_실패_건도_포함한다() {
        let expenses = [
            makeExpense(amount: 50, currency: "USD", rate: Expense.unknownExchangeRate),
            makeExpense(amount: 30, currency: "USD", rate: 1_300)
        ]

        let summary = ReceiptSummary(expenses: expenses)

        let usd = summary.byCurrency.first { $0.currency == "USD" }
        XCTAssertEqual(usd?.amount, 80)
        XCTAssertEqual(usd?.count, 2)
    }

    // MARK: - 필터

    func test_사역_이름으로_거른다() {
        let travel = makeTravel(name: "제주 워크숍")
        let mine = makeExpense(travel: travel, merchant: "흑돼지집")
        let other = makeExpense(merchant: "공항 식당")

        let filter = ReceiptFilter(missionName: "제주 워크숍")

        XCTAssertTrue(filter.matches(mine))
        XCTAssertFalse(filter.matches(other), "여행이 없는 기록은 '미분류' 라 걸러져야 합니다")
    }

    func test_검색어는_상호_메모_카테고리_사역을_모두_본다() {
        let expense = makeExpense(category: .food, merchant: "흑돼지집", memo: "팀 저녁")

        XCTAssertTrue(ReceiptFilter(searchText: "흑돼지").matches(expense))
        XCTAssertTrue(ReceiptFilter(searchText: "팀 저녁").matches(expense))
        XCTAssertTrue(ReceiptFilter(searchText: "식비").matches(expense))
        XCTAssertFalse(ReceiptFilter(searchText: "항공").matches(expense))
    }

    func test_검색어_대소문자를_가리지_않는다() {
        let expense = makeExpense(merchant: "Jeju Cafe")

        XCTAssertTrue(ReceiptFilter(searchText: "jeju").matches(expense))
    }

    func test_공백만_있는_검색어는_거르지_않는다() {
        let expense = makeExpense(merchant: "흑돼지집")

        XCTAssertTrue(ReceiptFilter(searchText: "   ").matches(expense))
    }

    func test_사진_없는_것만_보기() {
        let withPhoto = makeExpense(amount: 1_000, hasPhoto: true)
        let without = makeExpense(amount: 2_000, hasPhoto: false)

        let filter = ReceiptFilter(onlyMissingPhoto: true)

        XCTAssertFalse(filter.matches(withPhoto))
        XCTAssertTrue(filter.matches(without))
    }

    // MARK: - 일자별 묶음

    func test_날짜별로_묶고_최신_날짜가_먼저_온다() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)

        let expenses = [
            makeExpense(amount: 1_000, paidAt: day1),
            makeExpense(amount: 2_000, paidAt: day2),
            makeExpense(amount: 3_000, paidAt: day2.addingTimeInterval(3_600))
        ]

        let sections = ReceiptGrouping.byDay(expenses)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.first?.expenses.count, 2, "같은 날 두 건이 한 묶음이어야 합니다")
        XCTAssertGreaterThan(try XCTUnwrap(sections.first).day, try XCTUnwrap(sections.last).day)
    }

    func test_묶음_안에서는_늦은_시각이_먼저_온다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expenses = [
            makeExpense(amount: 1_000, merchant: "아침", paidAt: base),
            makeExpense(amount: 2_000, merchant: "저녁", paidAt: base.addingTimeInterval(7_200))
        ]

        let section = ReceiptGrouping.byDay(expenses).first

        XCTAssertEqual(section?.expenses.first?.merchantName, "저녁")
    }

    func test_일자별_소계도_같은_규칙으로_계산한다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expenses = [
            makeExpense(amount: 1_000, paidAt: base),
            makeExpense(amount: 2_000, paidAt: base.addingTimeInterval(3_600))
        ]

        let section = ReceiptGrouping.byDay(expenses).first

        XCTAssertEqual(section?.dayTotal.totalInKRW, 3_000)
    }

    func test_사역_이름_목록을_중복_없이_정렬해_준다() {
        let travel = makeTravel(name: "제주 워크숍")
        let expenses = [
            makeExpense(travel: travel),
            makeExpense(travel: travel),
            makeExpense()
        ]

        XCTAssertEqual(ReceiptGrouping.missionNames(in: expenses), ["미분류", "제주 워크숍"])
    }

    // MARK: - 표시 문구

    // 환율은 소수점을 버리면 검산이 안 맞는다.
    func test_환율은_소수점_두_자리까지_남긴다() {
        XCTAssertEqual(ReceiptFormat.exchangeRate(24.5), "24.5원")
        XCTAssertEqual(ReceiptFormat.exchangeRate(1_300), "1,300원")
    }
}
