//
//  QuickPresetSuggester.swift
//  Mwallet · MwalletWidgetExtension
//
//  위젯 프리셋 세 칸을, 그 여행에서 실제로 적어 온 것에서 뽑는다.
//
//  ─────────────────────────────────────────────────────────────
//  왜 코드에 박아 두면 안 되는가
//
//  예전 프리셋은 커피 4,500 · 식사 10,000 · 교통 3,000 이었다. 여행 앱인데
//  한국 물가이고, 게다가 위젯은 그 여행이 쓰던 통화로 저장한다. 방콕 여행에서
//  '커피 4,500' 을 누르면 장부에 ฿4,500 — 17만 원짜리 커피가 적혔다.
//
//  나라를 뒤져 물가를 짐작할 수도 있지만, 더 정확한 답이 이미 손에 있다.
//  이 사람이 이 여행에서 무엇을 얼마에 적어 왔는지다. 방콕에서 사흘 동안
//  ฿60 짜리 커피를 세 번 적었다면 다음 커피도 ฿60 이다.
//  ─────────────────────────────────────────────────────────────
//
//  고르는 규칙은 '자주 적은 것 우선' 이다.
//
//    1. 같은 이름으로 여러 번 적은 것을 앞세운다 — 반복이 곧 '자주 쓰는 것'
//    2. 같은 횟수면 최근에 적은 것을 앞세운다
//    3. 반복이 세 칸을 못 채우면 최근에 적은 것으로 나머지를 채운다
//
//  금액은 그 이름으로 적은 것 중 가장 흔한 값이다. 평균이 아니다 — 커피를
//  ฿60 에 세 번, ฿250 에 한 번 적었다면 답은 ฿60 이지 ฿107.5 가 아니다.
//

import Foundation

/// 지출 하나에서 뽑아낸, 프리셋이 될 만한 것.
///
/// Core Data 의 Expense 를 그대로 받지 않는다. 이 셈은 저장소와 아무 상관이
/// 없어서, 값만 받으면 시험에서 장부를 띄우지 않고도 규칙을 확인할 수 있다.
struct QuickPresetCandidate: Equatable {
    let label: String
    let amount: Double
    let categoryIndex: Int
    let date: Date
}

enum QuickPresetSuggester {

    /// 위젯에 올릴 프리셋. 없으면 빈 배열.
    static func suggest(from candidates: [QuickPresetCandidate], limit: Int = 3) -> [QuickPresetSpec] {
        let groups = group(usable(candidates))
        guard !groups.isEmpty else { return [] }

        // 반복된 것을 먼저, 그다음 최근 것. 두 무리 안에서는 각자의 기준으로 세운다.
        let repeated = groups.filter { $0.count > 1 }
            .sorted { ($0.count, $0.latest) > ($1.count, $1.latest) }
        let once = groups.filter { $0.count == 1 }
            .sorted { $0.latest > $1.latest }

        return (repeated + once).prefix(limit).map(\.spec)
    }

    // MARK: - 고르기 전에 거르기

    /// 프리셋이 될 수 없는 것을 걷어낸다.
    ///
    /// 이름이 없으면 버튼에 적을 글자가 없고, 금액이 0 이하면 눌러도 뜻이 없다.
    private static func usable(_ candidates: [QuickPresetCandidate]) -> [QuickPresetCandidate] {
        candidates.filter { candidate in
            !candidate.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && candidate.amount > 0
        }
    }

    // MARK: - 같은 것끼리 묶기

    private struct Group {
        let spec: QuickPresetSpec
        let count: Int
        let latest: Date
    }

    /// 이름과 분류가 같으면 한 묶음으로 본다.
    ///
    /// 이름만으로 묶지 않는 까닭은 '택시' 를 교통으로도 기타로도 적을 수 있어서다.
    /// 묶어 버리면 프리셋이 엉뚱한 분류로 담긴다.
    private static func group(_ candidates: [QuickPresetCandidate]) -> [Group] {
        var buckets: [String: [QuickPresetCandidate]] = [:]
        for candidate in candidates {
            buckets[key(for: candidate), default: []].append(candidate)
        }

        return buckets.values.compactMap { bucket -> Group? in
            guard let latest = bucket.max(by: { $0.date < $1.date }) else { return nil }
            return Group(
                spec: QuickPresetSpec(emoji: QuickPresetEmoji.of(categoryIndex: latest.categoryIndex),
                                      // 적을 때마다 띄어쓰기가 달랐을 수 있다.
                                      // 가장 최근에 쓴 대로 적는다.
                                      label: latest.label.trimmingCharacters(in: .whitespacesAndNewlines),
                                      amount: commonAmount(in: bucket),
                                      categoryIndex: latest.categoryIndex),
                count: bucket.count,
                latest: latest.date
            )
        }
    }

    /// 묶는 열쇠. 대소문자와 앞뒤 공백은 같은 것으로 본다.
    private static func key(for candidate: QuickPresetCandidate) -> String {
        let name = candidate.label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(candidate.categoryIndex)\u{1F}\(name)"
    }

    /// 그 묶음에서 가장 흔한 금액. 같은 횟수면 최근 것.
    ///
    /// 평균을 쓰지 않는다. 커피를 ฿60 에 세 번, 어느 날 호텔 라운지에서
    /// ฿250 에 한 번 적었다면 다음에 누를 커피는 ฿60 이다. 평균 ฿107.5 는
    /// 한 번도 낸 적 없는 금액이다.
    private static func commonAmount(in bucket: [QuickPresetCandidate]) -> Double {
        var counts: [Double: Int] = [:]
        var latest: [Double: Date] = [:]
        for candidate in bucket {
            counts[candidate.amount, default: 0] += 1
            if let seen = latest[candidate.amount] {
                latest[candidate.amount] = max(seen, candidate.date)
            } else {
                latest[candidate.amount] = candidate.date
            }
        }
        return counts
            .map { (amount: $0.key, count: $0.value, date: latest[$0.key] ?? .distantPast) }
            .sorted { ($0.count, $0.date) > ($1.count, $1.date) }
            .first?.amount ?? bucket.first?.amount ?? 0
    }
}

// MARK: - 분류별 그림

/// 프리셋 단추에 얹는 그림.
///
/// 이름은 사용자가 적은 것이라 무엇이든 올 수 있다. 그림까지 이름에서 짐작하면
/// 틀리기 쉬워서, 분류 하나에 하나씩만 정해 둔다. 분류는 우리가 아는 값이다.
enum QuickPresetEmoji {

    /// ExpenseInfoCategory.rawValue → 그림.
    static func of(categoryIndex: Int) -> String {
        switch categoryIndex {
        case 0: return "✈️"   // 항공
        case 1: return "🏠"   // 숙소
        case 2: return "🚌"   // 교통
        case 3: return "🍽"   // 식비
        case 4: return "🗺"   // 관광
        case 5: return "🛍"   // 쇼핑
        case 6: return "🎁"   // 선물
        case 7: return "✝️"   // 사역비
        case 8: return "🤍"   // 헌금
        default: return "📝"  // 기타·알 수 없음
        }
    }
}
