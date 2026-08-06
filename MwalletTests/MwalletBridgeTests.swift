//
//  MwalletBridgeTests.swift
//  MwalletTests
//
//  위젯 ↔ 앱 사이의 App Group 큐.
//  위젯에서 누른 지출이 사라지지 않는지가 핵심이다.
//

import CoreData
import XCTest
@testable import Mwallet

final class MwalletBridgeTests: CoreDataTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 실제 기기/시뮬레이터에 남아 있을 수 있는 대기분을 비우고 시작한다.
        _ = MwalletShared.drainQueue()
    }

    override func tearDown() {
        _ = MwalletShared.drainQueue()
        super.tearDown()
    }

    private func enqueueSample(amount: Double = 4_500, label: String = "커피") {
        MwalletShared.enqueue(
            PendingExpense(amount: amount, categoryIndex: ExpenseInfoCategory.food.rawValue,
                           paymentMethodIndex: 0, info: label)
        )
    }

    // MARK: - 큐

    func test_담고_읽고_비운다() {
        enqueueSample()
        enqueueSample(amount: 10_000, label: "식사")

        XCTAssertEqual(MwalletShared.readQueue().count, 2)

        let drained = MwalletShared.drainQueue()

        XCTAssertEqual(drained.map(\.info), ["커피", "식사"])
        XCTAssertTrue(MwalletShared.readQueue().isEmpty, "비운 뒤에도 남아 있으면 지출이 두 번 기록됩니다")
    }

    func test_비어_있으면_빈_배열을_준다() {
        XCTAssertTrue(MwalletShared.readQueue().isEmpty)
        XCTAssertTrue(MwalletShared.drainQueue().isEmpty)
    }

    // MARK: - 반영

    func test_기본_여행이_있으면_지출로_옮긴다() throws {
        let temp = makeTravel(isDefault: true)
        try context.save()
        enqueueSample()

        let moved = MwalletBridge.flushPendingExpenses(into: context)

        XCTAssertEqual(moved, 1)
        let expenses = try context.fetch(Expense.fetchRequest())
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses.first?.travel, temp)
        XCTAssertEqual(expenses.first?.payAmount, 4_500)
        XCTAssertEqual(expenses.first?.currencyCode, "KRW")
        XCTAssertEqual(expenses.first?.exchangeRate, 1)
        XCTAssertTrue(MwalletShared.readQueue().isEmpty)
    }

    // 위젯은 위치를 묻지 않는다. 0(대한민국)을 넣으면 해외에서 담은 지출도
    // 국내로 표시된다.
    func test_위젯_기록의_국가는_알_수_없음이다() throws {
        makeTravel(isDefault: true)
        try context.save()
        enqueueSample()

        MwalletBridge.flushPendingExpenses(into: context)

        let expense = try XCTUnwrap(try context.fetch(Expense.fetchRequest()).first)
        XCTAssertEqual(expense.country, ExpenseCode.unknownCountry)
    }

    // 여기가 예전에 지출을 잃던 자리다. 먼저 큐를 비우고 travel 이 nil 이어도
    // 그대로 저장해, 어느 탭에도 안 보이는 기록이 생겼다.
    func test_기본_여행이_없으면_큐를_비우지_않는다() throws {
        enqueueSample()

        let moved = MwalletBridge.flushPendingExpenses(into: context)

        XCTAssertEqual(moved, 0)
        XCTAssertEqual(MwalletShared.readQueue().count, 1, "담을 곳이 없는데 큐를 비우면 지출이 사라집니다")
        XCTAssertEqual(try context.fetch(Expense.fetchRequest()).count, 0)
    }

    func test_큐가_비어_있으면_아무_것도_하지_않는다() throws {
        makeTravel(isDefault: true)
        try context.save()

        XCTAssertEqual(MwalletBridge.flushPendingExpenses(into: context), 0)
        XCTAssertEqual(try context.fetch(Expense.fetchRequest()).count, 0)
    }

    func test_여러_건을_한_번에_옮긴다() throws {
        makeTravel(isDefault: true)
        try context.save()
        enqueueSample(amount: 4_500, label: "커피")
        enqueueSample(amount: 10_000, label: "식사")
        enqueueSample(amount: 3_000, label: "교통")

        XCTAssertEqual(MwalletBridge.flushPendingExpenses(into: context), 3)
        XCTAssertEqual(try context.fetch(Expense.fetchRequest()).count, 3)
    }

    func test_옮긴_지출에_기록_시각과_시간대가_남는다() throws {
        makeTravel(isDefault: true)
        try context.save()
        enqueueSample()
        let before = Date()

        MwalletBridge.flushPendingExpenses(into: context)

        let expense = try XCTUnwrap(try context.fetch(Expense.fetchRequest()).first)
        XCTAssertEqual(expense.timeZoneIdentifier, TimeZone.current.identifier)
        // 위젯에서 누른 시각이 그대로 저장된다(시프트 없음).
        XCTAssertLessThanOrEqual(abs(expense.paidDate.timeIntervalSince(before)), 5)
    }

    // MARK: - 스냅샷

    func test_스냅샷을_쓰고_읽는다() {
        let travel = makeTravel(name: "제주 워크숍")
        makeBudget(travel: travel, category: .food, amount: 60_000)
        makeExpense(travel: travel, amount: 20_000, category: .food)
        let summary = BudgetStore(context: context).summary(for: travel)

        MwalletBridge.publish(summary: summary, travelName: "제주 워크숍", pendingReceiptCount: 2)

        let snapshot = MwalletShared.readSnapshot()
        XCTAssertEqual(snapshot?.travelName, "제주 워크숍")
        XCTAssertEqual(snapshot?.totalPlanned, 60_000)
        XCTAssertEqual(snapshot?.totalSpent, 20_000)
        XCTAssertEqual(snapshot?.pendingReceiptCount, 2)
        XCTAssertEqual(snapshot?.categories.first?.name, "식비")
    }

    func test_스냅샷_파생값() {
        let snapshot = BudgetSnapshot(travelName: "제주", totalPlanned: 100_000, totalSpent: 120_000,
                                      pendingReceiptCount: 0, categories: [], updatedAt: Date())

        XCTAssertTrue(snapshot.isOverspent)
        XCTAssertEqual(snapshot.remaining, -20_000)
        XCTAssertEqual(snapshot.ratio, 1.2, accuracy: 0.0001)
        XCTAssertTrue(snapshot.hasBudget)
    }

    func test_예산이_0이면_비율을_0으로_둔다() {
        let snapshot = BudgetSnapshot(travelName: "제주", totalPlanned: 0, totalSpent: 5_000,
                                      pendingReceiptCount: 0, categories: [], updatedAt: Date())

        XCTAssertEqual(snapshot.ratio, 0, "0 으로 나눈 값이 나오면 안 됩니다")
        XCTAssertFalse(snapshot.hasBudget)
    }

    func test_위젯_표시_포맷() {
        XCTAssertEqual(MwalletSharedFormat.krw(1_234_567), "1,234,567원")
        XCTAssertEqual(MwalletSharedFormat.percent(0.856), "86%")
    }
}
