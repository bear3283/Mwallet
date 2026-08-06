//
//  ReceiptStoreTests.swift
//  MwalletTests
//
//  영수증의 쓰기 규칙. 특히 환율 스냅샷은 한 번 굳으면 나중에 되돌릴 수 없어
//  "언제 새로 찍고 언제 보존하는가" 가 정확해야 한다.
//

import XCTest
@testable import Mwallet

final class ReceiptStoreTests: CoreDataTestCase {

    private var store: ReceiptStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = ReceiptStore(context: context)
        stubExchangeRates(["USD": 0.0008, "JPY": 0.11])   // USD 1 = 1250원, JPY 1 ≈ 9.09원
    }

    private func draft(amount: String, currency: String, merchant: String = "식당") -> ReceiptDraft {
        var draft = ReceiptDraft()
        draft.amountText = amount
        draft.currency = currency
        draft.merchant = merchant
        draft.category = ExpenseInfoCategory.food.description
        return draft
    }

    // MARK: - 생성

    func test_원화는_환율_1로_저장한다() throws {
        let expense = try store.create(from: draft(amount: "12000", currency: "KRW"))

        XCTAssertEqual(expense.exchangeRate, 1)
        XCTAssertEqual(expense.amountInKRW, 12_000)
    }

    func test_외화는_기록_시점_환율을_찍어_둔다() throws {
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), 1_250, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(expense.amountInKRW), 12_500, accuracy: 0.0001)
    }

    func test_환율을_못_받으면_미확보로_남기고_합계에서_빠진다() throws {
        stubExchangeRates([:])

        let expense = try store.create(from: draft(amount: "10", currency: "USD"))

        XCTAssertNil(expense.validExchangeRate)
        XCTAssertNil(expense.amountInKRW)
        XCTAssertTrue(expense.needsExchangeRate)
    }

    func test_기록_당시_시간대를_남긴다() throws {
        let expense = try store.create(from: draft(amount: "1000", currency: "KRW"))

        XCTAssertEqual(expense.timeZoneIdentifier, TimeZone.current.identifier)
    }

    func test_상호명_앞뒤_공백을_다듬는다() throws {
        let expense = try store.create(from: draft(amount: "1000", currency: "KRW", merchant: "  흑돼지집  "))

        XCTAssertEqual(expense.info, "흑돼지집")
    }

    // MARK: - 수정

    // 오타를 고쳤다고 그날의 환율이 오늘 환율로 바뀌면 안 된다.
    func test_통화가_그대로면_기록_시점_환율을_보존한다() throws {
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))
        let originalRate = try XCTUnwrap(expense.validExchangeRate)

        // 환율이 바뀐 뒤에 상호명만 고친다.
        stubExchangeRates(["USD": 0.0005])   // 2000원으로 급등
        var edited = ReceiptDraft(from: expense)
        edited.merchant = "고친 이름"
        try store.update(expense, with: edited)

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), originalRate, accuracy: 0.0001,
                       "편집만 했는데 환율이 오늘 값으로 바뀌었습니다")
        XCTAssertEqual(expense.info, "고친 이름")
    }

    func test_통화를_바꾸면_환율을_새로_찍는다() throws {
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))

        var edited = ReceiptDraft(from: expense)
        edited.currency = "JPY"
        try store.update(expense, with: edited)

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), 1 / 0.11, accuracy: 0.0001)
    }

    // 처음에 환율을 못 받았던 건은, 편집할 때 채워 주는 편이 낫다.
    func test_환율이_비어_있던_건은_편집할_때_채운다() throws {
        stubExchangeRates([:])
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))
        XCTAssertNil(expense.validExchangeRate)

        stubExchangeRates(["USD": 0.0008])
        var edited = ReceiptDraft(from: expense)
        edited.merchant = "이름"
        try store.update(expense, with: edited)

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), 1_250, accuracy: 0.0001)
    }

    func test_사진만_붙이면_환율과_시간대를_건드리지_않는다() throws {
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))
        let rate = try XCTUnwrap(expense.validExchangeRate)
        let zone = expense.timeZoneIdentifier

        stubExchangeRates(["USD": 0.0005])
        try store.attachPhoto(Data([0x01, 0x02]), to: expense)

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), rate, accuracy: 0.0001)
        XCTAssertEqual(expense.timeZoneIdentifier, zone)
        XCTAssertFalse(expense.needsPhoto)
    }

    func test_현재_환율_사후_적용() throws {
        stubExchangeRates([:])
        let expense = try store.create(from: draft(amount: "10", currency: "USD"))

        stubExchangeRates(["USD": 0.0008])
        try store.applyCurrentExchangeRate(to: expense)

        XCTAssertEqual(try XCTUnwrap(expense.validExchangeRate), 1_250, accuracy: 0.0001)
    }

    // MARK: - 삭제

    func test_삭제하면_목록에서_사라진다() throws {
        let expense = try store.create(from: draft(amount: "1000", currency: "KRW"))
        XCTAssertEqual(try context.fetch(Expense.fetchRequest()).count, 1)

        try store.delete(expense)

        XCTAssertEqual(try context.fetch(Expense.fetchRequest()).count, 0)
    }

    // MARK: - 입력 검증

    func test_금액이_비었거나_음수면_유효하지_않다() {
        XCTAssertFalse(draft(amount: "", currency: "KRW").isValid)
        XCTAssertFalse(draft(amount: "-100", currency: "KRW").isValid)
        XCTAssertFalse(draft(amount: "0", currency: "KRW").isValid)
        XCTAssertTrue(draft(amount: "100", currency: "KRW").isValid)
    }

    func test_금액의_천단위_쉼표를_받아_준다() {
        XCTAssertEqual(draft(amount: "1,234", currency: "KRW").amount, 1_234)
    }

    // MARK: - 목록

    func test_임시_기록_여행은_선택지에서_뺀다() {
        makeTravel(isDefault: true)
        makeTravel(name: "제주 워크숍")

        let names = store.availableTravels().map { $0.name }

        XCTAssertEqual(names, ["제주 워크숍"])
    }
}
