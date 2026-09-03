//
//  SettlementSummary.swift
//  Mwallet
//
//  누가 얼마씩 썼는지 나눈다.
//
//  단기사역은 여럿이 함께 다니고 한 사람이 몰아서 내는 일이 잦다. 돌아와서
//  나누려면 '이 지출을 누가 같이 썼나' 를 알아야 하는데, 그 값은 기록할 때
//  이미 받아 두고 있다(Expense.participants). 새로 받을 것은 없고
//  나누기만 하면 된다.
//
//  나누는 규칙은 하나다 — 한 지출은 그것을 함께 쓴 사람 수로 똑같이 나눈다.
//  누가 냈는지는 아직 기록하지 않으므로 '받을 돈/줄 돈' 까지는 셈하지 않는다.
//  여기서 답하는 것은 '나는 얼마를 썼나' 다.
//

import Foundation

/// 한 사람 몫.
struct SettlementShare: Identifiable, Equatable {

    /// 지출에 저장된 이름. 사람을 묶는 열쇠라 번역하지 않는다.
    let name: String
    /// 이 사람이 나눠 진 금액(원).
    let amount: Double
    /// 이 사람이 낀 지출 건수.
    let expenseCount: Int

    var id: String { name }

    /// 화면에 적을 이름. '나' 만 기기 언어로 옮기고, 사용자가 적은 이름은 그대로.
    var displayName: String { Travel.participantDisplayName(name) }
}

struct SettlementSummary {

    let shares: [SettlementShare]

    /// 나눠진 금액의 합. 환산하지 못한 건은 빠져 있다.
    let totalSettled: Double

    /// 함께 쓴 사람이 적히지 않은 지출의 합.
    ///
    /// 누구 몫인지 알 수 없어 사람에게 나누지 못한다. 옛 기록이나 혼자
    /// 쓴 것을 그냥 저장한 경우다. 숨기지 않고 따로 알린다.
    let unassigned: Double
    let unassignedCount: Int

    /// 환율을 받지 못해 원화로 옮기지 못한 지출의 수.
    let unconvertibleCount: Int

    var hasUnassigned: Bool { unassignedCount > 0 }
    var hasUnconvertible: Bool { unconvertibleCount > 0 }
    var isEmpty: Bool { shares.isEmpty && unassignedCount == 0 }

    /// 가장 많이 진 사람의 몫. 막대 길이를 재는 기준이다.
    var largestShare: Double { shares.map(\.amount).max() ?? 0 }

    // MARK: - 셈하기

    init(expenses: [Expense]) {
        var totals: [String: Double] = [:]
        var counts: [String: Int] = [:]
        var settled: Double = 0
        var unassigned: Double = 0
        var unassignedCount = 0
        var unconvertible = 0

        for expense in expenses {
            // 환율을 못 받은 건은 원화로 옮길 수 없다. 억지로 0으로 두면
            // 합계가 조용히 작아지므로 세어 두고 넘긴다.
            guard let amount = expense.amountInKRW else {
                unconvertible += 1
                continue
            }

            let people = expense.participants.filter { !$0.isEmpty }
            guard !people.isEmpty else {
                unassigned += amount
                unassignedCount += 1
                continue
            }

            // 한 지출을 함께 쓴 사람 수로 똑같이 나눈다.
            let each = amount / Double(people.count)
            for person in people {
                totals[person, default: 0] += each
                counts[person, default: 0] += 1
            }
            settled += amount
        }

        // 많이 진 사람부터. 같으면 이름 순서로 두어 볼 때마다 자리가 바뀌지 않게 한다.
        self.shares = totals
            .map { SettlementShare(name: $0.key, amount: $0.value, expenseCount: counts[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                lhs.amount == rhs.amount ? lhs.name < rhs.name : lhs.amount > rhs.amount
            }
        self.totalSettled = settled
        self.unassigned = unassigned
        self.unassignedCount = unassignedCount
        self.unconvertibleCount = unconvertible
    }
}
