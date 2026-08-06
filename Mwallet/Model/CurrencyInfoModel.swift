//
//  CurrencyInfoModel.swift
//  Mwallet
//
//  Created by 김태현 on 11/6/23.
//

import Foundation
import OSLog

class CurrencyInfoModel {

    static let shared = CurrencyInfoModel()

    private init() {
    }

    // 통화 목록을 못 읽어도 앱은 떠야 한다. 원화·달러만 남은 최소 사전으로 되돌아간다.
    // 이 둘은 통화 후보를 만들 때 항상 포함되는 값이라 없으면 화폐 선택이 비어 버린다.
    lazy var currencyResult: [Int: CurrencyInfo] = {
        guard let csvURL = Bundle.main.url(forResource: "CurrencyList", withExtension: "csv") else {
            Logger.resources.error("CurrencyList.csv 를 번들에서 찾지 못했습니다")
            return Self.fallback
        }
        do {
            let parsed = try createCurrencyInfoDictionary(from: csvURL)
            return parsed.isEmpty ? Self.fallback : parsed
        } catch {
            Logger.resources.error("CurrencyList.csv 파싱 실패: \(error.localizedDescription, privacy: .public)")
            return Self.fallback
        }
    }()

    // 인덱스는 CurrencyList.csv 의 행 번호와 같아야 한다. 0 원화 · 4 달러.
    private static let fallback: [Int: CurrencyInfo] = [
        -1: CurrencyInfo(isoCodeNm: "Unknown", koreanNm: "알 수 없음", symbol: "-"),
        0: CurrencyInfo(isoCodeNm: "KRW", koreanNm: "원", symbol: "₩"),
        4: CurrencyInfo(isoCodeNm: "USD", koreanNm: "달러", symbol: "$")
    ]

    // MARK: 인덱스(화폐 순서)와 CurrencyInfo 구조체를 딕셔너리 형태로 만들기
    func createCurrencyInfoDictionary(from csvURL: URL) throws -> [Int: CurrencyInfo] {
        let csvData = try CSVParser.rows(contentsOf: csvURL)
        var currencyInfoDict: [Int: CurrencyInfo] = [:]

        for columns in csvData where columns.count >= 4 {
            // 헤더 줄은 인덱스가 숫자가 아니라 여기서 걸러진다.
            guard let index = Int(columns[0].trimmingCharacters(in: .whitespaces)) else { continue }

            currencyInfoDict[index] = CurrencyInfo(
                isoCodeNm: columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                koreanNm: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                symbol: columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return currencyInfoDict
    }
}
