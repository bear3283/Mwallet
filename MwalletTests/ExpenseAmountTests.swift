//
//  ExpenseAmountTests.swift
//  MwalletTests
//
//  Expense 의 금액 환산. 화면·통계·예결산·CSV 가 모두 amountInKRW 하나를 쓰므로
//  여기가 틀리면 네 곳이 함께 틀린다.
//

import CoreData
import XCTest
@testable import Mwallet

final class ExpenseAmountTests: CoreDataTestCase {


    // MARK: - 유효 환율

    func test_환율이_0이거나_음수면_유효하지_않다() {
        XCTAssertNil(makeExpense(amount: 100, currency: "USD", rate: 0).validExchangeRate)
        XCTAssertNil(makeExpense(amount: 100, currency: "USD", rate: Expense.unknownExchangeRate).validExchangeRate)
        XCTAssertEqual(makeExpense(amount: 100, currency: "USD", rate: 1300).validExchangeRate, 1300)
    }

    // MARK: - 원화 환산

    func test_원화는_환율_없이_금액_그대로_쓴다() {
        // 원화 기록은 환율을 못 받았어도 금액이 그대로 유효해야 한다.
        let expense = makeExpense(amount: 12_000, currency: "KRW", rate: Expense.unknownExchangeRate)

        XCTAssertEqual(expense.amountInKRW, 12_000)
    }

    func test_외화는_기록_시점_환율로_환산한다() {
        let expense = makeExpense(amount: 10, currency: "USD", rate: 1300)

        XCTAssertEqual(try XCTUnwrap(expense.amountInKRW), 13_000, accuracy: 0.0001)
    }

    // 환산할 수 없는 건은 0 이 아니라 nil 이어야 한다.
    // 0 으로 떨어지면 합계에 조용히 섞여 총액이 실제보다 작아진다.
    func test_환율을_못_받은_외화는_nil_이다() {
        let expense = makeExpense(amount: 10, currency: "USD", rate: Expense.unknownExchangeRate)

        XCTAssertNil(expense.amountInKRW)
        XCTAssertTrue(expense.needsExchangeRate)
        XCTAssertEqual(expense.formattedAmountInKRW, "-")
    }

    func test_원화_기록은_환율이_필요하지_않다() {
        let expense = makeExpense(amount: 5_000, currency: "KRW", rate: 1)

        XCTAssertFalse(expense.needsExchangeRate)
    }

    // MARK: - 국가

    // 예전 기본값은 0(대한민국)이라, 국가를 한 번도 정하지 않은 기록
    // (영수증 탭으로 만든 것 전부)이 국내 지출로 표시됐다.
    func test_국가를_정하지_않은_기록은_알_수_없음이다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)

        XCTAssertEqual(expense.country, ExpenseCode.unknownCountry)
        XCTAssertEqual(CountryInfoModel.shared.countryResult[Int(expense.country)]?.koreanNm, "알 수 없음")
    }

    // MARK: - 시간대

    func test_기록_당시_시간대를_보존한다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)
        expense.timeZoneIdentifier = "Asia/Tokyo"

        XCTAssertEqual(expense.recordedTimeZone.identifier, "Asia/Tokyo")
    }

    func test_시간대가_없으면_기기_시간대로_대체한다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)
        expense.timeZoneIdentifier = nil

        XCTAssertEqual(expense.recordedTimeZone.identifier, TimeZone.current.identifier)
    }

    // MARK: - 표시용 값

    func test_상호명이_비면_기본_문구를_준다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)
        expense.info = ""

        XCTAssertEqual(expense.merchantName, "상호 미입력")
    }

    func test_여행에_배정되지_않은_기록은_미분류다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)

        // 여행이 없으면 미분류.
        XCTAssertEqual(expense.missionTitle, "미분류")

        // 기본함('임시 기록')에 담겨 있어도 미분류.
        // 이름을 바꿔도 기본함인 사실은 그대로라 여전히 미분류다.
        let box = makeTravel(isDefault: true)
        expense.travel = box
        XCTAssertEqual(expense.missionTitle, "미분류")

        box.name = "아무 이름"
        XCTAssertEqual(expense.missionTitle, "미분류")

        // 사용자가 만든 여행에 배정되면 그 이름으로 묶인다.
        expense.travel = makeTravel(name: "제주 워크숍")
        XCTAssertEqual(expense.missionTitle, "제주 워크숍")
    }

    func test_사진이_없는_기록을_구분한다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)

        XCTAssertTrue(expense.needsPhoto)

        expense.imageData = Data([0x01, 0x02])
        XCTAssertFalse(expense.needsPhoto)
    }

    func test_좌표는_둘_다_있어야_유효하다() {
        let expense = makeExpense(amount: 1, currency: "KRW", rate: 1)

        XCTAssertNil(expense.coordinate)

        expense.setCoordinate(.init(latitude: 33.4, longitude: 126.5))
        XCTAssertEqual(try XCTUnwrap(expense.coordinate).latitude, 33.4, accuracy: 0.0001)

        expense.setCoordinate(nil)
        XCTAssertNil(expense.coordinate)
    }
}
