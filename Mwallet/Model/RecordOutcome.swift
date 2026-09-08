//
//  RecordOutcome.swift
//  Mwallet
//
//  손을 뗀 뒤 무엇을 할지.
//
//  이 판단은 여태 RecordView 의 제스처 콜백 안에 if 세 겹으로 들어 있었다.
//  화면 안에 있으면 실기기 마이크 없이는 한 줄도 확인할 수 없는데, 정작
//  이 앱의 핵심인 '말해서 기록하기' 가 여기서 갈린다.
//
//  오디오와 아무 상관이 없는 판단이라 값 셋만 있으면 답이 정해진다.
//  떼어 내 두면 마이크 없이도 규칙을 지킬 수 있다.
//

import Foundation

enum RecordOutcome: Equatable {

    /// 너무 짧게 눌렀다. 말할 틈이 없었으므로 들은 것도 없다고 본다.
    case tooShort
    /// 듣기는 했는데 내역도 금액도 얻지 못했다.
    case nothingHeard
    /// 얻은 것이 있다. 직접 기록 화면으로 넘긴다.
    case proceed

    /// 이보다 짧게 누르면 말한 것으로 치지 않는다.
    ///
    /// 단추를 스치듯 누른 경우다. 그때도 인식을 기다리면 빈 화면이 잠깐
    /// 떴다가 사라져, 눌린 것인지 아닌지 알 수 없다.
    static let minimumPressSeconds: Double = 1.5

    /// - Parameters:
    ///   - pressedSeconds: 단추를 누르고 있던 시간.
    ///   - info: 받아 적힌 내역. 못 얻었으면 nil.
    ///   - payAmount: 받아 적힌 금액. 못 얻었으면 unknownAmount(-1).
    static func decide(pressedSeconds: Double,
                       info: String?,
                       payAmount: Double) -> RecordOutcome {
        guard pressedSeconds >= minimumPressSeconds else { return .tooShort }

        // 둘 중 하나만 얻어도 넘긴다. 나머지는 직접 기록 화면에서 채우면 된다 —
        // 애써 말한 것을 '반쪽' 이라는 이유로 버리지 않는다.
        let heardSomething = info != nil || payAmount != ParsedVoiceSentence.unknownAmount
        return heardSomething ? .proceed : .nothingHeard
    }
}
