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
    static func publish(summary: BudgetSummary, travelName: String, pendingReceiptCount: Int,
                        in context: NSManagedObjectContext) {
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
        // 위젯이 '어디로, 어떤 돈으로 담기는지' 를 적어 둘 수 있게 함께 넘긴다.
        MwalletShared.writeDestination(quickLogDestination(in: context))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: 앱 → 위젯: 담길 곳과 프리셋

    /// 위젯이 프리셋 단추에 적을 것.
    ///
    /// 통화와 프리셋을 앱이 정해서 넘긴다. 위젯 쪽에서 장부를 뒤져 셈하게 하면
    /// 타임라인을 그릴 때마다 저장소를 열어야 하고, 통화 코드를 푸는 표
    /// (CurrencyInfoModel)는 앱 타깃에만 있다.
    ///
    /// 아직 한 건도 없는 여행이면 통화를 물려받을 수 없다. 그때는 통화를 비우고
    /// 프리셋도 넘기지 않는다 — 위젯이 담아도 QuickExpenseStore 가 큐로 물러나는
    /// 상태라, 금액이 적힌 단추를 보이면 담기는 척만 하는 셈이 된다.
    static func quickLogDestination(in context: NSManagedObjectContext) -> QuickLogDestination? {
        guard let travel = destination(in: context) else { return nil }

        guard let money = QuickExpenseStore.inheritedMoney(of: travel) else {
            return QuickLogDestination(travelName: travel.displayName,
                                       currencyCode: "",
                                       presets: [])
        }

        let code = ExpenseCode.currencyCode(for: money.currency)
        // 프리셋은 그 여행에서 지금 쓰는 통화로 적은 것만 본다. 통화가 바뀐
        // 여행(국경을 넘었다)에서 옛 통화의 금액을 올리면 자릿수가 어긋난다.
        let candidates = ((travel.expenseArray?.allObjects as? [Expense]) ?? [])
            .filter { $0.currency == money.currency }
            .map {
                QuickPresetCandidate(label: $0.info ?? "",
                                     amount: $0.payAmount,
                                     categoryIndex: Int($0.category),
                                     date: $0.payDate ?? .distantPast)
            }

        return QuickLogDestination(travelName: travel.displayName,
                                   currencyCode: code,
                                   presets: QuickPresetSuggester.suggest(from: candidates,
                                                                         limit: QuickPresetSpec.maxSlots))
    }

    // MARK: 위젯 → 앱: 대기 지출을 Core Data 로 반영

    // 위젯에서 큐에 담긴 지출을 실제 기록으로 옮긴다. 앱이 활성화될 때 호출한다.
    // 원화로 담는다 — 위젯은 통화를 묻지 않는다.
    @discardableResult
    static func flushPendingExpenses(into context: NSManagedObjectContext) -> Int {
        guard !MwalletShared.readQueue().isEmpty else { return 0 }

        // 담을 곳이 없으면 큐를 비우지 않는다. 예전에는 먼저 drain 한 뒤
        // travel 이 nil 이어도 그대로 저장해, 어느 탭에도 안 보이는 지출이 생겼다.
        // CloudKit 머지 전이라 '임시 기록' 여행이 아직 없을 수 있으므로
        // 다음 활성화 때 다시 시도하도록 남겨 둔다.
        guard let travel = destination(in: context) else {
            Logger.widget.notice("담을 여행이 없어 대기 지출을 보류합니다")
            return 0
        }

        let pending = MwalletShared.drainQueue()

        // 그 여행에서 마지막으로 적은 지출의 통화를 물려받는다.
        //
        // 예전에는 무조건 원화로 적었다. 방콕에서 ฿60 짜리 커피를 담으면
        // 장부에 ₩60 이 되어, 60원짜리 커피가 됐다. 위젯이 곧장 적는 길
        // (QuickExpenseStore)과 같은 규칙을 쓴다 — 두 벌이 되면 한쪽만
        // 고쳐지는 날이 온다.
        //
        // 물려받을 것이 없는 여행(아직 한 건도 없음)은 원화로 둔다. 위젯
        // 쪽은 이 경우 아예 적지 않고 큐에 남기지만, 여기까지 왔다는 것은
        // 이미 큐에 있다는 뜻이라 어딘가에는 적어야 한다.
        let money = QuickExpenseStore.inheritedMoney(of: travel)

        for item in pending {
            let expense = Expense(context: context)
            expense.travel = travel
            expense.info = item.info
            expense.payAmount = item.amount
            expense.category = Int64(item.categoryIndex)
            expense.paymentMethod = Int64(item.paymentMethodIndex)
            expense.currency = money?.currency ?? ExpenseCode.currencyIndex(for: "KRW")
            expense.exchangeRate = money?.exchangeRate ?? 1
            // 위젯은 위치를 묻지 않으므로 어느 나라인지 알 수 없다.
            // 예전에는 0(대한민국)을 넣어, 해외에서 담은 지출도 국내로 표시됐다.
            expense.country = money?.country ?? ExpenseCode.unknownCountry
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
    /// 위젯에서 담은 지출이 들어갈 여행.
    ///
    /// 여행 중이면 그 여행으로 간다. 예전에는 늘 기본함(임시 기록)으로 보냈는데,
    /// 방콕에 있는 동안 위젯을 눌러도 방콕 여행에 안 붙고 기본함에 쌓였다.
    /// 앱을 열어 하나씩 옮겨야 했으니, 빠르라고 만든 위젯이 일을 늘리고 있었다.
    ///
    /// 여행 중이 아니면 예전처럼 기본함이다. 어느 여행인지 알 수 없는데
    /// 아무 여행에나 붙이면 남의 결산이 틀어진다.
    static func destination(in context: NSManagedObjectContext) -> Travel? {
        // 규칙 자체는 QuickExpenseStore 에 있다. 위젯도 같은 판단을 해야 하는데
        // 그쪽에서는 앱 전용 확장을 쓸 수 없어, 두 벌이 되지 않도록 그리로 모았다.
        QuickExpenseStore.destination(in: context)
    }

}
