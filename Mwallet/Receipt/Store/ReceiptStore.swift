//
//  ReceiptStore.swift
//  Mwallet
//
//  Receipt 의 쓰기 경로를 한곳에 모은다.
//  목록 조회는 View 에서 @FetchRequest 로 하되, 생성·수정·삭제와
//  저장 시점의 규칙(환율 스냅샷, 시간대 기록)은 여기를 거치게 한다.
//

import CoreData
import Foundation

// 화면에서 입력받은 값을 담는 중간 타입.
// NSManagedObject 를 화면 상태로 직접 쓰면 취소 시 롤백이 번거로워진다.
struct ReceiptDraft {
    var missionName: String = ""
    var date: Date = Date()
    var merchant: String = ""
    var amountText: String = ""
    var currency: String = ReceiptCurrency.base
    var category: String = ReceiptCategory.presets.first ?? ReceiptCategory.fallback
    var memo: String = ""
    var imageData: Data?

    init() { }

    // 편집 화면이 기존 값을 채워 열 때 쓴다.
    init(from receipt: Receipt) {
        self.missionName = receipt.missionName ?? ""
        self.date = receipt.paidDate
        self.merchant = receipt.merchant ?? ""
        self.amountText = Self.editableAmountText(receipt.amount)
        self.currency = receipt.currencyCode
        self.category = receipt.categoryName
        self.memo = receipt.memoText
        self.imageData = receipt.imageData
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
        guard value != 0 else { return "" }
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
    func create(from draft: ReceiptDraft) throws -> Receipt {
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.createdAt = Date()
        applyFields(draft, to: receipt)

        // 기록 시점의 상태를 스냅샷으로 남긴다.
        receipt.timeZoneIdentifier = TimeZone.current.identifier
        receipt.exchangeRate = snapshotExchangeRate(for: draft.currency)

        try context.save()
        return receipt
    }

    // MARK: - 수정 / 삭제

    func update(_ receipt: Receipt, with draft: ReceiptDraft) throws {
        let previousCurrency = receipt.currencyCode
        let previousRate = receipt.validExchangeRate

        applyFields(draft, to: receipt)

        // 기록 당시의 시간대는 편집으로 바뀌지 않는다. 그대로 둔다.
        // 환율도 마찬가지로, 통화가 그대로이고 이미 유효한 값이 있으면 보존한다.
        // 오타를 고쳤다고 해서 그날의 환율이 오늘 환율로 바뀌면 안 된다.
        if draft.currency != previousCurrency || previousRate == nil {
            receipt.exchangeRate = snapshotExchangeRate(for: draft.currency)
        }

        try context.save()
    }

    // 목록에서 사진만 바로 붙인다. 편집 폼을 열지 않으므로
    // 기록 시점 환율과 시간대 같은 스냅샷 값은 건드리지 않는다.
    func attachPhoto(_ data: Data, to receipt: Receipt) throws {
        receipt.imageData = data
        try context.save()
    }

    // 오프라인에서 기록해 환율을 못 받은 건에 현재 환율을 채운다.
    // 그날의 환율이 아니라 지금 환율이므로, 화면에서 그 사실을 알리고 쓴다.
    func applyCurrentExchangeRate(to receipt: Receipt) throws {
        receipt.exchangeRate = snapshotExchangeRate(for: receipt.currencyCode)
        try context.save()
    }

    func delete(_ receipt: Receipt) throws {
        context.delete(receipt)
        try context.save()
    }

    // MARK: - 조회 보조

    // 이미 입력한 사역 이름 목록. 새 영수증을 추가할 때 자동완성으로 제안한다.
    func existingMissionNames() -> [String] {
        let request = Receipt.fetchRequest()
        request.propertiesToFetch = ["missionName"]
        do {
            let names = try context.fetch(request).compactMap { $0.missionName }
            return Array(Set(names.filter { !$0.isEmpty })).sorted()
        } catch {
            print("ReceiptStore | 사역 이름 조회 실패: \(error.localizedDescription)")
            return []
        }
    }

    // 사용자가 직접 입력해 만든 카테고리까지 합쳐 돌려준다.
    func availableCategories() -> [String] {
        let request = Receipt.fetchRequest()
        request.propertiesToFetch = ["category"]
        let saved: [String]
        do {
            saved = try context.fetch(request).map { $0.categoryName }
        } catch {
            print("ReceiptStore | 카테고리 조회 실패: \(error.localizedDescription)")
            saved = []
        }
        let extras = Set(saved).subtracting(ReceiptCategory.presets).sorted()
        return ReceiptCategory.presets + extras
    }

    // MARK: - 내부

    // 사용자가 폼에서 입력한 필드만 옮긴다.
    // 시간대와 환율은 기록 시점 스냅샷이라 create/update 에서 따로 다룬다.
    private func applyFields(_ draft: ReceiptDraft, to receipt: Receipt) {
        receipt.missionName = draft.missionName.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.date = draft.date
        receipt.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.amount = draft.amount ?? 0
        receipt.currency = draft.currency
        receipt.category = ReceiptCategory.normalized(draft.category)
        receipt.memo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.imageData = draft.imageData
    }

    // 원화면 환산이 필요 없으므로 1 을 쓴다.
    // 조회에 실패하면 unknownExchangeRate 를 넣고, 화면과 통계는
    // amountInKRW 가 nil 임을 보고 합계에서 제외하거나 "-" 로 표시한다.
    private func snapshotExchangeRate(for currency: String) -> Double {
        guard currency != ReceiptCurrency.base else { return 1 }
        return exchangeRateHandler.getExchangeRateFromKRW(currencyCode: currency)
            ?? Receipt.unknownExchangeRate
    }
}
