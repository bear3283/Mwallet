//
//  AppDestinationTests.swift
//  MwalletTests
//
//  위젯·단축어가 여는 링크가 제 탭으로 가는지.
//
//  링크 이름(`budget`)과 안에서 쓰는 이름(`ledger`)이 다르다. 이미 홈 화면에
//  놓인 위젯이 옛 이름으로 열고 있어, 새 이름만 받도록 정리해 버리면 그
//  위젯들이 조용히 먹통이 된다. 여기가 그걸 잡는 자리다.
//

import XCTest
@testable import Mwallet

final class AppDestinationTests: XCTestCase {

    func test_네_곳이_서로_다른_탭을_가리킨다() {
        let tabs = AppDestination.allCases.map(\.tab)

        XCTAssertEqual(Set(tabs).count, AppDestination.allCases.count,
                       "두 곳이 같은 탭을 가리킵니다: \(tabs)")
    }

    func test_위젯_링크가_제_탭으로_간다() throws {
        XCTAssertEqual(AppDestination(deepLink: try url("mwallet://record"))?.tab,
                       MainViewModel.Tab.record)
        XCTAssertEqual(AppDestination(deepLink: try url("mwallet://receipt"))?.tab,
                       MainViewModel.Tab.receipt)
        XCTAssertEqual(AppDestination(deepLink: try url("mwallet://travel"))?.tab,
                       MainViewModel.Tab.travel)
    }

    func test_예결산은_옛_이름과_새_이름을_모두_받는다() throws {
        XCTAssertEqual(AppDestination(deepLink: try url("mwallet://budget"))?.tab,
                       MainViewModel.Tab.ledger)
        XCTAssertEqual(AppDestination(deepLink: try url("mwallet://ledger"))?.tab,
                       MainViewModel.Tab.ledger)
    }

    func test_남의_링크는_받지_않는다() throws {
        XCTAssertNil(AppDestination(deepLink: try url("https://record")))
        XCTAssertNil(AppDestination(deepLink: try url("mwallet://없는곳")))
    }

    private func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }
}
