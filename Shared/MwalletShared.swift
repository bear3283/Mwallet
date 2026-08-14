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
    private static let destinationKey = "pending.destination"

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

    // MARK: 담길 곳의 이름 (앱 → 위젯)

    /// 위젯에서 담은 지출이 어느 여행으로 갈지, 그 이름.
    ///
    /// 위젯이 스스로 정하지 않는다. 여행 중인지 판단하는 규칙이 앱과 위젯
    /// 두 곳에 생기면 서로 다른 답을 낼 수 있고, 그러면 위젯에 적힌 곳과
    /// 실제로 담기는 곳이 달라진다. 앱이 정하고 위젯은 받아 적는다.
    static func writeDestinationName(_ name: String?) {
        guard let name else { return store?.removeObject(forKey: destinationKey) ?? () }
        store?.set(name, forKey: destinationKey)
    }

    static var destinationName: String? { store?.string(forKey: destinationKey) }

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

// MARK: - 원화 표시 포맷 (위젯 표시용, 앱 ReceiptFormat 과 별개의 가벼운 버전)

enum MwalletSharedFormat {
    static func krw(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(number)원"
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
