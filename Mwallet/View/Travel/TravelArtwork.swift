//
//  TravelArtwork.swift
//  Mwallet
//
//  여행 카드에 무엇을 그릴지 고른다 — 사진 한 장과 국기 몇 개.
//
//  이 규칙은 기록 탭의 선택 모달 안에 박혀 있었다. 예결산·영수증도 같은
//  카드를 쓰게 되면서 꺼냈다. 화면이 아니라 값이라 눈으로 보지 않고도
//  확인할 수 있다.
//
//  국기는 '어디를 다녀온 여행인가' 를 이름보다 빨리 알려 준다. 지출이 적힌
//  나라를 최근에 쓴 것부터 모으되 넉이면 그친다. 그보다 많이 겹쳐 놓으면
//  서로 가려서 어느 나라인지 알아볼 수 없다.
//

import Foundation

struct TravelArtwork: Equatable {

    /// 겹쳐 놓을 국기 이미지 이름. 최근에 쓴 나라가 앞이다.
    let flagNames: [String]
    /// 대표 사진이 없을 때 깔 나라별 기본 사진.
    let placeholderName: String

    static let fallbackFlag = "DefaultFlag"
    static let fallbackPlaceholder = "DefaultImage"

    /// 한 카드에 겹쳐 놓을 국기의 수.
    static let flagLimit = 4
}

enum TravelArtworkBuilder {

    static func artwork(for travel: Travel) -> TravelArtwork {
        artwork(countries: countries(in: travel))
    }

    /// 나라 번호에서 그림 이름으로. 나라 표를 타지 않고 확인하려고 갈라 둔다.
    static func artwork(countries: [Int]) -> TravelArtwork {
        let table = CountryInfoModel.shared.countryResult
        return TravelArtwork(
            flagNames: countries.map { table[$0]?.flagString ?? TravelArtwork.fallbackFlag },
            placeholderName: countries.first.flatMap { table[$0]?.defaultImageString }
                ?? TravelArtwork.fallbackPlaceholder)
    }

    /// 지출이 적힌 나라를, 최근에 쓴 것부터 겹치지 않게.
    ///
    /// 날짜가 없는 지출은 맨 뒤로 보낸다. 예전에는 날짜가 하나라도 없으면
    /// 두 지출의 차례를 '앞이 먼저' 로 답했는데, 그러면 비교가 서로 어긋나
    /// 나라 차례가 뒤죽박죽이 됐다.
    static func countries(in travel: Travel, limit: Int = TravelArtwork.flagLimit) -> [Int] {
        let expenses = ((travel.expenseArray?.allObjects as? [Expense]) ?? [])
            .sorted { ($0.payDate ?? .distantPast) > ($1.payDate ?? .distantPast) }

        var found: [Int] = []
        for expense in expenses {
            let country = Int(expense.country)
            guard !found.contains(country) else { continue }
            found.append(country)
            if found.count >= limit { break }
        }
        return found
    }
}
