//
//  ScreenshotTests.swift
//  MwalletUITests
//
//  화면을 눈으로 확인하기 위한 캡처.
//  검증 로직이 아니라 도구다 — 디자인을 손볼 때 실제 렌더링을 보고 판단하려고 둔다.
//
//  실행:
//    xcodebuild test -scheme Mwallet -only-testing:MwalletUITests \
//      -resultBundlePath <경로>.xcresult
//    xcrun xcresulttool export attachments --path <경로>.xcresult --output-path <폴더>
//

import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        } else {
            // 탭바가 커스텀이면 일반 버튼으로도 찾아본다.
            app.buttons[label].firstMatch.tap()
        }
        // 전환 애니메이션이 끝나기를 기다린다.
        Thread.sleep(forTimeInterval: 1.5)
    }

    func test_모든_탭을_캡처한다() throws {
        capture("01-기록")

        tapTab("예결산")
        capture("02-예결산")

        tapTab("영수증")
        capture("03-영수증")

        tapTab("여행")
        capture("04-여행지도")

        // 여행 요약 줄을 누르면 여행 상세로 들어간다.
        let summary = app.buttons.containing(.staticText, identifier: "예시: 제주 워크숍").firstMatch
        if summary.waitForExistence(timeout: 3) {
            summary.tap()
            Thread.sleep(forTimeInterval: 2)
            capture("05-여행상세")

            // 우상단 연필 → 여행 편집
            let edit = app.buttons["square.and.pencil"].firstMatch
            if edit.waitForExistence(timeout: 3) {
                edit.tap()
                Thread.sleep(forTimeInterval: 1.5)
                capture("06-여행편집")
            }
        }
    }
}
