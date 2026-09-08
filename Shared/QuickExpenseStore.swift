//
//  QuickExpenseStore.swift
//  Mwallet · MwalletWidgetExtension
//
//  위젯에서 담은 지출을 장부에 적는다.
//
//  여태는 위젯이 UserDefaults 큐에 담아 두고, 앱을 열어야 기록이 됐다.
//  장부가 App Group 으로 옮겨 온 지금은 위젯이 직접 적을 수 있다.
//
//  ─────────────────────────────────────────────────────────────
//  통화 — 여기가 이 파일의 진짜 이유다.
//
//  예전에는 위젯이 담은 것을 무조건 원화로 적었다. 방콕에서 ฿60 짜리 커피를
//  담으면 장부에 ₩60 으로 들어갔다. 60원짜리 커피가 되는 것이다. 여행 앱에서
//  위젯이 가장 쓸모 있는 순간이 해외인데, 정확히 그때 틀렸다.
//
//  위젯은 위치도 통화도 묻지 않는다. 대신 **그 여행에서 마지막으로 적은
//  지출이 쓰던 통화와 환율**을 그대로 물려받는다. 방콕에서 사흘째 바트로
//  적고 있었다면 다음 것도 바트다. 나라를 뒤지는 것보다 정확하다 — 실제로
//  무엇으로 적어 왔는지가 답이기 때문이다.
//
//  아직 한 건도 없는 여행이면 물려받을 것이 없다. 그때는 적지 않고 큐로
//  물러난다. 짐작으로 통화를 고르느니 앱이 제대로 정하게 두는 편이 낫다.
//  ─────────────────────────────────────────────────────────────
//

import CoreData
import Foundation
import OSLog

private let quickLog = Logger(subsystem: MwalletShared.appGroupID, category: "quickExpense")

enum QuickExpenseStore {

    /// 담긴 결과.
    enum Outcome: Equatable {
        /// 장부에 적었다. 어떤 통화로 적었는지는 통화 인덱스로 돌려준다 —
        /// 코드 문자열로 바꾸는 표는 앱 타깃에만 있다.
        case saved(currency: Int64)
        /// 적지 못해 큐에 남겼다. 앱을 열면 옮겨진다.
        case queued(reason: Reason)

        // 'queued 인 까닭' 이라는 뜻이 이름이 아니라 자리에 담겨 있다.
        // 밖으로 빼면 QuickExpenseQueueReason 처럼 자리를 이름으로 되풀이해야
        // 하고, 그러면 Outcome 을 안 보고도 읽히는 대신 짝이 흐려진다.
        // swiftlint:disable:next nesting
        enum Reason: Equatable {
            /// App Group 장부를 열지 못했다.
            case noStore
            /// 담을 여행이 없다.
            case noTravel
            /// 그 여행에 아직 지출이 없어 통화를 알 수 없다.
            case noCurrency
            /// 저장하다 실패했다.
            case saveFailed
        }
    }

    // MARK: - 담기

    /// 위젯에서 누른 지출 하나를 장부에 적는다.
    ///
    /// 적지 못하면 큐에 남긴다. 어느 쪽이든 기록은 사라지지 않는다.
    @discardableResult
    static func log(_ pending: PendingExpense) -> Outcome {
        guard let context = openContext() else {
            MwalletShared.enqueue(pending)
            return .queued(reason: .noStore)
        }
        // performAndWait 는 이름 그대로 끝날 때까지 기다린다. 그런데 Swift 6 은
        // 이 클로저를 다른 곳에서 돌 수도 있는 것으로 보아, 바깥 변수를 고치면
        // 경고한다. 여기서는 기다린 뒤에만 읽으므로 겹칠 일이 없다.
        nonisolated(unsafe) var outcome: Outcome = .queued(reason: .saveFailed)
        context.performAndWait {
            outcome = write(pending, in: context)
        }
        if case .queued = outcome {
            MwalletShared.enqueue(pending)
            MwalletShared.writeLastLogged(
                LoggedRecord(info: pending.info, amount: pending.amount, expenseURI: nil)
            )
        }
        return outcome
    }

