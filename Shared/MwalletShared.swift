//
//  MwalletShared.swift
//  Mwallet  +  MwalletWidget  (두 타깃에 모두 추가)
//
//  앱과 위젯이 App Group 을 통해 주고받는 계약.
//  - 앱 → 위젯: 예결산 스냅샷(읽기 전용 표시용)
//  - 위젯 → 앱: 대기 지출 큐(앱이 다음에 열릴 때 Core Data 로 반영)
//
//  순수 Foundation 이라 Core Data·앱 타입에 의존하지 않는다. 위젯 타깃에서도
//  그대로 컴파일된다.
//
//  ⚠️ App Group ID(아래 appGroupID)는 Xcode 의 Signing & Capabilities 에서
//     앱·위젯 두 타깃에 똑같이 등록해야 한다. 문자열이 다르면 데이터가 오가지 않는다.
//

import Foundation

// MARK: - App Group 공유 저장소

enum MwalletShared {

    // 앱·위젯 두 타깃의 App Groups capability 에 동일하게 넣을 값.
    static let appGroupID = "group.com.Mwallet.app"

    private static let snapshotKey = "budget.snapshot"
    private static let queueKey = "pending.expenses"
    // 예전에는 이름 문자열 하나였다. 통화·프리셋까지 담게 되면서 열쇠를 새로
    // 냈다 — 같은 열쇠에 다른 모양을 적으면 업데이트되는 사이 위젯이 못 읽는다.
    private static let destinationKey = "pending.destination.v2"
    private static let legacyDestinationKey = "pending.destination"
    private static let lastLoggedKey = "last.logged"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: 예결산 스냅샷 (앱 → 위젯)

    static func writeSnapshot(_ snapshot: BudgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store?.set(data, forKey: snapshotKey)
    }

    static func readSnapshot() -> BudgetSnapshot? {
        guard let data = store?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(BudgetSnapshot.self, from: data)
    }

    // MARK: 담길 곳 (앱 → 위젯)

    /// 위젯에서 담은 지출이 어디로, 어떤 돈으로 갈지.
    ///
    /// 위젯이 스스로 정하지 않는다. 여행 중인지 판단하는 규칙이 앱과 위젯
    /// 두 곳에 생기면 서로 다른 답을 낼 수 있고, 그러면 위젯에 적힌 곳과
    /// 실제로 담기는 곳이 달라진다. 앱이 정하고 위젯은 받아 적는다.
    static func writeDestination(_ destination: QuickLogDestination?) {
        guard let destination else {
            store?.removeObject(forKey: destinationKey)
            store?.removeObject(forKey: legacyDestinationKey)
            return
        }
        if let data = try? JSONEncoder().encode(destination) {
            store?.set(data, forKey: destinationKey)
        }
        // 아직 예전 위젯이 돌고 있을 수 있다(앱만 먼저 업데이트된 순간).
        // 이름 하나만 읽던 그 위젯이 빈칸을 보이지 않도록 함께 적어 둔다.
        store?.set(destination.travelName, forKey: legacyDestinationKey)
    }

    static var destination: QuickLogDestination? {
        guard let data = store?.data(forKey: destinationKey),
              let decoded = try? JSONDecoder().decode(QuickLogDestination.self, from: data) else {
            // 앱이 아직 예전 판이면 이름만 있다. 통화를 모르므로 프리셋은 비운다 —
            // 모르는 채로 금액을 적으면 그것이 바로 고치려던 잘못이다.
            guard let name = store?.string(forKey: legacyDestinationKey) else { return nil }
            return QuickLogDestination(travelName: name, currencyCode: "", presets: [])
        }
        return decoded
    }

    // MARK: 대기 지출 큐 (위젯 → 앱)

    static func enqueue(_ expense: PendingExpense) {
        var queue = readQueue()
        queue.append(expense)
        writeQueue(queue)
    }

    static func readQueue() -> [PendingExpense] {
        guard let data = store?.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([PendingExpense].self, from: data)) ?? []
    }

    // 큐를 비우면서 반환한다. 앱이 Core Data 로 옮길 때 쓴다.
    static func drainQueue() -> [PendingExpense] {
        let queue = readQueue()
        store?.removeObject(forKey: queueKey)
        return queue
    }

    /// 방금 담은 것을 도로 뺀다.
    ///
    /// 홈 화면의 위젯은 한 번 누르면 그대로 담기는 자리라 잘못 누르기 쉽다.
    /// 앱을 열어 지우게 하면 '빠른 기록' 이라는 말이 무색해진다.
    ///
    /// 앱이 이미 가져간 뒤에는 뺄 것이 없다. 그때는 nil 을 돌려주고, 화면은
    /// 되돌리기 단추를 감춘다.
    @discardableResult
    static func undoLast() -> PendingExpense? {
        var queue = readQueue()
        guard let last = queue.popLast() else { return nil }
        writeQueue(queue)
        return last
    }

    /// 큐에 아직 남아 있는 마지막 것. 위젯이 '방금 담음' 을 보여 줄 때 쓴다.
    static var lastPending: PendingExpense? { readQueue().last }

    private static func writeQueue(_ queue: [PendingExpense]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        store?.set(data, forKey: queueKey)
    }

    // MARK: - 방금 담은 것

    /// 방금 담은 하나. 큐에 남았든 장부에 적혔든 여기에 적어 둔다.
    ///
    /// 예전에는 위젯이 큐의 마지막 것을 '방금 담음' 으로 보여 줬다. 이제
    /// 위젯이 장부에 곧장 적으므로 큐가 대개 비어 있고, 그대로 두면 담아도
    /// 아무 표시가 안 남는다 — 눌렀는지 아닌지 알 수 없는 자리가 된다.
    static func writeLastLogged(_ record: LoggedRecord?) {
        guard let record else {
            store?.removeObject(forKey: lastLoggedKey)
            return
        }
        guard let data = try? JSONEncoder().encode(record) else { return }
        store?.set(data, forKey: lastLoggedKey)
    }

    static var lastLogged: LoggedRecord? {
        guard let data = store?.data(forKey: lastLoggedKey) else { return nil }
        return try? JSONDecoder().decode(LoggedRecord.self, from: data)
    }
}

