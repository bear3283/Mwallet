//
//  SentenceRules.swift
//  Mwallet
//
//  말한 문장을 갈라 읽을 때 언어마다 다른 두 가지.
//
//    1. 결제 방식을 뭐라고 말하는가   카드 · card · Karte · カード · 刷卡
//    2. 수를 어떻게 끊어 적는가        1,500.50  대  1.500,50
//
//  1은 낱말이라 표로 적을 수밖에 없다. 2는 iOS 가 이미 알고 있어 물어본다.
//
//  ── 2가 왜 중요한가 ────────────────────────────────────────────────
//
//  독일어·스페인어·이탈리아어·포르투갈어·프랑스어는 쉼표가 소수점이고
//  마침표가 자릿점이다. 한국어·영어와 정반대다. 예전 코드는 쉼표를 무조건
//  걷어냈는데, 그러면 이렇게 된다.
//
//      "15,50 Euro"   쉼표를 지움  →  1550    실제의 백 배
//      "1.500 Euro"   점을 소수점으로  →  1.5   실제의 천분의 일
//
//  금액이 백 배로 적히는 가계부는 없느니만 못하다. 그래서 문장을 뜯기
//  전에 자릿점을 걷어내고 소수점을 '.' 하나로 맞춰 둔다.
//

import Foundation

enum SentenceRules {

    // MARK: - 결제 방식

    /// 낱말 하나가 결제 방식인지. 아니면 nil.
    ///
    /// 기기 언어의 표를 먼저 보고, 없으면 영어를 본다 — 영어 낱말은 어느
    /// 나라에서나 섞여 나온다. 반대로 모든 언어의 표를 한꺼번에 보지는
    /// 않는다. 독일어에서 현금인 'bar' 는 스페인어에서 술집이라, 스페인어
    /// 기기의 "bar 15 euros" 가 현금 결제로 읽혀 버린다.
    static func paymentMethod(for word: String, language: String = current) -> PaymentMethod? {
        let key = normalizingWord(word)
        guard !key.isEmpty else { return nil }

        if let table = tables[language] ?? tables[base(of: language)] {
            if table.card.contains(key) { return .card }
            if table.cash.contains(key) { return .cash }
        }
        if english.card.contains(key) { return .card }
        if english.cash.contains(key) { return .cash }
        return nil
    }

    /// '카드 결제' 처럼 결제 방식 뒤에 따라붙는 낱말인지.
    ///
    /// 이 낱말은 그것만으로는 뜻이 없어 떼어 내고 앞 낱말을 다시 본다.
    static func isPaymentWord(_ word: String, language: String = current) -> Bool {
        let key = normalizingWord(word)
        guard !key.isEmpty else { return false }
        let table = tables[language] ?? tables[base(of: language)]
        return table?.payment.contains(key) == true || english.payment.contains(key)
    }

    // MARK: - 수의 자릿점과 소수점

    /// 자릿점을 걷어내고 소수점을 '.' 로 맞춘다.
    ///
    /// 어느 쪽이 자릿점이고 어느 쪽이 소수점인지는 iOS 에 묻는다. 나라마다
    /// 다르고 시간이 지나면 바뀌기도 해서, 코드에 적어 두면 그 자리에서 굳는다.
    ///
    /// 자릿점으로는 로케일이 답한 것에 더해 띄어쓰기 계열도 함께 걷는다 —
    /// 프랑스어는 좁은 붙임 공백(U+202F)으로 끊고, 받아쓰기가 보통 공백을
    /// 내놓기도 한다. 낱말을 가르는 보통 공백은 이미 앞에서 나뉘어 여기까지
    /// 오지 않는다.
    static func normalizingSeparators(_ token: String, locale: Locale = .current) -> String {
        let decimal = locale.decimalSeparator ?? "."
        var grouping: Set<Character> = ["\u{00A0}", "\u{202F}", "\u{2009}", "'"]
        if let separator = locale.groupingSeparator, let character = separator.first {
            grouping.insert(character)
        }
        // 소수점이 자릿점 목록에 들어가면 소수부가 통째로 사라진다.
        if let character = decimal.first { grouping.remove(character) }

        var out = ""
        out.reserveCapacity(token.count)
        for character in token {
            if grouping.contains(character) { continue }
            if String(character) == decimal { out.append("."); continue }
            out.append(character)
        }
        return out
    }