    private static func write(_ pending: PendingExpense,
                              in context: NSManagedObjectContext) -> Outcome {
        guard let travel = destination(in: context) else { return .queued(reason: .noTravel) }
        guard let money = inheritedMoney(of: travel) else { return .queued(reason: .noCurrency) }

        let expense = Expense(context: context)
        expense.travel = travel
        expense.info = pending.info
        expense.payAmount = pending.amount
        expense.category = Int64(pending.categoryIndex)
        expense.paymentMethod = Int64(pending.paymentMethodIndex)
        expense.currency = money.currency
        expense.exchangeRate = money.exchangeRate
        expense.country = money.country
        expense.payDate = pending.createdAt
        expense.timeZoneIdentifier = TimeZone.current.identifier

        do {
            try context.save()
            // 저장 전 objectID 는 임시라 다음에 못 찾는다. 저장한 뒤에 적는다.
            MwalletShared.writeLastLogged(
                LoggedRecord(info: pending.info,
                             amount: pending.amount,
                             expenseURI: expense.objectID.uriRepresentation().absoluteString)
            )
            return .saved(currency: money.currency)
        } catch {
            quickLog.error("빠른 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            return .queued(reason: .saveFailed)
        }
    }

    // MARK: - 되돌리기

    /// 방금 담은 것을 도로 뺀다.
    ///
    /// 장부에 적힌 것이면 그 지출을 지우고, 큐에 남은 것이면 큐에서 뺀다.
    /// 어느 쪽인지는 담을 때 적어 둔 것으로 안다 — 나중에 짐작하면 틀린다.
    @discardableResult
    static func undoLast() -> Bool {
        guard let record = MwalletShared.lastLogged else {
            // 옛 방식으로 담긴 것이 아직 큐에 남아 있을 수 있다.
            return MwalletShared.undoLast() != nil
        }

        defer { MwalletShared.writeLastLogged(nil) }

        guard let uri = record.expenseURI else {
            return MwalletShared.undoLast() != nil
        }
        return deleteExpense(uri: uri)
    }

    private static func deleteExpense(uri: String) -> Bool {
        guard let context = openContext(),
              let url = URL(string: uri),
              let objectID = context.persistentStoreCoordinator?
                  .managedObjectID(forURIRepresentation: url) else { return false }

        // performAndWait 는 이름 그대로 끝날 때까지 기다린다. 그런데 Swift 6 은
        // 이 클로저를 다른 곳에서 돌 수도 있는 것으로 보아, 바깥 변수를 고치면
        // 경고한다. 여기서는 기다린 뒤에만 읽으므로 겹칠 일이 없다.
        nonisolated(unsafe) var removed = false
        context.performAndWait {
            // 앱에서 이미 지웠을 수 있다. 그때는 조용히 넘어간다.
            guard let expense = try? context.existingObject(with: objectID) else { return }
            context.delete(expense)
            do {
                try context.save()
                removed = true
            } catch {
                quickLog.error("되돌리기 실패: \(error.localizedDescription, privacy: .public)")
                context.rollback()
            }
        }
        return removed
    }

    // MARK: - 물려받을 통화

    struct Money: Equatable {
        let currency: Int64
        let exchangeRate: Double
        let country: Int64
    }

    /// 그 여행에서 마지막으로 적은 지출의 통화·환율·나라.
    ///
    /// 환율이 없는(받지 못한) 지출은 건너뛴다. 환율 없이 물려받으면 그 지출도
    /// 합계에서 빠져, 담았는데 어디에도 안 세지는 것이 된다.
    static func inheritedMoney(of travel: Travel) -> Money? {
        let expenses = ((travel.expenseArray?.allObjects as? [Expense]) ?? [])
            .filter { $0.exchangeRate > 0 }
            .sorted { ($0.payDate ?? .distantPast) > ($1.payDate ?? .distantPast) }

        guard let latest = expenses.first else { return nil }
        // 통화와 나라는 마지막에 적은 것을 따른다 — 지금 있는 곳이 그곳이다.
        // 환율만은 그 여행이 그 통화로 처음 쓴 값을 이어 쓴다. 앱에서 적는
        // 것과 위젯으로 담는 것이 같은 환율이어야 한 여행의 셈이 맞는다.
        let anchored = TravelExchangeRate.anchoredRate(for: travel, currency: latest.currency)
        return Money(currency: latest.currency,
                     exchangeRate: anchored ?? latest.exchangeRate,
                     country: latest.country)
    }

    // MARK: - 담길 여행

    /// 여행 중이면 그 여행, 아니면 기본함.
    ///
    /// 앱 쪽 `MwalletBridge.destination` 과 같은 규칙이다. 여기서 다시 쓰는
    /// 것은 그쪽이 앱 타깃 전용 확장(`isUserCreated`·`fetchDefault`)에 기대고
    /// 있어 위젯에서 컴파일되지 않기 때문이다. 규칙이 갈라지지 않도록
    /// 앱 쪽도 이 함수를 쓰게 바꿨다.
    static func destination(in context: NSManagedObjectContext, now: Date = Date()) -> Travel? {
        ongoingTravel(in: context, now: now) ?? defaultTravel(in: context)
    }

    private static func ongoingTravel(in context: NSManagedObjectContext, now: Date) -> Travel? {
        let request = Travel.fetchRequest()
        request.predicate = NSPredicate(
            format: "isDefault == NO AND startDate <= %@ AND endDate >= %@",
            now as NSDate, now as NSDate
        )
        // 기간이 겹치면 늦게 시작한 것이 지금 있는 곳이다.
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private static func defaultTravel(in context: NSManagedObjectContext) -> Travel? {
        let request = Travel.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    // MARK: - 장부 열기

    /// 위젯에서 쓸 컨텍스트.
    ///
    /// CloudKit 미러링은 켜지 않는다. 위젯은 메모리가 빠듯하고, 어차피 앱이
    /// 다음에 열릴 때 저장 이력(persistent history)을 보고 올려 준다.
    /// 그래서 이력 추적만은 반드시 켜 둔다 — 끄고 쓰면 앱이 이 기록을
    /// 못 보고 지나친다.
    static func openContext() -> NSManagedObjectContext? {
        guard let url = StoreLocation.shared() else {
            quickLog.error("App Group 장부를 열지 못했습니다")
            return nil
        }

        let container = NSPersistentContainer(name: "Mwallet")
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [description]

        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure {
            quickLog.error("장부를 열지 못했습니다: \(failure.localizedDescription, privacy: .public)")
            return nil
        }

        let context = container.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }
}
