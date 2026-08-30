//
//  SentenceRulesTests.swift
//  MwalletTests
//
//  언어마다 다른 두 가지 — 결제 방식 낱말과 수의 자릿점.
//
//  자릿점 쪽이 더 무섭다. 낱말을 못 알아들으면 결제 방식이 '미분류' 로
//  남을 뿐이지만, 자릿점을 잘못 읽으면 금액이 백 배로 적힌다. 그 잘못은
//  화면에서 알아채기 어렵고 정산까지 그대로 흘러간다.
//

import XCTest
@testable import Mwallet

final class SentenceRulesTests: XCTestCase {

    // MARK: - 자릿점과 소수점

    // 한국어·영어는 쉼표가 자릿점이고 마침표가 소수점이다.
    func test_한국어는_쉼표를_자릿점으로_읽는다() {
        let korean = Locale(identifier: "ko_KR")
        XCTAssertEqual(SentenceRules.normalizingSeparators("90,000", locale: korean), "90000")
        XCTAssertEqual(SentenceRules.normalizingSeparators("12.5", locale: korean), "12.5")
    }

    // 독일어는 정반대다. 예전 코드는 쉼표를 무조건 걷어내서
    // "15,50" 을 1550 으로 읽었다 — 백 배다.
    func test_독일어는_쉼표를_소수점으로_읽는다() {
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(SentenceRules.normalizingSeparators("15,50", locale: german), "15.50",
                       "쉼표는 독일어에서 소수점이다")
        XCTAssertEqual(SentenceRules.normalizingSeparators("1.500", locale: german), "1500",
                       "마침표는 독일어에서 자릿점이다")
    }

