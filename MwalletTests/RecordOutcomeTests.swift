//
//  RecordOutcomeTests.swift
//  MwalletTests
//
//  손을 뗀 뒤 무엇을 할지 — 이 앱의 핵심 동작이 갈리는 자리.
//
//  이 판단은 여태 RecordView 의 제스처 콜백 안에 있었다. 화면 안에 있으면
//  실기기 마이크 없이는 한 줄도 확인할 수 없었고, 그래서 아무 시험도 없었다.
//  떼어 낸 지금은 값 셋만 넣으면 답이 정해지므로 여기서 지킨다.
//
//  마이크가 있어야 확인할 수 있는 것은 따로 남는다 — 신호(isFinal)가 실제로
//  오는지, 시간 제한이 도는지. 그것은 기기에서 눌러 봐야 한다.
//

import XCTest
@testable import Mwallet

final class RecordOutcomeTests: XCTestCase {

    private let unknown = ParsedVoiceSentence.unknownAmount

    // MARK: - 너무 짧게 누른 경우

    // 단추를 스치듯 누른 것이다. 말할 틈이 없었으므로 들은 것도 없다고 본다.
    func test_짧게_누르면_들은_것이_있어도_짧음으로_본다() {
        let outcome = RecordOutcome.decide(pressedSeconds: 0.3,
                                           info: "점심", payAmount: 15_000)
        XCTAssertEqual(outcome, .tooShort,
                       "스치듯 누른 것은 말한 것으로 치지 않는다")
    }

    func test_기준_바로_아래는_짧음이다() {
        let outcome = RecordOutcome.decide(pressedSeconds: RecordOutcome.minimumPressSeconds - 0.01,
                                           info: "점심", payAmount: 15_000)
        XCTAssertEqual(outcome, .tooShort)
    }

    func test_기준을_채우면_짧음이_아니다() {
        let outcome = RecordOutcome.decide(pressedSeconds: RecordOutcome.minimumPressSeconds,
                                           info: "점심", payAmount: 15_000)
        XCTAssertEqual(outcome, .proceed)
    }

    // MARK: - 듣기는 했는데 얻은 것이 없는 경우

    func test_내역도_금액도_없으면_못_알아들은_것이다() {
        let outcome = RecordOutcome.decide(pressedSeconds: 3, info: nil, payAmount: unknown)
        XCTAssertEqual(outcome, .nothingHeard)
    }

    // MARK: - 반쪽이라도 얻은 경우

    // 애써 말한 것을 '반쪽' 이라는 이유로 버리지 않는다. 나머지는 직접 기록
    // 화면에서 채우면 된다.
    func test_내역만_얻어도_넘긴다() {
        let outcome = RecordOutcome.decide(pressedSeconds: 3, info: "점심", payAmount: unknown)
        XCTAssertEqual(outcome, .proceed)
    }

    func test_금액만_얻어도_넘긴다() {
        let outcome = RecordOutcome.decide(pressedSeconds: 3, info: nil, payAmount: 15_000)
        XCTAssertEqual(outcome, .proceed)
    }

    // 0원은 '말하지 않음' 과 다르다. 0원짜리를 적는 일이 실제로 있다(무료 시식).
    func test_영원도_말한_것으로_친다() {
        let outcome = RecordOutcome.decide(pressedSeconds: 3, info: nil, payAmount: 0)
        XCTAssertEqual(outcome, .proceed,
                       "0원은 unknownAmount(-1)와 다르다")
    }

    // MARK: - 기준값

    // 이 값이 흔들리면 '눌렀는데 아무 일도 없다' 와 '스쳤는데 화면이 뜬다'
    // 사이에서 느낌이 바뀐다. 바꾼다면 뜻을 알고 바꾸라는 표시다.
    func test_짧음의_기준은_1_5초다() {
        XCTAssertEqual(RecordOutcome.minimumPressSeconds, 1.5)
    }
}
