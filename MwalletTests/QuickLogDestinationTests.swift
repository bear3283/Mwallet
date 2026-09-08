//
//  QuickLogDestinationTests.swift
//  MwalletTests
//
//  앱이 위젯에 넘기는 '담길 곳' — 여행 이름과 통화와 프리셋.
//
//  QuickPresetSuggesterTests 가 고르는 규칙을 지킨다면, 여기는 그 규칙이
//  실제 장부에 붙었을 때 무엇이 나오는지를 지킨다. 통화가 어긋나면 위젯
//  단추가 거짓말을 하므로, 그 한 가지가 이 파일의 이유다.
//

import CoreData
import XCTest
@testable import Mwallet

final class QuickLogDestinationTests: CoreDataTestCase {

    private let day: TimeInterval = 86_400
    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    /// 위젯이 담을 곳이 되도록 '지금 다니는 중' 인 여행을 만든다.
    private func ongoingTravel(name: String) -> Travel {
        makeTravel(name: name,
                   start: Date().addingTimeInterval(-2 * day),
                   end: Date().addingTimeInterval(2 * day))
    }

    // MARK: - 통화

    // 위젯은 그 여행이 마지막으로 쓰던 통화로 저장한다. 넘겨 주는 통화가
    // 그것과 다르면 단추에 적힌 돈과 적히는 돈이 어긋난다.
    func test_그_여행이_쓰던_통화를_넘긴다() throws {
        let travel = ongoingTravel(name: "방콕")
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "커피", paidAt: Date().addingTimeInterval(-day))
        try context.save()

        let destination = try XCTUnwrap(MwalletBridge.quickLogDestination(in: context))
        XCTAssertEqual(destination.currencyCode, "THB")
        XCTAssertEqual(destination.travelName, "방콕")
    }

    // 아직 한 건도 없으면 물려받을 통화가 없다. 그 상태에서는 위젯이 담아도
    // 큐로 물러나므로, 금액이 적힌 단추를 보이면 담기는 척만 하는 셈이다.
    func test_기록이_없으면_통화도_프리셋도_비운다() throws {
        _ = ongoingTravel(name: "아직 안 간 여행")
        try context.save()

        let destination = try XCTUnwrap(MwalletBridge.quickLogDestination(in: context))
        XCTAssertEqual(destination.currencyCode, "")
        XCTAssertTrue(destination.presets.isEmpty)
    }

    // 국경을 넘어 통화가 바뀐 여행. 옛 통화의 금액을 올리면 자릿수가 어긋난다 —
    // 동(₫) 5만이 바트(฿) 5만으로 적히면 스무 배가 넘는다.
    func test_지금_쓰는_통화의_지출만_프리셋이_된다() throws {
        let travel = ongoingTravel(name: "인도차이나")
        // 옛 통화 — 여러 번 적었지만 이제 쓰지 않는다.
        for index in 1...3 {
            _ = makeExpense(travel: travel, amount: 50_000, currency: "VND", rate: 0.05,
                            merchant: "쌀국수",
                            paidAt: Date().addingTimeInterval(-Double(index + 3) * day))
        }
        // 지금 쓰는 통화 — 가장 최근이다.
        _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                        merchant: "커피", paidAt: Date().addingTimeInterval(-day))
        try context.save()

        let destination = try XCTUnwrap(MwalletBridge.quickLogDestination(in: context))
        XCTAssertEqual(destination.currencyCode, "THB")
        XCTAssertEqual(destination.presets.map(\.label), ["커피"],
                       "옛 통화(동)의 쌀국수가 바트 단추로 서면 안 된다")
    }

    // MARK: - 프리셋

    func test_자주_적은_것이_앞에_선다() throws {
        let travel = ongoingTravel(name: "방콕")
        for index in 1...3 {
            _ = makeExpense(travel: travel, amount: 60, currency: "THB", rate: 38,
                            merchant: "커피",
                            paidAt: Date().addingTimeInterval(-Double(index + 1) * day))
        }
        _ = makeExpense(travel: travel, amount: 900, currency: "THB", rate: 38,
                        category: .shopping, merchant: "기념품",
                        paidAt: Date().addingTimeInterval(-0.5 * day))
        try context.save()

        let destination = try XCTUnwrap(MwalletBridge.quickLogDestination(in: context))
        XCTAssertEqual(destination.presets.first?.label, "커피")
        XCTAssertEqual(destination.presets.first?.amount, 60)
    }

    // 큰 위젯이 다섯 칸을 쓰고, 중형은 그중 앞의 셋만 쓴다. 한 번 뽑아
    // 두 크기가 나눠 쓰므로 넘기는 개수가 큰 쪽에 맞아야 한다.
    func test_큰_위젯이_쓸_만큼_넘긴다() throws {
        let travel = ongoingTravel(name: "방콕")
        for index in 1...8 {
            _ = makeExpense(travel: travel, amount: Double(10 * index), currency: "THB", rate: 38,
                            merchant: "항목\(index)",
                            paidAt: Date().addingTimeInterval(-Double(index) * 3600))
        }
        try context.save()

        let destination = try XCTUnwrap(MwalletBridge.quickLogDestination(in: context))
        XCTAssertEqual(destination.presets.count, QuickPresetSpec.maxSlots)
        XCTAssertGreaterThan(QuickPresetSpec.maxSlots, QuickPresetSpec.mediumSlots,
                             "큰 위젯이 중형보다 많이 보여야 크게 놓는 뜻이 있다")
    }

    // MARK: - 담길 곳이 없을 때

    func test_담을_여행이_없으면_아무것도_넘기지_않는다() throws {
        let destination = MwalletBridge.quickLogDestination(in: context)
        XCTAssertNil(destination)
    }
}
