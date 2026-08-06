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
import OSLog
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
        guard !MwalletShared.readQueue().isEmpty else { return 0 }

        // 담을 곳이 없으면 큐를 비우지 않는다. 예전에는 먼저 drain 한 뒤
        // travel 이 nil 이어도 그대로 저장해, 어느 탭에도 안 보이는 지출이 생겼다.
        // CloudKit 머지 전이라 '임시 기록' 여행이 아직 없을 수 있으므로
        // 다음 활성화 때 다시 시도하도록 남겨 둔다.
        guard let travel = defaultTravel(in: context) else {
            Logger.widget.notice("기본 여행이 없어 대기 지출을 보류합니다")
            return 0
        }

        let pending = MwalletShared.drainQueue()

        for item in pending {
            let expense = Expense(context: context)
            expense.travel = travel
            expense.info = item.info
            expense.payAmount = item.amount
            expense.category = Int64(item.categoryIndex)
            expense.paymentMethod = Int64(item.paymentMethodIndex)
            expense.currency = ExpenseCode.currencyIndex(for: "KRW")
            expense.exchangeRate = 1               // 원화는 기준 통화라 환율 1
            // 위젯은 위치를 묻지 않으므로 어느 나라인지 알 수 없다.
            // 예전에는 0(대한민국)을 넣어, 해외에서 담은 지출도 국내로 표시됐다.
            expense.country = ExpenseCode.unknownCountry
            expense.payDate = item.createdAt
            expense.timeZoneIdentifier = TimeZone.current.identifier
        }

        do {
            try context.save()
        } catch {
            // 큐는 이미 비운 뒤라 여기서 그냥 돌아가면 기록이 사라진다.
            // 만들다 만 객체를 되돌리고 큐를 복구해 다음 기회에 다시 시도한다.
            Logger.widget.error("대기 지출 반영 실패: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            pending.forEach(MwalletShared.enqueue)
            return 0
        }
        return pending.count
    }

    // '임시 기록' 기본 여행. 위젯 기록이 담길 곳.
    private static func defaultTravel(in context: NSManagedObjectContext) -> Travel? {
        return Travel.fetchDefault(in: context)
    }
}
