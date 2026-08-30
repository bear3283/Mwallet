//
//  CountryInfo.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/01.
//

import Foundation

struct CountryInfo {
    let englishNm: String
    let koreanNm: String
    let locationNm: String
    let flagString: String
    let defaultImageString: String
    let relatedCurrencyArray: [String]
    let blurImageString: String
}

// MARK: - 화면에 적을 이름

extension CountryInfo {

    /// 기기 언어로 된 나라 이름.
    ///
    /// CountryList.csv 에는 한국어 이름과 영어 이름만 있다. 열한 언어로 늘리려면
    /// 이백 몇 줄을 열 번 옮겨 적어야 하는데, 그럴 까닭이 없다 — iOS 는 모든
    /// 나라의 이름을 모든 언어로 이미 알고 있다. 영어 이름으로 나라 코드를
    /// 찾아 두고, 이름은 그때그때 물어본다.
    ///
    /// 표에 없는 이름(csv 의 오타, iOS 가 나라로 치지 않는 지역)은 못 찾는다.
    /// 그때는 csv 에 적힌 이름을 그대로 쓴다.
    var displayName: String {
        if let code = CountryInfo.regionCode(forEnglishName: englishNm),
           let localized = Locale.current.localizedString(forRegionCode: code) {
            return localized
        }
        return CountryInfo.prefersKorean ? koreanNm : englishNm
    }

    static var prefersKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    /// 영어 이름 → 나라 코드. 한 번 만들어 두고 다시 쓴다.
    ///
    /// iOS 가 아는 이름과 csv 의 이름이 늘 같지는 않다("South Korea" 대
    /// "Korea, Republic of"). 그래서 iOS 가 아는 여러 갈래 이름을 모두 열쇠로
    /// 넣어 둔다.
    private static let regionCodesByEnglishName: [String: String] = {
        let english = Locale(identifier: "en_US")
        var map: [String: String] = [:]
        for region in Locale.Region.isoRegions where region.subRegions.isEmpty {
            let code = region.identifier
            for name in [english.localizedString(forRegionCode: code)] {
                guard let name else { continue }
                map[name.lowercased(), default: code] = code
            }
        }
        return map
    }()

    static func regionCode(forEnglishName name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        if let code = regionCodesByEnglishName[key] { return code }
        // 'South Korea' 처럼 iOS 가 'Korea' 계열로 부르는 이름을 위한 두 번째 시도.
        return regionCodesByEnglishName.first { $0.key.contains(key) || key.contains($0.key) }?.value
    }
}
