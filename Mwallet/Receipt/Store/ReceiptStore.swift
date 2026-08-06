//
//  ReceiptStore.swift
//  Mwallet
//
//  영수증 화면의 쓰기 경로.
//  기록 탭이 만드는 Expense 를 그대로 다룬다. 별도 Receipt 엔티티는 두지 않는다.
//  목록 조회는 View 에서 @FetchRequest 로 하되, 생성·수정·삭제와
//  저장 시점의 규칙(환율 스냅샷, 시간대 기록)은 여기를 거치게 한다.
//

import CoreData
import CoreLocation
import Foundation
import OSLog

// 화면에서 입력받은 값을 담는 중간 타입.
// NSManagedObject 를 화면 상태로 직접 쓰면 취소 시 롤백이 번거로워진다.
struct ReceiptDraft {
    var travel: Travel?
    var date: Date = Date()
    var merchant: String = ""
    var amountText: String = ""
    var currency: String = ExpenseCode.baseCurrency
    var category: String = ExpenseInfoCategory.food.description
    var memo: String = ""
    var imageData: Data?
    var coordinate: CLLocationCoordinate2D?
    var placeName: String?

    init() { }

    // 편집 화면이 기존 값을 채워 열 때 쓴다.
    init(from expense: Expense) {
        self.travel = expense.travel
        self.date = expense.paidDate
        self.merchant = expense.info ?? ""
        self.amountText = Self.editableAmountText(expense.payAmount)
        self.currency = expense.currencyCode
        self.category = expense.categoryName
        self.memo = expense.memoText
        self.imageData = expense.imageData
        self.coordinate = expense.coordinate
        self.placeName = expense.location
    }

    var amount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    var isValid: Bool {
        amount != nil && amount != 0
    }

    // 24.5 는 "24.5", 3200 은 "3200" 으로 보여 준다.
    // 소수점 없는 금액에 ".0" 이 붙으면 편집할 때 거슬린다.
    private static func editableAmountText(_ value: Double) -> String {
        guard value > 0 else { return "" }
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}

final class ReceiptStore {

    private let context: NSManagedObjectContext
    private let exchangeRateHandler: ExchangeRateHandler

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        exchangeRateHandler: ExchangeRateHandler = .shared
    ) {
        self.context = context
        self.exchangeRateHandler = exchangeRateHandler
    }

    // MARK: - 생성

    @discardableResult
    func create(from draft: ReceiptDraft) throws -> Expense {
        let expense = Expense(context: context)
        applyFields(draft, to: expense)

        // 기록 시점의 상태를 스냅샷으로 남긴다.
        expense.timeZoneIdentifier = TimeZone.current.identifier
        expense.exchangeRate = snapshotExchangeRate(for: draft.currency)

        try context.save()
        return expense
    }

    // MARK: - 수정 / 삭제

    func update(_ expense: Expense, with draft: ReceiptDraft) throws {
        let previousCurrency = expense.currencyCode
        let previousRate = expense.validExchangeRate

        applyFields(draft, to: expense)

        // 기록 당시의 시간대는 편집으로 바뀌지 않는다. 그대로 둔다.
        // 환율도 마찬가지로, 통화가 그대로이고 이미 유효한 값이 있으면 보존한다.
        // 오타를 고쳤다고 해서 그날의 환율이 오늘 환율로 바뀌면 안 된다.
        if draft.currency != previousCurrency || previousRate == nil {
            expense.exchangeRate = snapshotExchangeRate(for: draft.currency)
        }

        try context.save()
    }

    func delete(_ expense: Expense) throws {
        context.delete(expense)
        try context.save()
    }

    // 목록에서 사진만 바로 붙인다. 편집 폼을 열지 않으므로
    // 기록 시점 환율과 시간대 같은 스냅샷 값은 건드리지 않는다.
    func attachPhoto(_ data: Data, to expense: Expense) throws {
        expense.imageData = data
        try context.save()
    }

    // 오프라인에서 기록해 환율을 못 받은 건에 현재 환율을 채운다.
    // 그날의 환율이 아니라 지금 환율이므로, 화면에서 그 사실을 알리고 쓴다.
    func applyCurrentExchangeRate(to expense: Expense) throws {
        expense.exchangeRate = snapshotExchangeRate(for: expense.currencyCode)
        try context.save()
    }

    // MARK: - 조회 보조

    // 여행 목록. 영수증을 어느 여행에 넣을지 고르는 데 쓴다.
    // '임시 기록' 여행은 사용자가 만든 일정이 아니라 목록에서 뺀다.
    func availableTravels() -> [Travel] {
        let request = Travel.fetchRequest()
        do {
            // 시작일 내림차순이 아니라 '여행 중 → 지난 → 다가오는' 순서로 준다.
            // 탭을 열었을 때 지금 진행 중인 여행이 먼저 보여야 한다.
            return try context.fetch(request)
                .filter { $0.isUserCreated }
                .sorted(by: travelModalSortRule)
        } catch {
            Logger.data.error("영수증 화면의 여행 조회 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // 카테고리는 Int64 코드라 자유 입력을 받지 않는다.
    // 기록 탭과 같은 목록을 쓰므로 두 화면의 분류가 어긋나지 않는다.
    func availableCategories() -> [String] {
        ExpenseInfoCategory.selectable.map { $0.description }
    }

    // MARK: - 내부

    // 사용자가 폼에서 입력한 필드만 옮긴다.
    // 시간대와 환율은 기록 시점 스냅샷이라 create/update 에서 따로 다룬다.
    private func applyFields(_ draft: ReceiptDraft, to expense: Expense) {
        expense.travel = draft.travel
        expense.payDate = draft.date
        expense.info = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.payAmount = draft.amount ?? 0
        expense.currency = ExpenseCode.currencyIndex(for: draft.currency)
        expense.category = ExpenseCode.categoryIndex(for: draft.category)
        expense.memo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.imageData = draft.imageData
        expense.setCoordinate(draft.coordinate)
        expense.location = draft.placeName
    }

    // 원화면 환산이 필요 없으므로 1 을 쓴다.
    // 조회에 실패하면 unknownExchangeRate 를 넣고, 화면과 통계는
    // amountInKRW 가 nil 임을 보고 합계에서 제외하거나 "-" 로 표시한다.
    private func snapshotExchangeRate(for currency: String) -> Double {
        guard currency != ExpenseCode.baseCurrency else { return 1 }
        return exchangeRateHandler.getExchangeRateFromKRW(currencyCode: currency)
            ?? Expense.unknownExchangeRate
    }
}
