//
//  VoiceSentenceParsingTests.swift
//  MwalletTests
//
//  말한 문장 한 줄에서 내역·금액·결제 방식을 뽑아내는 경로.
//  이 앱의 핵심 기능인데 그동안 검증이 없었다.
//
//  divideVoiceSentence 를 직접 부른다. voiceSentence 의 didSet 도 같은 일을
//  하지만 다음 런루프로 미뤄지므로, 테스트에서는 동기적으로 호출한다.
//

import XCTest
@testable import Mwallet

@MainActor
final class VoiceSentenceParsingTests: XCTestCase {

    private var viewModel: RecordViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = RecordViewModel()
    }

    // tearDown() 은 nonisolated 오버라이드라 메인 액터 프로퍼티를 건드릴 수 없다.
    // async 형태는 클래스의 @MainActor 격리를 물려받는다.
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    private struct Parsed {
        let info: String?
        let amount: Double
        let method: PaymentMethod
    }

    private func parse(_ sentence: String) -> Parsed {
        viewModel.voiceSentence = sentence
        viewModel.divideVoiceSentence()
        return Parsed(info: viewModel.info,
                      amount: viewModel.payAmount,
                      method: viewModel.paymentMethod)
    }

    // MARK: - 기본 형태

    func test_내역과_아라비아_금액과_결제방식을_모두_뽑는다() {
        let result = parse("커피 15000원 카드")

        XCTAssertEqual(result.info, "커피")
        XCTAssertEqual(result.amount, 15_000)
        XCTAssertEqual(result.method, .card)
    }

    func test_한글_수사를_숫자로_읽는다() {
        let result = parse("커피 사천오백원 현금")

        XCTAssertEqual(result.info, "커피")
        XCTAssertEqual(result.amount, 4_500)
        XCTAssertEqual(result.method, .cash)
    }

    func test_만_단위를_만_배로_올린다() {
        // 삼만 → 3 × 10000, 오천 → 5000
        XCTAssertEqual(parse("삼만 오천원").amount, 35_000)
    }

    // '만' 앞에 수사가 없으면 1만이다. 예전에는 0원으로 잡혔다.
    func test_만_하나만_말해도_만원으로_읽는다() {
        XCTAssertEqual(parse("택시 만원").amount, 10_000)
        XCTAssertEqual(parse("만원").amount, 10_000)
    }

    func test_만_앞에_수사가_붙으면_그만큼_곱한다() {
        XCTAssertEqual(parse("숙소 이만원").amount, 20_000)
        XCTAssertEqual(parse("숙소 십만원").amount, 100_000)
        XCTAssertEqual(parse("숙소 십오만원").amount, 150_000)
    }

    func test_만_뒤에_붙는_수를_더한다() {
        XCTAssertEqual(parse("만오천원").amount, 15_000)
    }

    func test_아라비아와_한글을_섞어도_읽는다() {
        XCTAssertEqual(parse("숙소 3만원").amount, 30_000)
    }

    // MARK: - 결제 방식

    func test_결제_방식의_여러_말투를_받는다() {
        XCTAssertEqual(parse("커피 5000원 카드").method, .card)
        XCTAssertEqual(parse("커피 5000원 카드로").method, .card)
        XCTAssertEqual(parse("커피 5000원 카드결제").method, .card)
        XCTAssertEqual(parse("커피 5000원 카드 결제").method, .card)

        XCTAssertEqual(parse("커피 5000원 현금").method, .cash)
        XCTAssertEqual(parse("커피 5000원 현금으로").method, .cash)
        XCTAssertEqual(parse("커피 5000원 현금결제").method, .cash)
        XCTAssertEqual(parse("커피 5000원 현금 결제").method, .cash)
    }

    func test_결제_방식을_말하지_않으면_비워_둔다() {
        XCTAssertEqual(parse("커피 5000원").method, .unknown)
    }

    // 결제 방식만 떼어 내고 금액·내역은 그대로 남아야 한다.
    func test_결제_방식은_내역에_섞이지_않는다() {
        let result = parse("점심 식사 12000원 카드 결제")

        XCTAssertEqual(result.amount, 12_000)
        XCTAssertEqual(result.method, .card)
        XCTAssertFalse(result.info?.contains("카드") ?? false)
        XCTAssertFalse(result.info?.contains("결제") ?? false)
    }

    // MARK: - 숫자 표기

    func test_천단위_쉼표를_걷어낸다() {
        XCTAssertEqual(parse("숙소 90,000원").amount, 90_000)
    }

    func test_소수점을_읽는다() {
        XCTAssertEqual(parse("환전 12.5").amount, 12.5, accuracy: 0.001)
    }

    func test_소수점은_두_자리까지만_남긴다() {
        // 12. 다음 3456 이 와도 소수 둘째 자리에서 끊는다.
        XCTAssertEqual(parse("환전 12.3456").amount, 12.34, accuracy: 0.001)
    }

    func test_단위_글자가_붙어도_금액만_떼어_낸다() {
        XCTAssertEqual(parse("간식 3000원").amount, 3_000)
        XCTAssertEqual(parse("간식 3000").amount, 3_000)
    }

    // MARK: - 내역

    func test_금액_앞의_말은_모두_내역이_된다() {
        XCTAssertEqual(parse("팀 저녁 식사 48000원").info, "팀 저녁 식사")
    }

    func test_금액만_말하면_내역은_비어_있다() {
        let result = parse("15000원")

        XCTAssertNil(result.info)
        XCTAssertEqual(result.amount, 15_000)
    }

    // 내역은 15 자 남짓에서 끊긴다. 화면 한 줄에 들어가야 하기 때문이다.
    func test_내역이_길면_잘라_낸다() {
        let long = "아주아주아주아주아주아주아주긴상호명입니다"
        let result = parse("\(long) 5000원")

        XCTAssertNotNil(result.info)
        XCTAssertLessThan(result.info!.count, long.count, "긴 내역이 잘리지 않았습니다")
    }

    // MARK: - 빈 입력

    func test_빈_문장은_아무것도_남기지_않는다() {
        let result = parse("")

        XCTAssertNil(result.info)
        XCTAssertEqual(result.amount, -1, "금액 미확보는 -1 이어야 합계에서 빠진다")
    }

    // MARK: - '점' 의 두 얼굴
    //
    // '점' 은 소수점 표시이면서 낱말에도 흔히 쓰인다.
    // 앞 글자가 숫자일 때만 소수점으로 읽는다.

    func test_낱말_안의_점은_소수점이_아니다() {
        let result = parse("점심 먹었다")

        XCTAssertEqual(result.info, "점심 먹었다")
        XCTAssertEqual(result.amount, -1, "금액을 말하지 않았는데 0원으로 잡히면 빈 기록이 저장된다")
    }

    func test_점으로_시작하는_다른_낱말들도_지킨다() {
        XCTAssertEqual(parse("점검 비용 3000원").info, "점검 비용")
        XCTAssertEqual(parse("지점 방문").info, "지점 방문")
        XCTAssertEqual(parse("거점 이동 5000원").amount, 5_000)
    }

    func test_숫자_뒤의_점은_소수점으로_읽는다() {
        XCTAssertEqual(parse("환율 이십사점오").amount, 24.5, accuracy: 0.001)
        XCTAssertEqual(parse("환율 삼점일사").amount, 3.14, accuracy: 0.001)
    }

    func test_점심에_금액이_붙어도_정상으로_읽는다() {
        let result = parse("점심 15000원 카드")

        XCTAssertEqual(result.info, "점심")
        XCTAssertEqual(result.amount, 15_000)
        XCTAssertEqual(result.method, .card)
    }
}
