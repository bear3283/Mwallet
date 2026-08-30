//
//  CurrencyInfo.swift
//  Mwallet
//
//  Created by 김태현 on 11/6/23.
//

import Foundation

struct CurrencyInfo {
    let isoCodeNm: String
    let koreanNm: String
    let symbol: String
}

// MARK: - 화면에 적을 이름

extension CurrencyInfo {

    /// 기기 언어로 된 통화 이름.
    ///
    /// 나라 이름과 같은 이유로 iOS 에 묻는다 — ISO 코드만 있으면 어느 언어로든
    /// 답해 준다. csv 의 한국어 이름은 코드를 못 알아볼 때만 쓴다.
    var displayName: String {
        Locale.current.localizedString(forCurrencyCode: isoCodeNm)
            ?? (CountryInfo.prefersKorean ? koreanNm : isoCodeNm)
    }

    /// 이름과 기호를 한 줄로. 고른 통화를 적는 자리에 쓴다.
    var displayLabel: String {
        symbol.isEmpty || symbol == "-" ? displayName : "\(displayName) \(symbol)"
    }
}
