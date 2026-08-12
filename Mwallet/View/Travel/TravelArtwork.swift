//
//  TravelArtwork.swift
//  Mwallet
//
//  여행 카드에 무엇을 그릴지 고른다 — 바탕 하나와 국기 몇 개.
//
//  이 규칙은 기록 탭의 선택 모달 안에 박혀 있었다. 예결산·영수증도 같은
//  카드를 쓰게 되면서 꺼냈다. 화면이 아니라 값이라 눈으로 보지 않고도
//  확인할 수 있다.
//
//  국기는 '어디를 다녀온 여행인가' 를 이름보다 빨리 알려 준다. 지출이 적힌
//  나라를 최근에 쓴 것부터 모으되 넉이면 그친다. 그보다 많이 겹쳐 놓으면
//  서로 가려서 어느 나라인지 알아볼 수 없다.
//
//  바탕은 나라를 알 때만 사진이다. 예전에는 나라를 모르면 'DefaultImage'
//  (구름 속 비행기 한 장)를 깔았는데, 세로 목록일 때는 한 번에 한둘만
//  보여서 티가 안 났다. 격자가 되면서 같은 사진이 대여섯 장 늘어서게 됐고,
//  그러면 카드가 서로 구별되지 않아 이름을 하나씩 읽어야 한다. 나라를 모르면
//  사진 대신 이름 첫 글자를 크게 적는다.
//

import Foundation

struct TravelArtwork: Equatable {

    /// 카드 바탕.
    enum Cover: Equatable {
        /// 나라를 알 때. 그 나라의 사진을 깐다.
        case photo(String)
        /// 나라를 모를 때. 이름 첫 글자를 크게 적는다.
        case monogram(String)
    }

    /// 겹쳐 놓을 국기 이미지 이름. 최근에 쓴 나라가 앞이다.
    let flagNames: [String]
    let cover: Cover

    static let fallbackFlag = "DefaultFlag"

    /// 나라 표가 '이 나라 사진은 없다' 는 뜻으로 적어 둔 이름.
    ///
    /// CountryList.csv 의 29개 나라가 이 한 장을 함께 가리킨다. 사진이 아니라
    /// 빈자리 표시라, 그대로 깔면 서로 다른 여행이 같은 카드로 보인다.
    static let noPhoto = "DefaultImage"

    /// 한 카드에 겹쳐 놓을 국기의 수.
    static let flagLimit = 4
}

enum TravelArtworkBuilder {

    static func artwork(for travel: Travel) -> TravelArtwork {
        artwork(countries: countries(in: travel), name: travel.displayName)
    }

    /// 나라 번호에서 그림 이름으로. 나라 표를 타지 않고 확인하려고 갈라 둔다.
    static func artwork(countries: [Int], name: String) -> TravelArtwork {
        let table = CountryInfoModel.shared.countryResult
        let flags = countries.map { table[$0]?.flagString ?? TravelArtwork.fallbackFlag }

        // 나라를 알아도 그 나라의 사진이 없을 수 있다. 그때도 글자로 간다.
        guard let photo = countries.first.flatMap({ table[$0]?.defaultImageString }),
              photo != TravelArtwork.noPhoto else {
            return TravelArtwork(flagNames: flags, cover: .monogram(monogram(from: name)))
        }
        return TravelArtwork(flagNames: flags, cover: .photo(photo))
    }

    /// 카드에 크게 적을 한 글자.
    ///
    /// 그냥 맨 앞 글자를 쓰면 이름이 겹치는 여행끼리 같은 글자를 받는다.
    /// '예시: 방콕' 과 '예시: 부산' 이 둘 다 '예' 가 되어, 구별하라고 넣은
    /// 글자가 도리어 다 같아진다. 사람들이 여행 이름 앞에 표를 붙이는 일이
    /// 잦아서(2026 방콕, 출장: 도쿄) 흔한 일이다.
    ///
    /// 그래서 두 가지를 건너뛴다 — 쌍점 앞의 표와, 앞머리의 숫자·기호.
    /// 숫자는 글자가 하나도 없을 때만 쓴다.
    static func monogram(from name: String) -> String {
        // '예시: 방콕 단기사역' → '방콕 단기사역'
        let body = name.split(separator: ":", omittingEmptySubsequences: false).last.map(String.init) ?? name

        if let letter = body.first(where: \.isLetter) ?? name.first(where: \.isLetter) {
            return String(letter).uppercased()
        }
        // '2026' 처럼 글자가 없는 이름.
        if let digit = name.first(where: \.isNumber) {
            return String(digit)
        }
        return "여"
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
