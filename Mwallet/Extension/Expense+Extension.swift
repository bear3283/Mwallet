//
//  Expense+Extension.swift
//  Mwallet
//

import Foundation

extension Expense {

    // 기록 시점에 환율을 얻지 못했음을 나타내는 값.
    // Core Data 의 exchangeRate 가 스칼라 Double 이라 nil 을 담을 수 없어 사용한다.
    // 저장되지 않은 기록의 기본값 0.0 도 같은 의미로 취급한다.
    static let unknownExchangeRate: Double = -1

    // 유효한 환율만 돌려준다. 미확보(-1)거나 기본값(0.0)이면 nil.
    // 이 프로퍼티를 거치지 않고 exchangeRate 를 직접 곱하면
    // 음수 금액이 그대로 화면과 정산 결과에 노출된다.
    var validExchangeRate: Double? {
        exchangeRate > 0 ? exchangeRate : nil
    }

    // 기록 시점 환율로 환산한 원화 금액. 금액이나 환율이 유효하지 않으면 nil.
    var payAmountInKRW: Double? {
        guard payAmount >= 0, let rate = validExchangeRate else { return nil }
        return payAmount * rate
    }
}
