//
//  DefaultTravelTests.swift
//  MwalletTests
//
//  '임시 기록' 기본함 판별. 예전에는 이름이 특정 이모지 문자열인지로 가렸는데,
//  여행 편집 화면이 생기면서 이름이 사용자가 고칠 수 있는 값이 됐다.
//

import XCTest
@testable import Mwallet

final class DefaultTravelTests: CoreDataTestCase {

    // MARK: - 판별

    func test_기본함과_사용자_여행을_가른다() {
        let box = makeTravel(isDefault: true)
        let trip = makeTravel(name: "제주 워크숍")

        XCTAssertTrue(box.isDefault)
        XCTAssertFalse(box.isUserCreated)
        XCTAssertFalse(trip.isDefault)
        XCTAssertTrue(trip.isUserCreated)
    }

    func test_새_여행은_기본함이_아니다() {
        // Core Data 기본값이 NO 라 따로 지정하지 않아도 사용자 여행이어야 한다.
        let travel = Travel(context: context)

        XCTAssertFalse(travel.isDefault)
    }

    func test_기본함을_찾아온다() {
        makeTravel(name: "제주 워크숍")
        let box = makeTravel(isDefault: true)

        XCTAssertEqual(Travel.fetchDefault(in: context), box)
    }

    func test_기본함이_없으면_nil_이다() {
        makeTravel(name: "제주 워크숍")

        XCTAssertNil(Travel.fetchDefault(in: context))
    }

    // MARK: - 표시 이름

    func test_기본함은_임시_기록으로_보인다() {
        XCTAssertEqual(makeTravel(isDefault: true).displayName, "임시 기록")
    }

    func test_이름이_비면_대체_문구를_준다() {
        let travel = makeTravel(name: "")

        XCTAssertEqual(travel.displayName, "이름 없는 여행")
    }

    // MARK: - 이름과 무관하게 동작하는가

    // 예전 규칙이었다면 이름을 바꾸는 순간 기본함이 일반 여행으로 바뀌어
    // 위젯 기록이 갈 곳을 잃었다.
    func test_이름을_바꿔도_기본함은_기본함이다() {
        let box = makeTravel(isDefault: true)

        box.name = "아무 이름"

        XCTAssertTrue(box.isDefault)
        XCTAssertEqual(Travel.fetchDefault(in: context), box)
    }

    // 반대로, 예전 이모지 이름을 쓴다고 해서 기본함이 되지는 않는다.
    func test_옛_이름을_써도_기본함이_되지_않는다() {
        let travel = makeTravel(name: Travel.legacyDefaultName)

        XCTAssertFalse(travel.isDefault)
        XCTAssertNil(Travel.fetchDefault(in: context))
    }

    // MARK: - 목록에서 제외

    func test_기본함은_예산과_영수증_선택지에_오르지_않는다() {
        makeTravel(isDefault: true)
        makeTravel(name: "제주 워크숍")

        XCTAssertEqual(BudgetStore(context: context).availableTravels().map(\.displayName), ["제주 워크숍"])
        XCTAssertEqual(ReceiptStore(context: context).availableTravels().map(\.displayName), ["제주 워크숍"])
    }

    func test_기본함에_담긴_지출은_미분류다() {
        let box = makeTravel(isDefault: true)
        let expense = makeExpense(travel: box)

        XCTAssertEqual(expense.missionTitle, "미분류")
    }

    // MARK: - 편집 차단

    func test_기본함은_편집할_수_없다() {
        let box = makeTravel(isDefault: true)
        var draft = TravelDraft(from: box)
        draft.name = "고친 이름"

        XCTAssertThrowsError(try TravelStore(context: context).update(box, with: draft)) { error in
            XCTAssertEqual(error as? TravelStoreError, .cannotEditDefault)
        }
        XCTAssertEqual(box.displayName, "임시 기록")
    }
}
