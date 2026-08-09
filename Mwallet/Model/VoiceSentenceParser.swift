//
//  VoiceSentenceParser.swift
//  Mwallet
//
//  말한 문장 한 줄에서 내역·금액·결제 방식을 뽑아낸다.
//
//    "점심 식사 12000원 카드 결제"  →  점심 식사 / 12000 / 카드
//
//  사람은 늘 같은 차례로 말한다 — 무엇을, 얼마에, 어떻게. 그래서 문장을
//  뒤에서부터 읽는다. 결제 방식을 먼저 떼고, 그다음 이어지는 수를 떼고,
//  앞에 남은 말이 전부 내역이다.
//
//  화면 상태(RecordViewModel)에서 떼어 낸 순수 계산이다. 코어 데이터도
//  오디오도 건드리지 않으므로 문장만 넣어 곧바로 확인할 수 있다.
//

struct ParsedVoiceSentence: Equatable {

    /// 금액을 말하지 않았다는 표시. 0원과 달리 합계와 저장에서 빠진다.
    static let unknownAmount: Double = -1

    var info: String?
    var amount: Double
    var paymentMethod: PaymentMethod

    static let empty = ParsedVoiceSentence(info: nil,
                                           amount: unknownAmount,
                                           paymentMethod: .unknown)
}

enum VoiceSentenceParser {

    static func parse(_ sentence: String) -> ParsedVoiceSentence {
        guard !sentence.isEmpty else { return .empty }

        var splits = sentence.components(separatedBy: " ").map(removingThousandsCommas)
        let paymentMethod = takePaymentMethod(from: &splits)

        guard !splits.isEmpty else {
            return ParsedVoiceSentence(info: nil,
                                       amount: ParsedVoiceSentence.unknownAmount,
                                       paymentMethod: paymentMethod)
        }

        switch takeAmount(from: &splits) {
        case .amount(let amount):
            return ParsedVoiceSentence(info: joinedInfo(splits),
                                       amount: amount,
                                       paymentMethod: paymentMethod)
        case .noneSpokenAmount:
            return ParsedVoiceSentence(info: joinedInfo(splits),
                                       amount: ParsedVoiceSentence.unknownAmount,
                                       paymentMethod: paymentMethod)
        case .nothingLeft:
            return ParsedVoiceSentence(info: nil,
                                       amount: ParsedVoiceSentence.unknownAmount,
                                       paymentMethod: paymentMethod)
        }
    }

    // MARK: - 쉼표

    /// "90,000" 처럼 천 단위 쉼표를 붙여 말해도 수로 읽히도록 걷어낸다.
    private static func removingThousandsCommas(_ split: String) -> String {
        split.filter { $0 != "," }
    }

    // MARK: - 결제 방식

    /// 문장 끝의 결제 방식을 떼어 낸다. 뗀 만큼 splits 가 줄어든다.
    ///
    /// 받는 말투: 카드 · 카드로 · 카드결제 · 카드 결제 (현금도 같다)
    private static func takePaymentMethod(from splits: inout [String]) -> PaymentMethod {
        guard let last = splits.last else { return .unknown }

        if let method = method(for: last) {
            splits.removeLast()
            return method
        }

        // "카드 결제" 처럼 띄어 말하면 마지막 조각이 '결제' 다.
        if last == "결제", splits.count > 1, let method = method(for: splits[splits.count - 2]) {
            splits.removeLast(2)
            return method
        }

        return .unknown
    }

    private static func method(for word: String) -> PaymentMethod? {
        switch word {
        case "카드", "카드로", "카드결제": return .card
        case "현금", "현금으로", "현금결제": return .cash
        default: return nil
        }
    }

    // MARK: - 금액

    private enum AmountOutcome {
        case amount(Double)
        /// 수로 읽을 조각이 하나도 없다. 말한 것이 전부 내역이다.
        case noneSpokenAmount
        /// 떼어 낼 글자가 남지 않았다. 내역도 비운다.
        case nothingLeft
    }

    /// 문장 끝에서 이어지는 수를 떼어 낸다. 뗀 만큼 splits 가 줄어든다.
    private static func takeAmount(from splits: inout [String]) -> AmountOutcome {
        guard varieties(of: splits).contains(where: { $0.0 != .noNumericInterpretation }) else {
            return .noneSpokenAmount
        }

        dropTrailingWords(from: &splits)
        trimUnitSuffixOfLastSplit(&splits)

        let numericCharacters = takeTrailingNumericCharacters(from: &splits)
        guard !numericCharacters.isEmpty else { return .nothingLeft }

        return .amount(KoreanNumberReader.read(numericCharacters))
    }

    /// 수 뒤에 붙은 말을 떼어 낸다 — "15000원 맛있었다" 의 '맛있었다'.
    private static func dropTrailingWords(from splits: inout [String]) {
        let varieties = varieties(of: splits)
        var removed = 0
        while removed < varieties.count,
              varieties[varieties.count - removed - 1].0 == .noNumericInterpretation {
            splits.removeLast()
            removed += 1
        }
    }

    /// "15000원" 처럼 수로 시작해 단위가 붙은 조각에서 수만 남긴다.
    private static func trimUnitSuffixOfLastSplit(_ splits: inout [String]) {
        guard let last = varieties(of: splits).last, last.0 == .startsWithNumeric else { return }
        let trimmed = String(splits.removeLast().prefix(last.1))
        splits.append(trimmed)
    }

    /// 끝에서 이어지는 수 조각들을 글자 하나씩의 배열로 떼어 낸다.
    /// 조각 사이에는 공백을 남겨, 서로 다른 수가 한 덩어리로 붙지 않게 한다.
    private static func takeTrailingNumericCharacters(from splits: inout [String]) -> [String] {
        let varieties = varieties(of: splits)
        var count = 0
        while count < varieties.count, varieties[varieties.count - count - 1].0 == .allNumeric {
            count += 1
        }

        let numericSplits = splits.suffix(count)
        splits.removeLast(count)

        return numericSplits.flatMap { $0.unicodeScalars.map(String.init) + [" "] }
    }

    // MARK: - 내역

    private static func joinedInfo(_ splits: [String]) -> String? {
        let joined = splits.getUnifiedStringWithSpaceBetweenEachSplit()
        return joined.isEmpty ? nil : joined
    }

    // MARK: - 조각의 성격

    private static func varieties(of splits: [String]) -> [(SplitVariety, Int)] {
        splits.map { $0.getCharacterFormArray().getSplitVarietyAndNumericPrefixCount() }
    }
}
