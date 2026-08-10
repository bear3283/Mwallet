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
//    xcrun xcresulttool export attachments --path <경로>.xcresult \
//      --output-path <폴더>
//
//  화면 이름은 파일명 앞에 붙는다(01-기록, 02-예결산 …).
//

import XCTest

// XCUIApplication 을 비롯한 XCUITest API 는 메인 액터에 묶여 있다.
// 클래스 전체를 메인에 두어야 엄격 동시성 검사에서 깨끗하다.
@MainActor
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    // setUpWithError 는 nonisolated 오버라이드라 메인 액터 멤버를 부를 수 없다.
    // async 형태는 클래스의 @MainActor 격리를 물려받는다.
    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // 스플래시가 지나가고 탭바가 올라올 때까지 기다린다.
        // 기다리지 않으면 첫 장이 스플래시로 찍힌다.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "탭바가 나타나지 않았습니다")
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
    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "'\(label)' 탭을 찾지 못했습니다")
        tab.tap()
        settle()
    }

    /// 화면에 보이는 첫 번째 요소를 눌러 본다. 못 찾으면 false.
    @discardableResult
    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        guard element.waitForExistence(timeout: timeout), element.isHittable else { return false }
        element.tap()
        settle()
        return true
    }

    // MARK: - 탭 네 개

    func test_01_탭을_캡처한다() throws {
        capture("01-기록")

        tapTab("예결산")
        capture("02-예결산")

        tapTab("영수증")
        capture("03-영수증")

        tapTab("여행")
        capture("04-여행목록")
    }

    // MARK: - 여행 선택 시트

    func test_02_여행_선택_시트를_캡처한다() throws {
        // 여행 탭이 목록이 되면서 선택기는 예결산 탭에만 남았다.
        tapTab("예결산")

        // 여는 버튼은 여행 이름 + 기간을 담은 큰 버튼이다.
        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "~")).firstMatch
        guard tapIfExists(picker) else {
            XCTFail("여행 선택 버튼을 찾지 못했습니다. 화면 구조가 바뀌었는지 확인해 주세요.")
            return
        }
        capture("05-여행선택시트")

        // 시트를 닫아 다음 테스트에 영향을 주지 않는다.
        tapIfExists(app.buttons["닫기"])
    }

    // MARK: - 여행 상세 · 편집

    func test_03_여행_상세와_편집을_캡처한다() throws {
        tapTab("여행")

        // 여행 카드 한 장을 누르면 상세로 들어간다.
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "예시")).firstMatch
        guard tapIfExists(card) else {
            XCTFail("여행 카드를 찾지 못했습니다.")
            return
        }
        settle(1.5)
        capture("06-여행상세")

        // 목록 아래쪽까지 보이도록 한 번 스크롤한 장도 남긴다.
        app.swipeUp()
        settle()
        capture("07-여행상세-아래")

        // 우상단 연필 → 여행 편집
        let edit = app.navigationBars.buttons.element(boundBy: 1)
        guard tapIfExists(edit) else {
            XCTFail("편집 버튼을 찾지 못했습니다.")
            return
        }
        capture("08-여행편집")
    }

    // MARK: - 여행 생성 (대표 사진)
    //
    // 이 흐름은 실제로 여행을 하나 만든다. 시뮬레이터 데이터가 늘어나므로
    // 평소 실행에서는 건너뛰고, 필요할 때만 이름을 지정해 돌린다.
    //   -only-testing:MwalletUITests/ScreenshotTests/test_04_여행_생성을_캡처한다

    func test_04_여행_생성을_캡처한다() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_CREATE_FLOW"] == "1",
                          "여행을 실제로 만드는 흐름이라 CAPTURE_CREATE_FLOW=1 일 때만 돈다")

        tapTab("여행")
        // 탭 동작 버튼은 네비게이션 바가 아니라 본문 첫 줄에 있다.
        // 예전에는 navigationBars.buttons 를 순서로 집었는데, 툴바를 숨기면서
        // 아무것도 찾지 못하게 됐다. 이 테스트는 꺼 둔 채라 그 사실도 묻혔다.
        guard tapIfExists(app.buttons["tabAction.plus"].firstMatch) else {
            XCTFail("여행 추가(+) 버튼을 찾지 못했습니다.")
            return
        }
        capture("09-여행생성-날짜")

        // 달력에서 오늘을 고르고 다음 단계로.
        let today = Calendar.current.component(.day, from: Date())
        tapIfExists(app.staticTexts["\(today)"].firstMatch)
        tapIfExists(app.buttons["다음"].firstMatch)
        settle()
        capture("10-여행생성-인원")

        tapIfExists(app.buttons["완료"].firstMatch)
        settle(1.5)
        capture("11-여행생성-완료")
    }
}
