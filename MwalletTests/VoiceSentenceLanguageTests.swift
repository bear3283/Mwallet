//
//  VoiceSentenceLanguageTests.swift
//  MwalletTests
//
//  스토어에 열한 언어로 "버튼을 누른 채 한 문장 말하세요" 라고 적어 두었다.
//  그 약속이 언어마다 실제로 지켜지는지 문장 하나씩으로 확인한다.
//
//  화면의 예시 말풍선에 적히는 문장을 그대로 쓴다 — 앱이 가르쳐 준 대로
//  말했을 때 되지 않으면, 그 언어에서는 이 기능이 없는 것과 같다.
//

import XCTest
@testable import Mwallet

final class VoiceSentenceLanguageTests: XCTestCase {

    private func parse(_ sentence: String, _ identifier: String) -> ParsedVoiceSentence {
        VoiceSentenceParser.parse(sentence, locale: Locale(identifier: identifier))
    }

    // 화면이 가르쳐 주는 예시 문장. Localizable.xcstrings 의 '점심 15000원 카드'.
    func test_예시_문장이_열한_언어에서_모두_읽힌다() {
        let cases: [(locale: String, sentence: String, info: String, amount: Double)] = [
            ("ko_KR", "점심 15000원 카드", "점심", 15000),
            ("en_US", "lunch 15 dollars card", "lunch", 15),
            ("ja_JP", "ランチ 1500円 カード", "ランチ", 1500),
            ("zh_Hans_CN", "午餐 100 元 刷卡", "午餐", 100),
            ("zh_Hant_TW", "午餐 150 元 刷卡", "午餐", 150),
            ("de_DE", "Mittagessen 15 Euro Karte", "Mittagessen", 15),
            ("fr_FR", "déjeuner 15 euros carte", "déjeuner", 15),
            ("it_IT", "pranzo 15 euro carta", "pranzo", 15),
            ("es_ES", "comida 15 euros tarjeta", "comida", 15),
            ("es_MX", "comida 200 pesos tarjeta", "comida", 200),
            ("pt_BR", "almoço 30 reais cartão", "almoço", 30)
        ]

        for expected in cases {
            let read = parse(expected.sentence, expected.locale)
            XCTAssertEqual(read.amount, expected.amount, accuracy: 0.001,
                           "\(expected.locale): 「\(expected.sentence)」의 금액")
            XCTAssertEqual(read.info, expected.info,
                           "\(expected.locale): 「\(expected.sentence)」의 내역")
            XCTAssertEqual(read.paymentMethod, .card,
                           "\(expected.locale): 「\(expected.sentence)」의 결제 방식")
        }
    }

    // 여기가 가장 조용히 틀리던 자리다. 예전에는 쉼표를 무조건 걷어내서
    // 독일어 "15,50" 이 1550 으로 적혔다 — 백 배다.
    func test_쉼표를_소수점으로_쓰는_언어의_금액() {
        XCTAssertEqual(parse("Mittagessen 15,50 Euro Karte", "de_DE").amount, 15.5, accuracy: 0.001)
        XCTAssertEqual(parse("pranzo 15,50 euro carta", "it_IT").amount, 15.5, accuracy: 0.001)
        XCTAssertEqual(parse("almoço 30,50 reais cartão", "pt_BR").amount, 30.5, accuracy: 0.001)
    }

    // 반대로 마침표는 그 언어들에서 자릿점이다. "1.500" 은 천오백이지 1.5 가 아니다.
    func test_마침표를_자릿점으로_쓰는_언어의_금액() {
        XCTAssertEqual(parse("Mittagessen 1.500 Euro Karte", "de_DE").amount, 1500, accuracy: 0.001)
        XCTAssertEqual(parse("comida 1.500 pesos tarjeta", "es_ES").amount, 1500, accuracy: 0.001)
    }

    // 한국어·영어는 정반대이고, 예전과 똑같이 읽혀야 한다.
    func test_한국어와_영어는_예전_그대로다() {
        XCTAssertEqual(parse("점심 90,000원 카드", "ko_KR").amount, 90000, accuracy: 0.001)
        XCTAssertEqual(parse("lunch 12.5 dollars cash", "en_US").amount, 12.5, accuracy: 0.001)
        XCTAssertEqual(parse("점심 12.5원 현금", "ko_KR").amount, 12.5, accuracy: 0.001)
    }

    // 한국어 수사는 한국어에서만 읽는다. 다른 언어는 받아쓰기가 숫자를 내놓는다.
    func test_한국어_수사는_그대로_읽힌다() {
        XCTAssertEqual(parse("점심 삼만 오천원 카드", "ko_KR").amount, 35000, accuracy: 0.001)
        XCTAssertEqual(parse("커피 사천오백원 현금", "ko_KR").amount, 4500, accuracy: 0.001)
    }

    // 결제 방식만 말하지 않아도 나머지는 읽혀야 한다 — 되는 만큼은 받아 준다.
    func test_결제_방식을_말하지_않아도_읽는다() {
        let read = parse("Mittagessen 15 Euro", "de_DE")
        XCTAssertEqual(read.amount, 15, accuracy: 0.001)
        XCTAssertEqual(read.info, "Mittagessen")
        XCTAssertEqual(read.paymentMethod, .unknown)
    }

    // 금액을 말하지 않으면 '말하지 않음' 으로 남는다. 0원과 다르다.
    func test_금액을_말하지_않으면_비워_둔다() {
        let read = parse("lunch card", "en_US")
        XCTAssertEqual(read.amount, ParsedVoiceSentence.unknownAmount)
        XCTAssertEqual(read.info, "lunch")
        XCTAssertEqual(read.paymentMethod, .card)
    }

    // 현금 쪽도 언어마다 확인한다.
    func test_현금도_언어마다_읽는다() {
        let cases: [(String, String)] = [
            ("ko_KR", "점심 15000원 현금"),
            ("en_US", "lunch 15 dollars cash"),
            ("ja_JP", "ランチ 1500円 現金"),
            ("de_DE", "Mittagessen 15 Euro bar"),
            ("fr_FR", "déjeuner 15 euros espèces"),
            ("it_IT", "pranzo 15 euro contanti"),
            ("es_ES", "comida 15 euros efectivo"),
            ("pt_BR", "almoço 30 reais dinheiro"),
            ("zh_Hans_CN", "午餐 100 元 现金"),
            ("zh_Hant_TW", "午餐 150 元 現金")
        ]
        for (identifier, sentence) in cases {
            XCTAssertEqual(parse(sentence, identifier).paymentMethod, .cash,
                           "\(identifier): 「\(sentence)」")
        }
    }
}
