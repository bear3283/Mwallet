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

    // 개발용 CloudKit 스키마 배포 버튼이 설정 화면에 있다.
    func test_05_설정을_캡처한다() throws {
        tapTab("여행")
        guard tapIfExists(app.buttons["tabAction.gearshape"].firstMatch) else {
            XCTFail("설정 버튼을 찾지 못했습니다.")
            return
        }
        settle()
        // 목록 아래쪽의 개발용 절까지 보이도록 한 번 내린다.
        app.swipeUp()
        settle()
        capture("11-설정")
    }

    func test_02_여행_선택_시트를_캡처한다() throws {
        tapTab("예결산")

        // 여는 버튼은 여행 이름 + 기간을 담은 큰 버튼이다.
        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "~")).firstMatch
        guard tapIfExists(picker) else {
            XCTFail("여행 선택 버튼을 찾지 못했습니다. 화면 구조가 바뀌었는지 확인해 주세요.")
            return
        }
        capture("05-여행선택시트-처음")

        // 끌어올린 자리. 여기서 나머지 여행이 드러나야 한다.
        raiseSheet()
        capture("06-여행선택시트-올림")

        // 오른쪽 위 달력. 해가 여럿일 때 한 해만 보는 길이다.
        if tapIfExists(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "연도 고르기")).firstMatch) {
            capture("07-여행선택시트-연도메뉴")
            // 메뉴를 눌러 두면 다음 캡처를 덮으므로 물러난다.
            app.tap()
            settle()
        }

        tapIfExists(app.buttons["닫기"])
    }

    /// 영수증 탭에는 '전체 여행' 칸이 하나 더 붙는다.
    func test_06_영수증의_여행_선택을_캡처한다() throws {
        tapTab("영수증")

        let picker = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "~", "전체 여행")).firstMatch
        guard tapIfExists(picker) else {
            XCTFail("영수증의 여행 선택 버튼을 찾지 못했습니다.")
            return
        }
        raiseSheet()
        capture("08-영수증-여행선택")

        tapIfExists(app.buttons["닫기"])
    }

    /// 기록 탭도 같은 시트를 쓴다. 세 탭이 정말 한 벌인지 눈으로 견준다.
    func test_07_기록의_여행_선택을_캡처한다() throws {
        tapTab("기록")

        guard tapIfExists(app.buttons["record.travelChoice"]) else {
            XCTFail("기록 탭의 여행 선택 버튼을 찾지 못했습니다.")
            return
        }
        capture("09-기록-여행선택-처음")

        raiseSheet()
        capture("10-기록-여행선택-올림")

        tapIfExists(app.buttons["닫기"])
    }

    /// 시트를 맨 위까지 끌어올린다. 낮은 자리에서는 한 줄밖에 보이지 않는다.
    private func raiseSheet() {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.66))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
        from.press(forDuration: 0.05, thenDragTo: to)
        settle()
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
        //
        // 화면 전체를 쓸어 올리면 지도가 손가락을 먼저 받아 지도만 움직이고
        // 화면은 그대로 있는다. 지도는 조작할 수 있는 것이라 그게 맞는 동작이다.
        // 지도를 피해 아래쪽에서 끌어올린다.
        // 지도 위쪽(예산 줄 언저리)에서 끌어올린다.
        //
        // 지도가 화면 중간을 넓게 차지해 그 위에서 쓸면 지도만 움직인다.
        // 지도 아래는 떠 있는 탭바가 덮고 있어 잡을 자리가 거의 없다.
        // 화면을 내리려면 지도를 피해 위쪽에서 끄는 수밖에 없다.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04))
        start.press(forDuration: 0.05, thenDragTo: end)
        settle()
        capture("07-여행상세-아래")

        // 맨 아래의 인원별 정산까지 내려가 한 장 남긴다.
        start.press(forDuration: 0.05, thenDragTo: end)
        start.press(forDuration: 0.05, thenDragTo: end)
        settle()
        capture("10-인원별정산")

        // 지출 한 줄을 누르면 그 지출의 상세로 간다.
        // 번호를 누르면 지도가 움직이고, 본문을 누르면 여기로 온다.
        let firstExpense = app.buttons["travelDetail.expenseRow"].firstMatch
        if tapIfExists(firstExpense) {
            settle()
            capture("09-지출상세")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            settle()
        } else {
            XCTFail("지출 줄을 찾지 못했습니다.")
        }

        // 우상단 연필 → 여행 편집
        let edit = app.buttons["travelDetail.edit"].firstMatch
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
