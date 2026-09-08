//
//  TravelExchangeRateTests.swift
//  MwalletTests
//
//  한 여행 안에서 환율을 하나로 묶는 규칙.
//
//  돈이 저장되는 자리다. 한 번 박힌 환율은 지출에 남아 합계·정산·CSV 로
//  흘러가고 나중에 되돌릴 수 없다. 그래서 규칙을 여기서 못 박는다.
//

import CoreData
import XCTest
@testable import Mwallet

final class TravelExchangeRateTests: CoreDataTestCase {

    private let day: TimeInterval = 86_400
    private var start: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    // MARK: - 처음 쓴 환율을 이어 쓴다

    func test_그_여행이_처음_쓴_환율을_돌려준다() throws {
        let travel = makeTravel(name: "방콕")
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "첫날 커피", paidAt: start)
        _ = makeExpense(travel: travel, amount: 120, currency: "THB", rate: 41,
                        merchant: "사흘째 점심", paidAt: start.addingTimeInterval(3 * day))
        try context.save()

        let rate = TravelExchangeRate.anchoredRate(for: travel, currencyCode: "THB")
        XCTAssertEqual(rate, 38, "나중에 환율이 41 로 올랐어도 첫날 38 을 이어 쓴다")
    }

    // 적은 차례가 아니라 지출한 날짜가 기준이다. 여행 첫날 영수증을 나중에
    // 적어도 그것이 '처음' 이다.
    func test_늦게_적었어도_지출한_날짜가_이르면_그것이_기준이다() throws {
        let travel = makeTravel(name: "방콕")
        _ = makeExpense(travel: travel, amount: 120, currency: "THB", rate: 41,
                        merchant: "사흘째", paidAt: start.addingTimeInterval(3 * day))
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "첫날 영수증", paidAt: start)
        try context.save()

        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "THB"), 38)
    }

    func test_아직_적은_것이_없으면_기준이_없다() throws {
        let travel = makeTravel(name: "아직 안 간 여행")
        try context.save()

        XCTAssertNil(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "THB"))
    }

    func test_여행이_없으면_기준이_없다() {
        XCTAssertNil(TravelExchangeRate.anchoredRate(for: nil, currencyCode: "THB"))
    }

    // MARK: - 통화별로 묶는다

    // 한 여행이 국경을 넘는 일이 있다. 여행 하나에 환율 하나로 묶어 버리면
    // 동(₫)에 바트(฿) 환율이 붙어 스무 배가 넘게 어긋난다.
    func test_통화가_다르면_따로_묶는다() throws {
        let travel = makeTravel(name: "인도차이나")
        _ = makeExpense(travel: travel, amount: 50_000, currency: "VND", rate: 0.056,
                        merchant: "쌀국수", paidAt: start)
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "커피", paidAt: start.addingTimeInterval(5 * day))
        try context.save()

        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "VND"), 0.056)
        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "THB"), 38)
    }

    // MARK: - 환율을 못 받은 지출은 기준이 되지 못한다

    // 그것을 기준으로 삼으면 그 뒤에 적는 것이 모두 합계에서 빠진다.
    func test_환율을_못_받은_지출은_건너뛴다() throws {
        let travel = makeTravel(name: "방콕")
        let offline = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 1,
                                  merchant: "비행기에서", paidAt: start)
        offline.exchangeRate = Expense.unknownExchangeRate
        _ = makeExpense(travel: travel, amount: 120, currency: "THB", rate: 38,
                        merchant: "도착 후", paidAt: start.addingTimeInterval(day))
        try context.save()

        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "THB"), 38,
                       "환율을 못 받은 건이 기준이 되면 그 뒤가 모두 합계에서 빠진다")
    }

    // MARK: - 원화

    func test_원화는_언제나_1이다() throws {
        let travel = makeTravel(name: "속초")
        try context.save()

        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: travel, currencyCode: "KRW"), 1)
    }

    // MARK: - 여행끼리는 섞이지 않는다

    func test_다른_여행의_환율을_가져오지_않는다() throws {
        let spring = makeTravel(name: "봄 방콕")
        _ = makeExpense(travel: spring, amount: 60, currency: "THB", rate: 38,
                        merchant: "봄 커피", paidAt: start)
        let autumn = makeTravel(name: "가을 방콕")
        _ = makeExpense(travel: autumn, amount: 60, currency: "THB", rate: 44,
                        merchant: "가을 커피", paidAt: start.addingTimeInterval(180 * day))
        try context.save()

        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: spring, currencyCode: "THB"), 38)
        XCTAssertEqual(TravelExchangeRate.anchoredRate(for: autumn, currencyCode: "THB"), 44,
                       "여행이 다르면 환율도 새로 잡는다")
    }

    // MARK: - 위젯도 같은 환율을 쓴다

    // 앱에서 적는 것과 위젯으로 담는 것이 다른 환율이면 한 여행의 셈이 갈린다.
    func test_위젯이_물려받는_환율도_그_여행의_첫_환율이다() throws {
        let travel = makeTravel(name: "방콕",
                                start: Date().addingTimeInterval(-3 * day),
                                end: Date().addingTimeInterval(2 * day))
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "첫날", paidAt: Date().addingTimeInterval(-3 * day))
        _ = makeExpense(travel: travel, amount: 120, currency: "THB", rate: 41,
                        merchant: "어제", paidAt: Date().addingTimeInterval(-day))
        try context.save()

        let money = try XCTUnwrap(QuickExpenseStore.inheritedMoney(of: travel))
        XCTAssertEqual(money.exchangeRate, 38,
                       "위젯도 여행의 첫 환율을 쓴다 — 마지막 환율(41)이 아니다")
        XCTAssertEqual(money.currency, ExpenseCode.currencyIndex(for: "THB"),
                       "통화는 마지막에 적은 것을 따른다 — 지금 있는 곳이 그곳이다")
    }
}