    func test_스페인어와_이탈리아어도_같은_방식이다() {
        for identifier in ["es_ES", "it_IT", "pt_BR"] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(SentenceRules.normalizingSeparators("15,50", locale: locale), "15.50",
                           "\(identifier) 의 소수점")
            XCTAssertEqual(SentenceRules.normalizingSeparators("1.500", locale: locale), "1500",
                           "\(identifier) 의 자릿점")
        }
    }

    // 프랑스어는 좁은 붙임 공백으로 끊는다. 보통 공백이 아니라 낱말이
    // 갈리지 않고 한 덩어리로 여기까지 온다.
    func test_프랑스어의_붙임공백을_걷어낸다() {
        let french = Locale(identifier: "fr_FR")
        XCTAssertEqual(SentenceRules.normalizingSeparators("1\u{202F}500", locale: french), "1500")
        XCTAssertEqual(SentenceRules.normalizingSeparators("1\u{00A0}500", locale: french), "1500")
        XCTAssertEqual(SentenceRules.normalizingSeparators("15,50", locale: french), "15.50")
    }

    // 소수점이 자릿점 목록에도 들어가면 소수부가 통째로 사라진다.
    func test_소수점은_자릿점으로_걷히지_않는다() {
        for identifier in ["ko_KR", "en_US", "de_DE", "fr_FR", "ja_JP"] {
            let locale = Locale(identifier: identifier)
            let read = SentenceRules.normalizingSeparators("7,5", locale: locale)
            XCTAssertTrue(read == "75" || read == "7.5",
                          "\(identifier) 에서 '7,5' 가 \(read) 가 됐다 — 자리가 사라졌다")
        }
    }

    // MARK: - 결제 방식

    func test_기기_언어의_낱말을_알아듣는다() {
        let cases: [(String, String, PaymentMethod)] = [
            ("ko", "카드", .card), ("ko", "현금", .cash),
            ("en", "card", .card), ("en", "cash", .cash),
            ("ja", "カード", .card), ("ja", "現金", .cash),
            ("zh-Hans", "刷卡", .card), ("zh-Hans", "现金", .cash),
            ("zh-Hant", "刷卡", .card), ("zh-Hant", "現金", .cash),
            ("de", "Karte", .card), ("de", "bar", .cash),
            ("fr", "carte", .card), ("fr", "espèces", .cash),
            ("it", "carta", .card), ("it", "contanti", .cash),
            ("es", "tarjeta", .card), ("es", "efectivo", .cash),
            ("pt", "cartão", .card), ("pt", "dinheiro", .cash)
        ]
        for (language, word, expected) in cases {
            XCTAssertEqual(SentenceRules.paymentMethod(for: word, language: language), expected,
                           "\(language) 의 '\(word)'")
        }
    }

    // 받아쓰기는 문장 끝에 마침표를 붙이곤 한다. 그것 때문에 못 알아들으면
    // 사용자는 왜 안 되는지 알 길이 없다.
    func test_대소문자와_문장부호에_걸리지_않는다() {
        XCTAssertEqual(SentenceRules.paymentMethod(for: "Card.", language: "en"), .card)
        XCTAssertEqual(SentenceRules.paymentMethod(for: "KARTE", language: "de"), .card)
        XCTAssertEqual(SentenceRules.paymentMethod(for: "Efectivo,", language: "es"), .cash)
    }

    // 영어 낱말은 어느 나라에서나 섞여 나온다.
    func test_영어_낱말은_어느_언어에서나_통한다() {
        XCTAssertEqual(SentenceRules.paymentMethod(for: "card", language: "de"), .card)
        XCTAssertEqual(SentenceRules.paymentMethod(for: "cash", language: "ja"), .cash)
    }

    // 독일어에서 현금인 'bar' 는 스페인어에서 술집이다. 모든 언어의 표를
    // 한꺼번에 보면 "bar 15 euros" 가 현금 결제로 읽혀 버린다.
    func test_다른_언어의_낱말까지_끌어오지_않는다() {
        XCTAssertNil(SentenceRules.paymentMethod(for: "bar", language: "es"),
                     "스페인어의 'bar' 는 술집이지 현금이 아니다")
        XCTAssertEqual(SentenceRules.paymentMethod(for: "bar", language: "de"), .cash)
    }

    // MARK: - 어느 언어를 갈라 읽을 수 있는가

    func test_스토어에_올린_열한_언어를_모두_갈라_읽는다() {
        let store = ["ko_KR", "en_US", "ja_JP", "zh_Hans_CN", "zh_Hant_TW",
                     "de_DE", "fr_FR", "it_IT", "es_ES", "es_MX", "pt_BR"]
        for identifier in store {
            XCTAssertTrue(SentenceRules.canParse(Locale(identifier: identifier)),
                          "\(identifier) 의 규칙이 없다 — 스토어에는 이 언어로 말하기를 적어 두었다")
        }
    }

    func test_규칙이_없는_언어는_없다고_답한다() {
        XCTAssertFalse(SentenceRules.canParse(Locale(identifier: "sv_SE")))
        XCTAssertFalse(SentenceRules.canParse(Locale(identifier: "th_TH")))
    }

    func test_중국어는_간체와_번체를_갈라_본다() {
        XCTAssertEqual(SentenceRules.languageKey(for: Locale(identifier: "zh_Hans_CN")), "zh-Hans")
        XCTAssertEqual(SentenceRules.languageKey(for: Locale(identifier: "zh_Hant_TW")), "zh-Hant")
        // 문자 표기가 없으면 지역으로 되짚는다.
        XCTAssertEqual(SentenceRules.languageKey(for: Locale(identifier: "zh_TW")), "zh-Hant")
    }

    // es-MX 는 표를 따로 두지 않고 es 를 물려받는다.
    func test_지역만_다른_언어는_같은_표를_쓴다() {
        XCTAssertEqual(SentenceRules.paymentMethod(for: "tarjeta", language: "es-MX"), .card)
        XCTAssertEqual(SentenceRules.paymentMethod(for: "cartão", language: "pt-BR"), .card)
    }
}
