//
//  BudgetStoreTests.swift
//  MwalletTests
//
//  예산 저장 규칙. 한 사역의 카테고리당 Budget 은 하나여야 합계가 어긋나지 않는다.
//

import XCTest
@testable import Mwallet

final class BudgetStoreTests: CoreDataTestCase {

    private var store: BudgetStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = BudgetStore(context: context)
    }

    func test_카테고리별_금액을_저장한다() throws {
        let travel = makeTravel()

        try store.save([.food: 60_000, .room: 100_000], for: travel)

        let saved = store.budgets(for: travel)
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(store.summary(for: travel).totalPlanned, 160_000)
    }

    // 0 원은 '배정하지 않음' 이다. 레코드를 남기면 빈 줄이 목록에 늘어선다.
    func test_0원은_레코드를_남기지_않는다() throws {
        let travel = makeTravel()

        try store.save([.food: 60_000, .room: 0], for: travel)

        let categories = store.budgets(for: travel).map { ExpenseInfoCategory(rawValue: Int($0.category)) }
        XCTAssertEqual(categories, [.food])
    }

    func test_금액을_0으로_바꾸면_기존_예산을_지운다() throws {
        let travel = makeTravel()
        try store.save([.food: 60_000], for: travel)
        XCTAssertEqual(store.budgets(for: travel).count, 1)

        try store.save([.food: 0], for: travel)

        XCTAssertTrue(store.budgets(for: travel).isEmpty)
        XCTAssertEqual(store.summary(for: travel).totalPlanned, 0)
    }

    func test_다시_저장하면_레코드를_늘리지_않고_금액만_바꾼다() throws {
        let travel = makeTravel()
        try store.save([.food: 60_000], for: travel)

        try store.save([.food: 80_000], for: travel)

        XCTAssertEqual(store.budgets(for: travel).count, 1, "저장할 때마다 레코드가 쌓이면 합계가 부풀어 오릅니다")
        XCTAssertEqual(store.summary(for: travel).totalPlanned, 80_000)
    }

    // CloudKit 으로 같은 카테고리가 두 벌 들어올 수 있다. 저장할 때 하나로 정리한다.
    func test_같은_카테고리가_중복이면_큰_금액만_남긴다() throws {
        let travel = makeTravel()
        makeBudget(travel: travel, category: .food, amount: 30_000)
        makeBudget(travel: travel, category: .food, amount: 50_000)
        try context.save()
        XCTAssertEqual(store.budgets(for: travel).count, 2)

        try store.save([.food: 50_000], for: travel)

        XCTAssertEqual(store.budgets(for: travel).count, 1)
        XCTAssertEqual(store.summary(for: travel).totalPlanned, 50_000)
    }

    func test_다른_여행의_예산은_건드리지_않는다() throws {
        let mine = makeTravel(name: "제주 워크숍")
        let other = makeTravel(name: "부산 워크숍")
        try store.save([.food: 10_000], for: other)

        try store.save([.food: 60_000], for: mine)

        XCTAssertEqual(store.summary(for: other).totalPlanned, 10_000)
        XCTAssertEqual(store.summary(for: mine).totalPlanned, 60_000)
    }

    func test_지출은_최신순으로_준다() {
        let travel = makeTravel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        makeExpense(travel: travel, merchant: "먼저", paidAt: base)
        makeExpense(travel: travel, merchant: "나중", paidAt: base.addingTimeInterval(3_600))

        XCTAssertEqual(store.expenses(for: travel).first?.merchantName, "나중")
    }

    func test_임시_기록_여행은_예산_대상이_아니다() {
        makeTravel(isDefault: true)
        makeTravel(name: "제주 워크숍")

        XCTAssertEqual(store.availableTravels().map { $0.name }, ["제주 워크숍"])
    }
}