// MARK: - 방금 담은 것

/// 되돌리기가 무엇을 되돌려야 하는지까지 담는다.
///
/// 큐에 남은 것이면 큐에서 빼면 되지만, 장부에 적힌 것은 그 지출을 찾아
/// 지워야 한다. 어느 쪽인지 나중에 짐작하려 들면 틀린다 — 담을 때 적어 둔다.
struct LoggedRecord: Codable, Equatable {
    var info: String
    var amount: Double
    /// 장부에 적힌 경우 그 지출의 주소. 큐에 남았으면 nil.
    var expenseURI: String?

    var isSaved: Bool { expenseURI != nil }
}

// MARK: - 스냅샷 모델

struct BudgetSnapshot: Codable {

    var travelName: String
    var totalPlanned: Double
    var totalSpent: Double
    var pendingReceiptCount: Int      // 영수증 사진이 아직 없는 지출 수
    var categories: [CategorySlice]   // 집행 상위 카테고리 (결산 위젯 중형용)
    var updatedAt: Date

    struct CategorySlice: Codable {
        var name: String
        var spent: Double
    }

    var ratio: Double { totalPlanned > 0 ? totalSpent / totalPlanned : 0 }
    var remaining: Double { totalPlanned - totalSpent }
    var isOverspent: Bool { totalSpent > totalPlanned }
    var hasBudget: Bool { totalPlanned > 0 }
}

// MARK: - 대기 지출 모델

struct PendingExpense: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var categoryIndex: Int        // ExpenseInfoCategory.rawValue 와 동일
    var paymentMethodIndex: Int   // PaymentMethod.rawValue 와 동일
    var info: String
    var createdAt: Date

    init(amount: Double, categoryIndex: Int, paymentMethodIndex: Int, info: String) {
        self.id = UUID()
        self.amount = amount
        self.categoryIndex = categoryIndex
        self.paymentMethodIndex = paymentMethodIndex
        self.info = info
        self.createdAt = Date()
    }
}

// MARK: - 담길 곳

/// 위젯이 담으면 어디에, 어떤 돈으로 들어가는지.
///
/// 예전에는 여행 이름만 넘겼다. 그런데 위젯이 담은 지출은 그 여행이 마지막으로
/// 쓰던 통화로 적힌다(QuickExpenseStore.inheritedMoney). 이름만 아는 위젯은
/// 버튼에 원화를 적어 두고 바트를 저장하고 있었다 — 방콕 여행에서 '₩4,500'
/// 이라고 적힌 단추를 누르면 장부에 ฿4,500(17만 원)이 들어갔다.
///
/// 버튼에 적는 돈과 저장되는 돈은 같아야 한다. 그래서 통화까지 함께 넘긴다.
struct QuickLogDestination: Codable, Equatable {

    var travelName: String
    /// 담기면 이 돈으로 적힌다. 버튼의 금액도 이 돈으로 적어야 한다.
    var currencyCode: String
    /// 이 여행에서 실제로 적어 온 것에서 뽑은 프리셋.
    ///
    /// 비어 있을 수 있다 — 아직 한 건도 없는 여행이다. 그때는 통화도 알 수
    /// 없어 위젯이 담아도 큐로 물러나므로, 프리셋 대신 안내를 띄운다.
    var presets: [QuickPresetSpec]
}

/// 프리셋 한 칸.
struct QuickPresetSpec: Codable, Equatable, Identifiable {
    var emoji: String
    var label: String
    var amount: Double
    var categoryIndex: Int   // ExpenseInfoCategory.rawValue

    var id: String { "\(categoryIndex)-\(label)-\(amount)" }
}

// MARK: - 표시 포맷 (위젯용, 앱 ReceiptFormat 과 별개의 가벼운 버전)

enum MwalletSharedFormat {
    static func krw(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? "0"
        return String(localized: "\(number)원")
    }

    /// 그 여행의 돈으로 적는다.
    ///
    /// 원화는 예전 그대로 둔다 — 한국어에서 '4,500원' 이라고 읽어 온 자리라
    /// 통화 포맷터로 넘기면 '₩4,500' 으로 바뀐다. 나머지 통화는 iOS 에 맡긴다.
    /// 기호가 앞에 붙는지 뒤에 붙는지는 언어마다 다르고, 소수 자릿수도 통화마다
    /// 다르다(엔·원은 0, 달러는 2).
    static func money(_ value: Double, currencyCode: String) -> String {
        guard currencyCode != "KRW" else { return krw(value) }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        // 위젯은 자리가 좁다. 딱 떨어지는 금액에 '.00' 을 달지 않는다.
        if value == value.rounded() { formatter.maximumFractionDigits = 0 }
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(Int(value))"
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
