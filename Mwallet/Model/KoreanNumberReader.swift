//
//  KoreanNumberReader.swift
//  Mwallet
//
//  글자 하나씩 늘어놓은 배열을 수 하나로 읽어 낸다.
//
//    ["사", "천", "오", "백"]        → 4500
//    ["삼", "만", " ", "오", "천"]   → 35000
//    ["1", "2", ".", "5"]           → 12.5
//
//  한국어 수사는 자리를 곱셈으로 쌓는다 — 사천오백은 (4×1000) + (5×100).
//  그래서 '만' 과 소수점을 먼저 찾아 세 덩어리로 가른 뒤, 각 덩어리를
//  따로 읽고 마지막에 이어 붙인다.
//
//    앞 만 뒤 . 소수  →  앞×10000 + 뒤 + 0.소수
//
//  '앞' 과 '뒤' 는 같은 규칙으로 읽히므로 처리를 공유한다.
//  (예전에는 두 덩어리에 같은 코드를 나란히 두 벌씩 적어 두었다)
//

enum KoreanNumberReader {

    private static let powerUnits = ["십": 10, "백": 100, "천": 1000]

    /// 글자 배열을 수로 읽는다. 수로 읽히지 않는 글자는 0으로 친다.
    static func read(_ characters: [String]) -> Double {
        var mono = characters

        // 1. '만' 과 소수점은 각각 가장 앞의 하나만 자릿수로 쓴다.
        //    "삼만 오만" 처럼 여러 번 말해도 첫 자리만 센다.
        let (fourPowerIndex, dotIndex) = normalizeMarkers(&mono)

        // 2. 소수점과 '만' 을 기준으로 세 덩어리로 가른다.
        let parts = partition(mono, fourPowerIndex: fourPowerIndex, dotIndex: dotIndex)

        // 3. 정수 두 덩어리를 각각 아라비아 수의 배열로 정리한다.
        //
        //    '앞' 만 만 배가 되므로, 이미 만 단위를 넘는 수는 '앞' 에서 덜어낸다.
        //    "123456만" 처럼 말한 경우인데 그 수가 합계에서 통째로 빠진다.
        //    옮겨 오기 전 코드와 같은 동작이다.
        let headDigits = integerDigits(parts.head, droppingOversizedNumbers: true)
        let tailDigits = integerDigits(parts.tail, droppingOversizedNumbers: false)

        // '만' 앞에 수사가 없으면 1만이다.
        // 자릿수 확장은 홀로 선 '십'·'백'·'천' 을 10·100·1000 으로 바꿔 주는데
        // '만' 에는 같은 처리가 없어서 '만원' 이 0원으로 잡혔다.
        let multiplier = (fourPowerIndex != nil && headDigits.isEmpty) ? 1 : sum(of: headDigits)

        return Double(multiplier * 10_000) + Double(sum(of: tailDigits)) + readFraction(parts.fraction)
    }

    // MARK: - 1. 자릿수 표시 정리

    /// '만' 과 소수점을 각각 가장 앞의 하나만 남기고, 정리된 위치를 돌려준다.
    private static func normalizeMarkers(_ mono: inout [String]) -> (fourPower: Int?, dot: Int?) {
        // 아라비아 마침표와 한글 '점' 중 먼저 나온 쪽을 소수점으로 삼는다.
        let arabicDot = mono.firstIndex(of: ".") ?? Int.max
        let koreanDot = mono.firstIndex(of: "점") ?? Int.max
        var dotIndex: Int? = min(arabicDot, koreanDot)
        if dotIndex == Int.max { dotIndex = nil }

        mono = mono.filter { $0 != "." && $0 != "점" }
        if let dotIndex, dotIndex <= mono.count {
            mono.insert(".", at: dotIndex)
        }

        var fourPowerIndex: Int? = mono.firstIndex(of: "만") ?? Int.max
        if fourPowerIndex == Int.max { fourPowerIndex = nil }

        mono = mono.filter { $0 != "만" }

        dotIndex = mono.firstIndex(of: ".") ?? Int.max
        if dotIndex == Int.max { dotIndex = nil }

        // '만' 은 소수점보다 앞에 있을 때만 자릿수로 되돌린다.
        if let fourPowerIndex, fourPowerIndex <= mono.count {
            if dotIndex == nil {
                mono.insert("만", at: fourPowerIndex)
            } else if let dot = dotIndex, fourPowerIndex <= dot {
                mono.insert("만", at: fourPowerIndex)
                dotIndex = dot + 1
            }
        }

        return (fourPowerIndex, dotIndex)
    }

    // MARK: - 2. 세 덩어리로 가르기

    /// '만' 앞, '만' 뒤, 소수점 뒤의 세 덩어리.
    private struct Parts {
        var head: [String] = []
        var tail: [String] = []
        var fraction: [String] = []
    }

