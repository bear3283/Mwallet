//
//  BudgetSummaryTests.swift
//  MwalletTests
//
//  예결산 탭에 뜨는 숫자는 전부 여기서 나온다.
//  가장 조심할 것: 환율을 못 받은 건을 0 으로 취급해 총액을 줄이지 않는가.
//

import XCTest
@testable import Mwallet

final class BudgetSummaryTests: CoreDataTestCase {

    private func summary(_ travel: Travel) -> BudgetSummary {
        let store = BudgetStore(context: context)
        return store.summary(for: travel)
    }

    // MARK: - 합계

    func test_카테고리별_예산과_집행을_합산한다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 60_000)
        makeBudget(travel: travel, category: .room, amount: 100_000)
        makeExpense(travel: travel, amount: 20_000, category: .food)
        makeExpense(travel: travel, amount: 25_000, category: .food)
        makeExpense(travel: travel, amount: 90_000, category: .room)

        let result = summary(travel)

        XCTAssertEqual(result.totalPlanned, 160_000)
        XCTAssertEqual(result.totalSpent, 135_000)
        XCTAssertEqual(result.remaining, 25_000)
        XCTAssertFalse(result.isOverspent)
    }

    func test_같은_카테고리_예산이_여러_건이면_더한다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 30_000)
        makeBudget(travel: travel, category: .food, amount: 20_000)

        XCTAssertEqual(summary(travel).totalPlanned, 50_000)
    }

    func test_금액이_0인_예산은_배정하지_않은_것으로_본다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 0)

        let result = summary(travel)

        XCTAssertEqual(result.totalPlanned, 0)
        XCTAssertFalse(result.hasBudget)
    }

    // MARK: - 환산 실패 처리

    // 가장 위험한 경로. 환율을 못 받은 건이 0 원으로 합계에 섞이면
    // 결산 총액이 실제보다 작아지는데 화면에는 아무 표시도 남지 않는다.
    func test_환율을_못_받은_건은_집행액에서_빼고_따로_센다() {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 10_000, category: .food)
        makeExpense(travel: travel, amount: 50, currency: "USD",
                    rate: Expense.unknownExchangeRate, category: .food)

        let result = summary(travel)

        XCTAssertEqual(result.totalSpent, 10_000, "환산 못 한 건이 합계에 섞였습니다")
        XCTAssertEqual(result.unconvertibleCount, 1)
        XCTAssertTrue(result.hasUnconvertible)
    }

    func test_환산_실패_건도_건수에는_남는다() throws {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 50, currency: "USD",
                    rate: Expense.unknownExchangeRate, category: .food)

        let line = try XCTUnwrap(summary(travel).lines.first { $0.category == .food })

        XCTAssertEqual(line.spentCount, 1)
        XCTAssertEqual(line.unconvertibleCount, 1)
        XCTAssertEqual(line.spent, 0)
    }

    func test_외화는_기록_시점_환율로_환산해_더한다() {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 10, currency: "USD", rate: 1_300, category: .food)

        XCTAssertEqual(summary(travel).totalSpent, 13_000, accuracy: 0.0001)
    }

    // MARK: - 줄 구성

    func test_예산도_집행도_없는_카테고리는_줄을_만들지_않는다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 10_000)

        let result = summary(travel)

        XCTAssertEqual(result.lines.count, 1)
        XCTAssertEqual(result.lines.first?.category, .food)
    }

    func test_예산_없이_쓰기만_해도_줄이_보인다() {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 5_000, category: .shopping)

        let result = summary(travel)

        XCTAssertEqual(result.lines.map(\.category), [.shopping])
        XCTAssertEqual(result.lines.first?.planned, 0)
    }

    // MARK: - 초과

    func test_예산을_넘긴_항목을_따로_모은다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 10_000)
        makeBudget(travel: travel, category: .room, amount: 100_000)
        makeExpense(travel: travel, amount: 15_000, category: .food)
        makeExpense(travel: travel, amount: 50_000, category: .room)

        let result = summary(travel)

        XCTAssertEqual(result.overspentLines.map(\.category), [.food])
        XCTAssertTrue(result.isOverspent == false, "전체로는 아직 예산 안이어야 합니다")
    }

    // MARK: - 비율

    func test_예산이_0이면_집행률을_내지_않는다() {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 5_000, category: .food)

        let result = summary(travel)

        XCTAssertNil(result.ratio, "0 으로 나눈 값이 나오면 안 됩니다")
        XCTAssertEqual(BudgetFormat.percent(result.ratio), "-")
    }

    // 예산이 없는데 쓴 게 있으면 막대는 가득 찬다. 0 으로 두면 안 쓴 것처럼 보인다.
    func test_예산_없이_지출만_있으면_막대는_가득_찬다() {
        let travel = makeTravel()
        makeExpense(travel: travel, amount: 5_000, category: .food)

        XCTAssertEqual(summary(travel).barRatio, 1)
    }

    func test_막대는_100퍼센트를_넘지_않는다() {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 10_000)
        makeExpense(travel: travel, amount: 30_000, category: .food)

        let result = summary(travel)

        XCTAssertEqual(result.barRatio, 1)
        XCTAssertEqual(result.ratio ?? 0, 3, accuracy: 0.0001, "비율 자체는 잘리면 안 됩니다")
    }

    // MARK: - 표시 문구

    func test_잔액_문구가_초과와_남음을_구분한다() {
        XCTAssertEqual(BudgetFormat.remaining(5_000), "5,000원 남음")
        XCTAssertEqual(BudgetFormat.remaining(-3_000), "3,000원 초과")
    }

    // MARK: - 빈 여행

    func test_여행이_없으면_빈_결산을_준다() {
        let store = BudgetStore(context: context)
        let result = store.summary(for: nil)

        XCTAssertEqual(result.totalPlanned, 0)
        XCTAssertEqual(result.totalSpent, 0)
        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertNil(result.ratio)
    }
}
