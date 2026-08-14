//
//  WidgetQuickLogTests.swift
//  MwalletTests
//
//  홈 화면 위젯에서 담은 지출이 어디로 가는지.
//
//  위젯은 한 번 누르면 그대로 담기는 자리다. 잘못 담긴 것을 되돌릴 수 있는지,
//  그리고 엉뚱한 여행에 붙지 않는지를 지킨다. 돈이 어느 장부에 얹히는가는
//  나중에 눈으로 세기 어렵다.
//

import CoreData
import XCTest
@testable import Mwallet

final class WidgetQuickLogTests: CoreDataTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 앞선 시험이 남긴 큐가 섞이지 않게 비우고 시작한다.
        MwalletShared.drainQueue()
        MwalletShared.writeDestinationName(nil)
    }

    override func tearDown() {
        MwalletShared.drainQueue()
        MwalletShared.writeDestinationName(nil)
        super.tearDown()
    }

    private func pending(_ amount: Double, _ info: String) -> PendingExpense {
        PendingExpense(amount: amount, categoryIndex: 3, paymentMethodIndex: 0, info: info)
    }

    // MARK: - 되돌리기

    func test_방금_담은_것을_되돌린다() {
        MwalletShared.enqueue(pending(4_500, "커피"))
        MwalletShared.enqueue(pending(10_000, "식사"))

        let undone = MwalletShared.undoLast()

        XCTAssertEqual(undone?.info, "식사")
        XCTAssertEqual(MwalletShared.readQueue().map(\.info), ["커피"])
    }

    func test_되돌릴_것이_없으면_아무_일도_없다() {
        XCTAssertNil(MwalletShared.undoLast())
        XCTAssertTrue(MwalletShared.readQueue().isEmpty)
    }

    // 앱이 이미 가져간 뒤에는 뺄 것이 없다. 그때 되돌리기를 누르면
    // 엉뚱한(그 전에 담은) 것이 사라지면 안 된다.
    func test_앱이_가져간_뒤에는_되돌릴_것이_없다() {
        MwalletShared.enqueue(pending(4_500, "커피"))
        MwalletShared.drainQueue()

        XCTAssertNil(MwalletShared.undoLast())
    }

    func test_마지막으로_담은_것을_보여_준다() {
        XCTAssertNil(MwalletShared.lastPending)

        MwalletShared.enqueue(pending(4_500, "커피"))
        MwalletShared.enqueue(pending(3_000, "교통"))

        XCTAssertEqual(MwalletShared.lastPending?.info, "교통")
    }

    // MARK: - 어디로 담기는가

    // 여행 중이면 그 여행으로 간다. 예전에는 늘 기본함으로 보내서,
    // 방콕에 있는 동안 누른 것이 방콕 여행에 안 붙었다.
    func test_여행_중이면_그_여행에_담는다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        let now = Date()
        let bangkok = makeTravel(name: "방콕",
                                 start: now.addingTimeInterval(-2 * 86_400),
                                 end: now.addingTimeInterval(2 * 86_400))
        try context.save()

        XCTAssertEqual(MwalletBridge.destination(in: context)?.objectID, bangkok.objectID)
    }

    func test_여행_중이_아니면_기본함에_담는다() throws {
        let box = makeTravel(name: "임시 기록", isDefault: true)
        makeTravel(name: "지난 여행",
                   start: Date().addingTimeInterval(-30 * 86_400),
                   end: Date().addingTimeInterval(-25 * 86_400))
        try context.save()

        XCTAssertEqual(MwalletBridge.destination(in: context)?.objectID, box.objectID)
    }

    // 기간이 겹치면 늦게 시작한 것을 고른다. 앞의 여행이 아직 안 끝났는데
    // 다음 여행이 시작된 경우, 지금 있는 곳은 나중 쪽이다.
    func test_기간이_겹치면_늦게_시작한_여행이다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        let now = Date()
        makeTravel(name: "먼저", start: now.addingTimeInterval(-5 * 86_400),
                   end: now.addingTimeInterval(1 * 86_400))
        let later = makeTravel(name: "나중", start: now.addingTimeInterval(-1 * 86_400),
                               end: now.addingTimeInterval(4 * 86_400))
        try context.save()

        XCTAssertEqual(MwalletBridge.destination(in: context)?.displayName, later.displayName)
    }

    // MARK: - 옮기기

    func test_담긴_것이_실제_기록으로_옮겨진다() throws {
        makeTravel(name: "임시 기록", isDefault: true)
        try context.save()

        MwalletShared.enqueue(pending(4_500, "커피"))
        let moved = MwalletBridge.flushPendingExpenses(into: context)

        XCTAssertEqual(moved, 1)
        XCTAssertTrue(MwalletShared.readQueue().isEmpty, "옮긴 뒤에는 큐가 비어야 합니다")

        let saved = try context.fetch(Expense.fetchRequest())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.info, "커피")
        XCTAssertEqual(saved.first?.payAmount, 4_500)
    }

    // 담을 곳이 없으면 큐를 비우지 않는다. 비우면 그 기록은 어디에도 남지 않는다.
    func test_담을_여행이_없으면_큐를_지키고_보류한다() {
        MwalletShared.enqueue(pending(4_500, "커피"))

        let moved = MwalletBridge.flushPendingExpenses(into: context)

        XCTAssertEqual(moved, 0)
        XCTAssertEqual(MwalletShared.readQueue().count, 1, "보류한 기록이 사라졌습니다")
    }
}
