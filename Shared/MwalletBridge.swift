//
//  MwalletBridge.swift
//  Mwallet  (앱 타깃에만 추가)
//
//  MwalletShared(App Group)와 앱의 Core Data 를 잇는다.
//  - publish: 예결산 요약을 위젯이 읽을 스냅샷으로 발행
//  - flushPendingExpenses: 위젯 큐에 쌓인 지출을 Core Data 로 옮김
//
//  MwalletShared.swift 도 앱 타깃에 함께 있어야 한다.
//

import CoreData
import WidgetKit

enum MwalletBridge {

    // MARK: 앱 → 위젯: 예결산 스냅샷 발행

    // 예결산 화면이 계산한 요약을 그대로 위젯 스냅샷으로 저장한다.
    static func publish(summary: BudgetSummary, travelName: String, pendingReceiptCount: Int) {
        let categories = summary.lines
            .filter { $0.spent > 0 }
            .sorted { $0.spent > $1.spent }
            .prefix(4)
            .map { BudgetSnapshot.CategorySlice(name: $0.category.description, spent: $0.spent) }

        let snapshot = BudgetSnapshot(
            travelName: travelName,
            totalPlanned: summary.totalPlanned,
            totalSpent: summary.totalSpent,
            pendingReceiptCount: pendingReceiptCount,
            categories: Array(categories),
            updatedAt: Date()
        )
        MwalletShared.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: 위젯 → 앱: 대기 지출을 Core Data 로 반영

    // 위젯에서 큐에 담긴 지출을 실제 기록으로 옮긴다. 앱이 활성화될 때 호출한다.
    // 위젯 기록은 여행을 고르지 않으므로 기본함(임시 기록)에 원화로 담는다.
    @discardableResult
    static func flushPendingExpenses(into context: NSManagedObjectContext) -> Int {
        let pending = MwalletShared.drainQueue()
        guard !pending.isEmpty else { return 0 }

        let travel = defaultTravel(in: context)

        for item in pending {
            let expense = Expense(context: context)
            expense.travel = travel
            expense.info = item.info
            expense.payAmount = item.amount
            expense.category = Int64(item.categoryIndex)
            expense.paymentMethod = Int64(item.paymentMethodIndex)
            expense.currency = ExpenseCode.currencyIndex(for: "KRW")
            expense.exchangeRate = 1               // 원화는 기준 통화라 환율 1
            expense.country = 0
            expense.payDate = DateGapHandler.shared.convertBeforeSaving(date: item.createdAt)
            expense.timeZoneIdentifier = TimeZone.current.identifier
        }

        do {
            try context.save()
        } catch {
            print("MwalletBridge | 대기 지출 반영 실패: \(error.localizedDescription)")
            return 0
        }
        return pending.count
    }

    // '임시 기록' 기본 여행. 위젯 기록이 담길 곳.
    private static func defaultTravel(in context: NSManagedObjectContext) -> Travel? {
        let request = Travel.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", tempTravelName)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
