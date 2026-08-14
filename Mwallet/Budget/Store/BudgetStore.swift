//
//  BudgetStore.swift
//  Mwallet
//
//  카테고리별 예산의 읽기·쓰기.
//  한 사역 일정에 카테고리당 하나의 Budget 만 두어 합산 규칙을 단순하게 유지한다.
//

import CoreData
import Foundation
import OSLog

final class BudgetStore {

    /// 이 스토어가 보는 저장소.
    ///
    /// 위젯 스냅샷을 낼 때 '어디로 담기는지' 를 같은 저장소에서 물어야 해서 연다.
    /// 화면이 따로 컨텍스트를 들고 있으면 스토어가 보는 것과 어긋날 수 있다.
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - 조회

    func budgets(for travel: Travel?) -> [Budget] {
        guard let travel else { return [] }
        let set = travel.budgetArray as? Set<Budget> ?? []
        return set.sorted { $0.category < $1.category }
    }

    func expenses(for travel: Travel?) -> [Expense] {
        guard let travel else { return [] }
        let set = travel.expenseArray as? Set<Expense> ?? []
        return set.sorted { $0.paidDate > $1.paidDate }
    }

    func summary(for travel: Travel?) -> BudgetSummary {
        BudgetSummary(
            travel: travel,
            budgets: budgets(for: travel),
            expenses: expenses(for: travel)
        )
    }

    // 예산을 세울 수 있는 여행. '임시 기록' 은 사용자가 만든 여행이 아니다.
    /// 화면에 올릴 여행 목록. 고르는 규칙은 TravelStore 한 곳에 있다.
    func availableTravels() -> [Travel] {
        TravelStore(context: context).availableTravels()
    }

    // MARK: - 쓰기

    // 카테고리별 예산을 통째로 맞춘다.
    // 0 원은 '배정하지 않음' 이므로 레코드를 남기지 않고 지운다.
    func save(_ amounts: [ExpenseInfoCategory: Double], for travel: Travel) throws {
        let existing = budgets(for: travel)
        var byCategory: [Int64: Budget] = [:]
        for budget in existing {
            // 같은 카테고리가 중복으로 있으면 하나만 남기고 정리한다.
            if let kept = byCategory[budget.category] {
                context.delete(kept.amount >= budget.amount ? budget : kept)
                if kept.amount < budget.amount { byCategory[budget.category] = budget }
            } else {
                byCategory[budget.category] = budget
            }
        }

        for category in ExpenseInfoCategory.selectable {
            let key = Int64(category.rawValue)
            let amount = amounts[category] ?? 0

            if amount > 0 {
                let budget = byCategory[key] ?? Budget(context: context)
                budget.travel = travel
                budget.category = key
                budget.amount = amount
            } else if let obsolete = byCategory[key] {
                context.delete(obsolete)
            }
        }

        try context.save()
    }
}