    // MARK: - 표

    private struct Words {
        let card: Set<String>
        let cash: Set<String>
        /// 결제 방식 뒤에 붙는 낱말('결제', 'payment').
        let payment: Set<String>
    }

    private static let english = Words(
        card: ["card", "credit", "creditcard", "debit", "debitcard", "visa"],
        cash: ["cash"],
        payment: ["payment", "paid", "pay"]
    )

    private static let tables: [String: Words] = [
        "ko": Words(card: ["카드", "카드로", "카드결제", "신용카드"],
                    cash: ["현금", "현금으로", "현금결제"],
                    payment: ["결제", "지불"]),
        "en": english,
        "ja": Words(card: ["カード", "クレジット", "クレジットカード", "カードで"],
                    cash: ["現金", "キャッシュ", "現金で"],
                    payment: ["払い", "支払い", "支払", "決済"]),
        "zh-Hans": Words(card: ["刷卡", "信用卡", "卡", "银行卡"],
                         cash: ["现金", "付现"],
                         payment: ["支付", "付款"]),
        "zh-Hant": Words(card: ["刷卡", "信用卡", "卡", "銀行卡"],
                         cash: ["現金", "付現"],
                         payment: ["支付", "付款"]),
        "de": Words(card: ["karte", "kreditkarte", "kartenzahlung", "ec-karte", "ec"],
                    cash: ["bar", "bargeld"],
                    payment: ["bezahlt", "zahlung", "gezahlt"]),
        "fr": Words(card: ["carte", "cb", "carte bancaire"],
                    cash: ["espèces", "especes", "liquide"],
                    payment: ["paiement", "payé", "paye"]),
        "it": Words(card: ["carta", "bancomat", "carta di credito"],
                    cash: ["contanti", "contante"],
                    payment: ["pagamento", "pagato"]),
        "es": Words(card: ["tarjeta"],
                    cash: ["efectivo", "metálico", "metalico"],
                    payment: ["pago", "pagado", "pagué", "pague"]),
        "pt": Words(card: ["cartão", "cartao"],
                    cash: ["dinheiro", "espécie", "especie"],
                    payment: ["pagamento", "pago", "paguei"])
    ]

    // MARK: - 어느 언어를 갈라 읽을 수 있는가

    /// 이 로케일의 문장을 갈라 읽을 규칙이 있는지.
    ///
    /// 화면과 SpeechLocale 이 이것을 보고 말하기를 열지 말지 정한다. 규칙이
    /// 없는 언어로 받아쓰기만 하면 글자는 뜨는데 금액도 결제 방식도 비어,
    /// 되는 척만 하다 만다.
    static func canParse(_ locale: Locale = .current) -> Bool {
        let key = languageKey(for: locale)
        return tables[key] != nil || tables[base(of: key)] != nil
    }

    /// 표를 찾을 열쇠. 중국어만 간체·번체를 갈라 본다 — 낱말이 다르다.
    static func languageKey(for locale: Locale = .current) -> String {
        let language = locale.language
        guard let code = language.languageCode?.identifier else { return "ko" }
        if code == "zh" {
            // 문자 표기가 안 적힌 기기도 있다. 지역으로 되짚는다.
            if let script = language.script?.identifier { return "zh-\(script)" }
            let region = locale.region?.identifier
            return ["TW", "HK", "MO"].contains(region ?? "") ? "zh-Hant" : "zh-Hans"
        }
        return code
    }

    // MARK: - 다듬기

    private static var current: String { languageKey() }

    /// 'zh-Hans' 는 그대로, 'es-MX' 는 'es' 로. 한자는 간체·번체가 갈려 남긴다.
    private static func base(of language: String) -> String {
        language.hasPrefix("zh") ? language : String(language.prefix(2))
    }

    /// 견줄 수 있게 다듬는다 — 대소문자를 맞추고 문장부호를 뗀다.
    ///
    /// 받아쓰기는 문장 끝에 마침표를 붙이곤 한다. "…card." 가 카드로 읽히지
    /// 않으면 사용자는 왜 안 되는지 알 길이 없다.
    private static func normalizingWord(_ word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
    }
}
