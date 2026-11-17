//
//  ExpenseFormRulesTests.swift
//  MwalletTests
//
//  폼이 하나로 합쳐지면서 생긴 규칙들.
//  금액을 기기 언어로 읽는 것, 새 초안이 여행에서 물려받는 것,
//  함께 쓴 사람과 결제 수단이 저장·수정되는 것, '지금 보는 여행' 을 정하는 것.
//

import XCTest
@testable import Mwallet

final class ExpenseFormRulesTests: CoreDataTestCase {

    private var store: ReceiptStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = ReceiptStore(context: context)
        stubExchangeRates(["THB": 0.025])
    }

    // MARK: - 금액 읽기

    func test_쉼표가_소수점인_언어에서_금액이_백_배가_되지_않는다() {
        let german = Locale(identifier: "de_DE")

        XCTAssertEqual(ReceiptDraft.parseAmount("15,50", locale: german), 15.5)
        XCTAssertEqual(ReceiptDraft.parseAmount("1.234,5", locale: german), 1234.5)
    }

    func test_쉼표가_자릿점인_언어에서는_걷어낸다() {
        let korean = Locale(identifier: "ko_KR")

        XCTAssertEqual(ReceiptDraft.parseAmount("12,000", locale: korean), 12_000)
        XCTAssertEqual(ReceiptDraft.parseAmount("24.5", locale: korean), 24.5)
    }

    func test_적어_준_금액을_같은_언어로_다시_읽으면_그대로다() {
        for identifier in ["ko_KR", "en_US", "de_DE", "fr_FR", "pt_BR"] {
            let locale = Locale(identifier: identifier)
            let text = ReceiptDraft.editableAmountText(24.5, locale: locale)

            XCTAssertEqual(ReceiptDraft.parseAmount(text, locale: locale), 24.5, identifier)
        }
    }

    // MARK: - 새 초안

    func test_새_초안은_그_여행에서_마지막으로_쓴_통화를_물려받는다() {
        let travel = makeTravel(participants: ["민수"])
        makeExpense(travel: travel, amount: 60, currency: "THB", rate: 40)

        let draft = store.newDraft(for: travel)

        XCTAssertEqual(draft.currency, "THB")
        XCTAssertEqual(draft.travel, travel)
        XCTAssertEqual(draft.participants, [Travel.selfParticipantName, "민수"])
    }

    func test_적은_것이_없는_여행은_통화를_짐작하지_않는다() {
        let travel = makeTravel()

        XCTAssertNil(store.inheritedMoney(for: travel))
        XCTAssertEqual(store.newDraft(for: travel).currency, ExpenseCode.baseCurrency)
    }

    func test_기본함은_여행으로_치지_않는다() {
        let box = makeTravel(isDefault: true)

        XCTAssertNil(store.newDraft(for: box).travel)
    }

    // MARK: - 함께 쓴 사람 · 결제 수단

    func test_함께_쓴_사람과_결제_수단을_저장한다() throws {
        var draft = store.newDraft(for: makeTravel(participants: ["민수", "지영"]))
        draft.amountText = "30000"
        draft.participants = [Travel.selfParticipantName, "지영"]
        draft.paymentMethod = .card

        let expense = try store.create(from: draft)

        XCTAssertEqual(expense.participants, [Travel.selfParticipantName, "지영"])
        XCTAssertEqual(expense.paymentMethod, Int64(PaymentMethod.card.rawValue))
    }

    func test_저장한_뒤에도_함께_쓴_사람을_고칠_수_있다() throws {
        let expense = makeExpense(travel: makeTravel(participants: ["민수"]),
                                  participants: [Travel.selfParticipantName, "민수"])

        var draft = ReceiptDraft(from: expense)
        XCTAssertEqual(draft.participants, [Travel.selfParticipantName, "민수"])
        draft.participants = [Travel.selfParticipantName]
        try store.update(expense, with: draft)

        XCTAssertEqual(expense.participants, [Travel.selfParticipantName])
    }

    func test_고쳐도_나라는_그대로_남는다() throws {
        let expense = makeExpense()
        expense.country = 3

        try store.update(expense, with: ReceiptDraft(from: expense))

        XCTAssertEqual(expense.country, 3)
    }

    // MARK: - 지금 보는 여행

    func test_여행_중이면_그_여행이_지금_보는_여행이다() {
        let now = Date()
        makeTravel(name: "지난 여행", start: now.addingTimeInterval(-30 * 86_400))
        let ongoing = makeTravel(name: "여행 중", start: now.addingTimeInterval(-86_400))
        makeTravel(isDefault: true)

        XCTAssertEqual(TravelStore(context: context).ongoingTravel(now: now), ongoing)
    }

    func test_여행_중이_아니면_지난_여행을_짐작해_고르지_않는다() {
        let now = Date()
        makeTravel(name: "지난 여행", start: now.addingTimeInterval(-30 * 86_400))
        makeTravel(isDefault: true)

        XCTAssertNil(TravelStore(context: context).ongoingTravel(now: now))
    }
}
