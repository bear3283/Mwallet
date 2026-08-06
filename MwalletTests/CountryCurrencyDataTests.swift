//
//  CountryCurrencyDataTests.swift
//  MwalletTests
//
//  번들에 든 CountryList.csv · CurrencyList.csv 가 코드가 기대하는 모양으로
//  읽히는지 확인한다. 통화 인덱스는 화면·저장·환율 계산이 모두 공유하는 값이라
//  표가 밀리면 조용히 다른 통화로 기록된다.
//

import XCTest
@testable import Mwallet

final class CountryCurrencyDataTests: XCTestCase {

    // MARK: - 통화 표

    func test_통화_인덱스가_ISO_코드와_맞는다() {
        let currencies = CurrencyInfoModel.shared.currencyResult

        XCTAssertEqual(currencies[0]?.isoCodeNm, "KRW")
        XCTAssertEqual(currencies[4]?.isoCodeNm, "USD")
        XCTAssertEqual(currencies[11]?.isoCodeNm, "HKD")
        XCTAssertEqual(currencies[12]?.isoCodeNm, "MOP")
    }

    func test_코드로_통화_인덱스를_되찾을_수_있다() {
        XCTAssertEqual(ExpenseCode.currencyIndex(for: "KRW"), 0)
        XCTAssertEqual(ExpenseCode.currencyIndex(for: "USD"), 4)
        // 소문자로 들어와도 같은 값을 준다.
        XCTAssertEqual(ExpenseCode.currencyIndex(for: "usd"), 4)
    }

    func test_모르는_통화_코드는_기준_통화로_떨어진다() {
        XCTAssertEqual(ExpenseCode.currencyIndex(for: "ZZZ"),
                       ExpenseCode.currencyIndex(for: ExpenseCode.baseCurrency))
    }

    // MARK: - 국가 표

    func test_헤더_줄이_대한민국_자리를_덮지_않는다() {
        // 예전 파서는 Int(columns[0]) ?? 0 이라 인덱스가 빈 헤더 줄이 0번에 들어갔다.
        XCTAssertEqual(CountryInfoModel.shared.countryResult[0]?.englishNm, "Korea")
        XCTAssertEqual(CountryInfoModel.shared.countryResult[0]?.koreanNm, "대한민국")
    }

    func test_알_수_없는_국가_항목이_항상_있다() {
        // 화면 여러 곳이 countryResult[-1] 을 기본값으로 쓴다.
        XCTAssertEqual(CountryInfoModel.shared.countryResult[-1]?.koreanNm, "알 수 없음")
    }

    // 회귀 테스트: "[HKD,USD]" 가 쉼표에서 잘려 USD 가 사라지고
    // 블러 이미지 이름이 "USD]" 로 밀리던 버그.
    func test_통화가_둘인_국가의_통화가_모두_남는다() {
        let hongkong = CountryInfoModel.shared.countryResult[12]

        XCTAssertEqual(hongkong?.englishNm, "Hongkong")
        XCTAssertEqual(hongkong?.relatedCurrencyArray, ["HKD", "USD"])
        XCTAssertEqual(hongkong?.blurImageString, "HongkongBlurredDefaultImage")
    }

    func test_마카오도_열이_밀리지_않는다() {
        let macao = CountryInfoModel.shared.countryResult[13]

        XCTAssertEqual(macao?.relatedCurrencyArray, ["MOP", "HKD"])
        XCTAssertEqual(macao?.blurImageString, "MacaoBlurredDefaultImage")
    }

    func test_모든_국가의_주요_통화가_통화표에_존재한다() {
        let knownCodes = Set(CurrencyInfoModel.shared.currencyResult.values.map { $0.isoCodeNm })

        for (index, info) in CountryInfoModel.shared.countryResult where index >= 0 {
            for code in info.relatedCurrencyArray {
                XCTAssertTrue(knownCodes.contains(code),
                              "\(info.koreanNm)(\(index)) 의 통화 \(code) 가 CurrencyList.csv 에 없습니다")
            }
        }
    }

    func test_국가_행의_이미지_이름이_통화_코드로_오염되지_않았다() {
        // 열 밀림이 생기면 blurImageString 에 "USD]" 같은 값이 들어간다.
        for (index, info) in CountryInfoModel.shared.countryResult where index >= 0 {
            XCTAssertTrue(info.blurImageString.hasSuffix("BlurredDefaultImage"),
                          "\(info.koreanNm)(\(index)) 의 블러 이미지 이름이 이상합니다: \(info.blurImageString)")
            XCTAssertFalse(info.flagString.isEmpty)
        }
    }
}