    private static func partition(
        _ mono: [String],
        fourPowerIndex: Int?,
        dotIndex: Int?
    ) -> Parts {
        var integerPart = mono
        var fraction: [String] = []

        if let dotIndex {
            if dotIndex == integerPart.count - 1 {
                integerPart.removeLast() // 소수점으로 끝나면 소수부가 없다
            } else {
                fraction = Array(integerPart[(dotIndex + 1)...])
                integerPart = Array(integerPart[..<dotIndex])
            }
        }

        guard let fourPowerIndex else {
            return Parts(tail: integerPart, fraction: fraction)
        }

        // "12.5만" 처럼 '만' 이 소수점 뒤에 오면 위 단계에서 자릿수로 되돌리지
        // 않는데, 자리 번호는 그대로 남는다. 정수부 길이로 눌러 범위를 지킨다.
        let pivot = min(fourPowerIndex, integerPart.count)
        return Parts(head: Array(integerPart[..<pivot]),
                     tail: pivot < integerPart.count ? Array(integerPart[(pivot + 1)...]) : [],
                     fraction: fraction)
    }

    // MARK: - 3. 정수 덩어리 읽기

    /// 글자 배열을 더하기만 하면 되는 아라비아 수의 배열로 바꾼다.
    private static func integerDigits(
        _ characters: [String],
        droppingOversizedNumbers: Bool
    ) -> [String] {
        var mono = mergingAdjacentArabicDigits(characters)
        mono.removeAll { $0 == " " }
        if droppingOversizedNumbers {
            mono.removeAll { $0.count > 4 }
        }
        return convertingKoreanNumerals(expandingPowerUnits(mono))
    }

    private static func sum(of digits: [String]) -> Int {
        digits.reduce(0) { $0 + (Int($1) ?? 0) }
    }

    /// "1", "2", "5" 처럼 이어지는 아라비아 숫자를 "125" 한 덩어리로 합친다.
    /// 조각 사이의 공백이 남아 있어야 "3만 12345" 가 서로 붙지 않는다.
    private static func mergingAdjacentArabicDigits(_ characters: [String]) -> [String] {
        var mono = characters
        guard mono.count > 1 else { return mono }

        for index in (1..<mono.count).reversed() {
            guard let left = mono[index - 1].first, let right = mono[index].first,
                  left.getCharacterForm() == .arabicNumeric,
                  right.getCharacterForm() == .arabicNumeric else { continue }
            mono[index - 1] = String(left) + mono[index]
            mono.remove(at: index)
        }
        return mono
    }

    /// '십'·'백'·'천' 을 앞의 수사와 곱해 아라비아 수로 바꾼다.
    /// 앞에 수사가 없으면 10·100·1000 그 자체로 읽는다 — "천원" 은 1000원이다.
    private static func expandingPowerUnits(_ characters: [String]) -> [String] {
        var mono = characters

        if mono.count > 1 {
            for index in (1..<mono.count).reversed() {
                guard let power = powerUnits[mono[index]] else { continue }

                let previous = mono[index - 1]
                if previous.count == 1, let numeral = previous.first,
                   numeral.getCharacterForm() == .koreanNumeric {
                    let digit = Int(numeral.getCorrespondingArabicString()) ?? 0
                    mono[index - 1] = "\(digit * power)"
                    mono.remove(at: index)
                } else {
                    mono[index] = "\(power)"
                }
            }
        }

        // 첫 자리는 앞에 볼 것이 없으므로 자릿수 그대로 읽는다.
        if let first = mono.first, let power = powerUnits[first] {
            mono[0] = "\(power)"
        }
        return mono
    }

    /// 남은 한글 수사를 아라비아 숫자로 바꾼다.
    private static func convertingKoreanNumerals(_ characters: [String]) -> [String] {
        characters.map { character in
            guard character.count == 1, let numeral = character.first,
                  numeral.getCharacterForm() == .koreanNumeric else { return character }
            return numeral.getCorrespondingArabicString()
        }
    }

    // MARK: - 4. 소수부 읽기

    /// 소수부는 수사만 남기고 둘째 자리에서 끊는다.
    private static func readFraction(_ characters: [String]) -> Double {
        var mono = characters

        // 낱개 하나만 남았을 때는 걸러 내지 않는다. 옮겨 오기 전 동작을 지킨다.
        if mono.count > 1 {
            mono.removeAll { character in
                guard let first = character.first else { return false }
                let form = first.getCharacterForm()
                return form != .arabicNumeric && form != .koreanNumeric
            }
        }

        let digits = convertingKoreanNumerals(mono).joined()
        return Double(Int((Double("0." + digits) ?? 0) * 100)) / 100
    }
}
