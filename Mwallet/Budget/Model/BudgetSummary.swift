//
//  BudgetSummary.swift
//  Mwallet
//
//  한 사역 일정의 예산 대비 집행을 계산한다.
//  예산은 Budget(카테고리별), 집행은 Expense(영수증에 세부가 담긴다).
//  화면 바깥의 순수 타입이라 값이 화면마다 갈라지지 않는다.
//

import Foundation

// MARK: - 카테고리 한 줄

struct BudgetLine: Identifiable {

    let category: ExpenseInfoCategory
    let planned: Double        // 배정한 예산
    let spent: Double          // 실제 집행 (원화 환산)
    let spentCount: Int        // 집행 건수
    // 환율을 얻지 못해 집행액에 넣지 못한 건수. 합계를 지어내지 않고 따로 알린다.
    let unconvertibleCount: Int

    var id: Int { category.rawValue }

    var remaining: Double { planned - spent }
    var isOverspent: Bool { spent > planned }

    // 예산이 0이면 집행률을 낼 수 없다. 쓴 게 있으면 초과로 본다.
    var ratio: Double? {
        guard planned > 0 else { return nil }
        return spent / planned
    }

    // 진행 막대는 100%를 넘어가지 않게 자른다. 초과 여부는 색과 숫자로 알린다.
    var barRatio: Double {
        guard let ratio else { return spent > 0 ? 1 : 0 }
        return min(max(ratio, 0), 1)
    }

    var hasAnything: Bool { planned > 0 || spent > 0 || spentCount > 0 }
}

// MARK: - 사역 전체 결산

struct BudgetSummary {

    let travel: Travel?
    let lines: [BudgetLine]

    let totalPlanned: Double
    let totalSpent: Double
    let unconvertibleCount: Int

    var remaining: Double { totalPlanned - totalSpent }
    var isOverspent: Bool { totalSpent > totalPlanned }
    var hasBudget: Bool { totalPlanned > 0 }
    var hasUnconvertible: Bool { unconvertibleCount > 0 }

    var ratio: Double? {
        guard totalPlanned > 0 else { return nil }
        return totalSpent / totalPlanned
    }

    var barRatio: Double {
        guard let ratio else { return totalSpent > 0 ? 1 : 0 }
        return min(max(ratio, 0), 1)
    }

    // 예산을 넘긴 항목. 재정 담당자가 가장 먼저 봐야 할 정보다.
    var overspentLines: [BudgetLine] {
        lines.filter { $0.isOverspent }
    }

    init(travel: Travel?, budgets: [Budget], expenses: [Expense]) {
        self.travel = travel

        var plannedByCategory: [Int: Double] = [:]
        for budget in budgets where budget.amount > 0 {
            plannedByCategory[Int(budget.category), default: 0] += budget.amount
        }

        var spentByCategory: [Int: Double] = [:]
        var countByCategory: [Int: Int] = [:]
        var unconvertibleByCategory: [Int: Int] = [:]
        var unconvertibleTotal = 0

        for expense in expenses {
            let key = Int(expense.category)
            countByCategory[key, default: 0] += 1
            guard let krw = expense.amountInKRW else {
                unconvertibleByCategory[key, default: 0] += 1
                unconvertibleTotal += 1
                continue
            }
            spentByCategory[key, default: 0] += krw
        }

        // 예산이나 집행이 하나라도 있는 카테고리만 보여 준다.
        // 빈 줄이 늘어서면 정작 봐야 할 항목이 묻힌다.
        self.lines = ExpenseInfoCategory.selectable.compactMap { category in
            let key = category.rawValue
            let line = BudgetLine(
                category: category,
                planned: plannedByCategory[key] ?? 0,
                spent: spentByCategory[key] ?? 0,
                spentCount: countByCategory[key] ?? 0,
                unconvertibleCount: unconvertibleByCategory[key] ?? 0
            )
            return line.hasAnything ? line : nil
        }

        self.totalPlanned = plannedByCategory.values.reduce(0, +)
        self.totalSpent = spentByCategory.values.reduce(0, +)
        self.unconvertibleCount = unconvertibleTotal
    }
}

// MARK: - 표시용 포맷

enum BudgetFormat {

    static func percent(_ ratio: Double?) -> String {
        guard let ratio else { return "-" }
        return String(format: "%.0f%%", ratio * 100)
    }

    // 잔액은 부호를 분명히 한다. 초과분을 음수로만 보여 주면 눈에 안 들어온다.
    static func remaining(_ value: Double) -> String {
        value < 0
            ? String(localized: "\(ReceiptFormat.krw(abs(value))) 초과")
            : String(localized: "\(ReceiptFormat.krw(value)) 남음")
    }
}
