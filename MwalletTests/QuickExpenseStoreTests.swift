//
//  QuickExpenseStoreTests.swift
//  MwalletTests
//
//  위젯이 담은 지출이 어떤 통화로, 어디에 적히는지.
//
//  가장 중요한 것은 통화다. 예전에는 위젯으로 담은 것을 무조건 원화로 적어,
//  방콕에서 ฿60 짜리 커피가 장부에 ₩60 으로 들어갔다. 눈으로 세기 어려운
//  종류의 틀림이라 — 숫자는 그럴듯하고 단위만 틀리다 — 여기서 지킨다.
//

import CoreData
import XCTest
@testable import Mwallet

final class QuickExpenseStoreTests: CoreDataTestCase {

    private let thb: Int64 = 42     // 통화 인덱스는 무엇이든 상관없다. 물려받는지만 본다.
    private let thailand: Int64 = 7

    // MARK: - 통화 물려받기

    func test_그_여행에서_마지막에_쓰던_통화를_물려받는다() throws {
        let travel = makeTravel(name: "방콕")
        addExpense(to: travel, currency: thb, rate: 38.5, country: thailand,
                   at: Date().addingTimeInterval(-3600))
        try context.save()

        let money = try XCTUnwrap(QuickExpenseStore.inheritedMoney(of: travel))

        XCTAssertEqual(money.currency, thb)
        XCTAssertEqual(money.exchangeRate, 38.5)
        XCTAssertEqual(money.country, thailand)
    }

    // 여러 건이면 가장 최근 것. 국경을 넘으면 통화도 그때부터 바뀐다.
    func test_가장_최근_지출의_통화를_따른다() throws {
        let travel = makeTravel(name: "인도차이나")
        addExpense(to: travel, currency: thb, rate: 38.5, country: thailand,
                   at: Date().addingTimeInterval(-86_400))
        addExpense(to: travel, currency: 99, rate: 0.055, country: 12,
                   at: Date().addingTimeInterval(-60))
        try context.save()

        let money = try XCTUnwrap(QuickExpenseStore.inheritedMoney(of: travel))

        XCTAssertEqual(money.currency, 99, "국경을 넘었는데 옛 통화를 따릅니다")
        XCTAssertEqual(money.exchangeRate, 0.055)
    }

    // 환율을 받지 못한 지출은 물려받지 않는다. 환율 0 을 물려받으면 그 지출이
    // 합계에서 빠져, 담았는데 어디에도 안 세지는 것이 된다.
    func test_환율이_없는_지출은_물려받지_않는다() throws {
        let travel = makeTravel(name: "방콕")
        addExpense(to: travel, currency: thb, rate: 38.5, country: thailand,
                   at: Date().addingTimeInterval(-86_400))
        addExpense(to: travel, currency: 99, rate: 0, country: 12,
                   at: Date().addingTimeInterval(-60))
        try context.save()

        let money = try XCTUnwrap(QuickExpenseStore.inheritedMoney(of: travel))

        XCTAssertEqual(money.currency, thb)
        XCTAssertEqual(money.exchangeRate, 38.5)
    }

    // 아직 한 건도 없는 여행은 물려받을 것이 없다. 짐작으로 고르면 틀린다.
    func test_지출이_없으면_물려받을_통화가_없다() throws {
        let travel = makeTravel(name: "새 여행")
        try context.save()

        XCTAssertNil(QuickExpenseStore.inheritedMoney(of: travel))
    }

    // MARK: - 담길 여행

    func test_여행_중이면_그_여행에_담는다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        let now = Date()
        let bangkok = makeTravel(name: "방콕",
                                 start: now.addingTimeInterval(-2 * 86_400),
                                 end: now.addingTimeInterval(2 * 86_400))
        try context.save()

        XCTAssertEqual(QuickExpenseStore.destination(in: context)?.objectID, bangkok.objectID)
    }

    func test_여행_중이_아니면_기본함에_담는다() throws {
        let box = makeTravel(name: "임시 기록", isDefault: true)
        makeTravel(name: "지난 여행",
                   start: Date().addingTimeInterval(-30 * 86_400),
                   end: Date().addingTimeInterval(-25 * 86_400))
        try context.save()

        XCTAssertEqual(QuickExpenseStore.destination(in: context)?.objectID, box.objectID)
    }

    // 기간이 겹치면 늦게 시작한 것. 앞의 여행이 안 끝났는데 다음이 시작됐다면
    // 지금 있는 곳은 나중 쪽이다.
    func test_기간이_겹치면_늦게_시작한_여행이다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        let now = Date()
        makeTravel(name: "먼저", start: now.addingTimeInterval(-5 * 86_400),
                   end: now.addingTimeInterval(1 * 86_400))
        let later = makeTravel(name: "나중", start: now.addingTimeInterval(-1 * 86_400),
                               end: now.addingTimeInterval(4 * 86_400))
        try context.save()

        XCTAssertEqual(QuickExpenseStore.destination(in: context)?.displayName, later.displayName)
    }

    // 앱 쪽 다리도 같은 규칙을 써야 한다. 갈라지면 위젯이 담은 곳과 앱이
    // 옮기는 곳이 달라진다.
    func test_앱_다리와_같은_여행을_고른다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        let now = Date()
        let bangkok = makeTravel(name: "방콕",
                                 start: now.addingTimeInterval(-86_400),
                                 end: now.addingTimeInterval(86_400))
        try context.save()

        XCTAssertEqual(MwalletBridge.destination(in: context)?.objectID, bangkok.objectID)
        XCTAssertEqual(QuickExpenseStore.destination(in: context)?.objectID, bangkok.objectID)
    }

    // MARK: - 큐로 물러난 것도 같은 통화로

    // 위젯이 적지 못해 큐에 남은 것을 앱이 옮길 때도 원화로 굳으면 안 된다.
    func test_큐에서_옮길_때도_그_여행의_통화를_따른다() throws {
        MwalletShared.drainQueue()
        defer { MwalletShared.drainQueue() }

        let travel = makeTravel(name: "방콕",
                                start: Date().addingTimeInterval(-86_400),
                                end: Date().addingTimeInterval(86_400))
        addExpense(to: travel, currency: thb, rate: 38.5, country: thailand, at: Date())
        try context.save()

        MwalletShared.enqueue(PendingExpense(amount: 60, categoryIndex: 3,
                                             paymentMethodIndex: 0, info: "커피"))
        XCTAssertEqual(MwalletBridge.flushPendingExpenses(into: context), 1)

        let coffee = try XCTUnwrap(
            try context.fetch(Expense.fetchRequest()).first { $0.info == "커피" }
        )
        XCTAssertEqual(coffee.currency, thb, "큐에서 옮긴 지출이 원화로 굳었습니다")
        XCTAssertEqual(coffee.exchangeRate, 38.5)
        XCTAssertEqual(coffee.country, thailand)
    }

    // MARK: - 거들기

    @discardableResult
    private func addExpense(to travel: Travel, currency: Int64, rate: Double,
                            country: Int64, at date: Date) -> Expense {
        let expense = Expense(context: context)
        expense.travel = travel
        expense.info = "기존 지출"
        expense.payAmount = 100
        expense.currency = currency
        expense.exchangeRate = rate
        expense.country = country
        expense.payDate = date
        return expense
    }
}
