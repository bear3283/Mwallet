//
//  StoreScreenshotTests.swift
//  MwalletUITests
//
//  App Store 에 올릴 화면. 언어마다 한 벌씩 찍는다.
//
//  ─────────────────────────────────────────────────────────────
//  ScreenshotTests 와 무엇이 다른가
//
//  저쪽은 디자인을 손볼 때 실제 렌더링을 보려고 두는 내부 도구다. 서른 장을
//  찍고, 시트를 열고 사진을 넘겨 가며 구석구석 들어간다. 그리고 화면을
//  옮겨 다닐 때 한국어 라벨을 쓴다 — tapTab("예결산") 같은 식이라 다른
//  언어로는 애초에 돌지 않는다.
//
//  이쪽은 스토어에 걸 넉 장이다. 그래서 두 가지가 다르다.
//
//    * 라벨 대신 자리(index)로 옮긴다. 탭 차례는 언어를 타지 않는다
//    * 언어를 밖에서 받는다. 열한 번 돌려 열한 벌을 만든다
//
//  구석구석 들어가지 않는 것도 뜻이 있다. 스토어에서 사람이 보는 것은
//  '이 앱이 무엇인가' 이고, 그건 네 탭이 다 말한다.
//  ─────────────────────────────────────────────────────────────
//
//  혼자 돌리면 기기 언어로 한 벌만 나온다. 열한 벌은 fastlane 이 만든다.
//  (언어는 xcodebuild 의 -testLanguage / -testRegion 이 정한다)
//
//      bundle exec fastlane store_screenshots
//

import XCTest

@MainActor
final class StoreScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
        app = XCUIApplication()

        // 언어는 xcodebuild 가 -testLanguage / -testRegion 으로 넣어 준다.
        // 그러면 앱만 그 언어로 뜨고 기기 설정은 그대로다 — 시뮬레이터
        // 언어를 바꾸면 되돌리는 일이 남고, 열한 번 돌리는 사이에 하나라도
        // 어긋나면 섞인 벌이 나온다.
        app.launch()

        // 스플래시가 지나가고 탭바가 올라올 때까지 기다린다.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "탭바가 나타나지 않았습니다")
        settle()
    }

    // MARK: - 도구

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 애니메이션이 끝나기를 기다린다. 전환 중에 찍으면 흐릿한 장이 남는다.
    private func settle(_ seconds: TimeInterval = 1.4) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// 자리로 탭을 고른다.
    ///
    /// 라벨로 고르면 언어마다 다른 글자를 알아야 한다. 차례는 어느 언어에서도
    /// 같으므로 여기서는 자리가 더 튼튼하다.
    /// (MainViewModel.Tab — 여행 0 · 예결산 1 · 기록 2 · 영수증 3)
    private func tapTab(at index: Int, _ what: String) {
        let tab = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(what) 탭을 찾지 못했습니다")
        tab.tap()
        settle()
    }

    // MARK: - 스토어에 걸 넉 장

    func test_스토어_화면을_찍는다() throws {
        // 앱을 열면 서는 자리. 이 앱이 무엇을 하는 앱인지 한 화면으로 말한다.
        tapTab(at: 2, "기록")
        capture("01-record")

        tapTab(at: 1, "예결산")
        capture("02-budget")

        tapTab(at: 3, "영수증")
        capture("03-receipt")

        tapTab(at: 0, "여행")
        capture("04-travel")
    }
}
