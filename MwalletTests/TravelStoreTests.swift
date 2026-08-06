//
//  TravelStoreTests.swift
//  MwalletTests
//
//  여행 편집. 여행에는 지출·예산이 Cascade 로 딸려 있어, 저장이 잘못되면
//  기록까지 함께 흔들린다.
//

import XCTest
@testable import Mwallet

final class TravelStoreTests: CoreDataTestCase {

    private var store: TravelStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = TravelStore(context: context)
    }

    // MARK: - 저장

    func test_이름과_기간과_인원을_고친다() throws {
        let travel = makeTravel(name: "제주 워크숍", participants: ["동료"])
        var draft = TravelDraft(from: travel)
        draft.name = "제주 사역"
        draft.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.endDate = Date(timeIntervalSince1970: 1_700_500_000)
        draft.participants = ["동료", "간사"]

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.name, "제주 사역")
        XCTAssertEqual(travel.startDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(travel.endDate, Date(timeIntervalSince1970: 1_700_500_000))
        XCTAssertEqual(travel.participantArray, ["동료", "간사"])
    }

    func test_이름_앞뒤_공백을_다듬는다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.name = "  제주 사역  "

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.name, "제주 사역")
    }

    func test_종료일을_지울_수_있다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.endDate = nil

        try store.update(travel, with: draft)

        XCTAssertNil(travel.endDate)
    }

    func test_수정_시각을_남긴다() throws {
        let travel = makeTravel()
        travel.lastUpdate = Date(timeIntervalSince1970: 0)
        let draft = TravelDraft(from: travel)

        try store.update(travel, with: draft)

        XCTAssertGreaterThan(try XCTUnwrap(travel.lastUpdate), Date(timeIntervalSince1970: 1))
    }

    // MARK: - 검증

    func test_이름이_비면_저장하지_않는다() {
        let travel = makeTravel(name: "제주 워크숍")
        var draft = TravelDraft(from: travel)
        draft.name = "   "

        XCTAssertFalse(draft.isValid)
        XCTAssertThrowsError(try store.update(travel, with: draft)) { error in
            XCTAssertEqual(error as? TravelStoreError, .emptyName)
        }
        XCTAssertEqual(travel.name, "제주 워크숍", "실패했는데 값이 바뀌었습니다")
    }

    func test_종료일이_시작일보다_빠르면_저장하지_않는다() {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.startDate = Date(timeIntervalSince1970: 1_700_500_000)
        draft.endDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertFalse(draft.hasValidPeriod)
        XCTAssertThrowsError(try store.update(travel, with: draft)) { error in
            XCTAssertEqual(error as? TravelStoreError, .endBeforeStart)
        }
    }

    func test_종료일이_시작일과_같으면_허용한다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        let sameDay = Date(timeIntervalSince1970: 1_700_000_000)
        draft.startDate = sameDay
        draft.endDate = sameDay

        XCTAssertTrue(draft.hasValidPeriod)
        try store.update(travel, with: draft)
        XCTAssertEqual(travel.endDate, sameDay)
    }

    func test_종료일이_없으면_기간_검증을_통과한다() {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.endDate = nil

        XCTAssertTrue(draft.isValid)
    }

    // MARK: - 인원 정리

    func test_빈_칸과_중복과_나를_걷어낸다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.participants = ["동료", "", "  ", "동료", "나", "간사"]

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.participantArray, ["동료", "간사"], "'나' 는 화면이 항상 앞에 붙이므로 저장하면 두 번 나옵니다")
    }

    func test_인원_순서를_보존한다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        // '나' 는 본인을 뜻하는 예약어라 섞지 않는다. 아래 테스트에서 따로 다룬다.
        draft.participants = ["지훈", "民수", "예린"]

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.participantArray, ["지훈", "民수", "예린"],
                       "Set 으로 중복을 지우면 순서가 흐트러집니다")
    }

    // '나' 는 화면이 목록 맨 앞에 항상 붙인다. 저장 목록에도 두면 두 번 나온다.
    // 그래서 참가자 이름으로는 쓸 수 없다. 기존 생성 흐름(AddMemberViewModel)도 같다.
    func test_나는_참가자_이름으로_쓸_수_없다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.participants = ["나", "지훈"]

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.participantArray, ["지훈"])
    }

    func test_인원_이름의_공백을_다듬는다() throws {
        let travel = makeTravel()
        var draft = TravelDraft(from: travel)
        draft.participants = ["  동료  "]

        try store.update(travel, with: draft)

        XCTAssertEqual(travel.participantArray, ["동료"])
    }

    // MARK: - 딸린 기록

    func test_편집해도_지출과_예산은_그대로_남는다() throws {
        let travel = makeTravel(name: "제주 워크숍")
        makeExpense(travel: travel, amount: 48_000)
        makeBudget(travel: travel, category: .food, amount: 60_000)
        try context.save()

        var draft = TravelDraft(from: travel)
        draft.name = "제주 사역"
        try store.update(travel, with: draft)

        let budgetStore = BudgetStore(context: context)
        XCTAssertEqual(budgetStore.expenses(for: travel).count, 1)
        XCTAssertEqual(budgetStore.summary(for: travel).totalPlanned, 60_000)
        XCTAssertEqual(budgetStore.summary(for: travel).totalSpent, 48_000)
    }
}
