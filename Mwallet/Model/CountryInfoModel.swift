//
//  CountryInfoModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/02.
//

import Foundation
import OSLog

// 표는 한 번 읽고 바뀌지 않는다. 불변이라 어느 스레드에서 읽어도 안전하다.
// (예전에는 lazy var 라 첫 접근이 겹치면 두 번 파싱될 수 있었다)
final class CountryInfoModel: Sendable {

    static let shared = CountryInfoModel()

    let countryResult: [Int: CountryInfo]

    private init() {
        countryResult = Self.load()
    }

    // 국가 목록을 못 읽어도 앱은 떠야 한다. 예전에는 여기서 fatalError 를 냈는데,
    // 번들 리소스가 손상된 것뿐인데 앱 전체가 죽었다. 지금은 '알 수 없음' 한 건만
    // 남긴 최소 사전으로 되돌아가고, 화면은 기본 국기·기본 이미지로 그려진다.
    private static func load() -> [Int: CountryInfo] {
        guard let csvURL = Bundle.main.url(forResource: "CountryList", withExtension: "csv") else {
            Logger.resources.error("CountryList.csv 를 번들에서 찾지 못했습니다")
            return fallback
        }
        do {
            let parsed = try makeDictionary(from: csvURL)
            return parsed.isEmpty ? fallback : parsed
        } catch {
            Logger.resources.error("CountryList.csv 파싱 실패: \(error.localizedDescription, privacy: .public)")
            return fallback
        }
    }

    // countryResult[-1] 은 여러 화면이 '알 수 없음' 표시에 쓰므로 항상 존재해야 한다.
    private static let fallback: [Int: CountryInfo] = [
        -1: CountryInfo(englishNm: "Unknown",
                        koreanNm: "알 수 없음",
                        locationNm: "-",
                        flagString: "DefaultFlag",
                        defaultImageString: "DefaultImage",
                        relatedCurrencyArray: [ExpenseCode.baseCurrency],
                        blurImageString: "BlurredDefaultImage")
    ]

    // MARK: 인덱스(국가순서)와 CountryInfo 구조체를 딕셔너리 형태로 만들기
    static func makeDictionary(from csvURL: URL) throws -> [Int: CountryInfo] {
        let csvData = try CSVParser.rows(contentsOf: csvURL)
        var countryInfoDict: [Int: CountryInfo] = [:]

        // 8번째 열(블러 이미지)까지 읽으므로 그만큼 있는 행만 받는다.
        // 예전 조건은 `>= 7` 인데 columns[7] 을 읽어 열이 7개인 행에서 범위를 벗어났다.
        for columns in csvData where columns.count >= 8 {
            // 헤더 줄("", "영어 국가명", ...)은 인덱스가 숫자가 아니라 여기서 걸러진다.
            // 예전에는 `Int(columns[0]) ?? 0` 이라 헤더가 대한민국(0) 자리를 덮어썼다.
            guard let index = Int(columns[0].trimmingCharacters(in: .whitespaces)) else { continue }

            let relatedCurrencyString = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)

            // "[HKD,USD]" 처럼 대괄호로 감싼 목록이다. 필드 안에 쉼표가 있어
            // CSV 에서는 따옴표로 감싸 두었고, 파서가 한 필드로 넘겨준다.
            let relatedCurrencyArray = relatedCurrencyString
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            countryInfoDict[index] = CountryInfo(
                englishNm: columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                koreanNm: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                locationNm: columns[3].trimmingCharacters(in: .whitespacesAndNewlines),
                flagString: columns[4].trimmingCharacters(in: .whitespacesAndNewlines),
                defaultImageString: columns[5].trimmingCharacters(in: .whitespacesAndNewlines),
                relatedCurrencyArray: relatedCurrencyArray,
                blurImageString: columns[7].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return countryInfoDict
    }
}
