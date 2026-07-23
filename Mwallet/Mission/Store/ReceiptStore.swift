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

    var amount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    var isValid: Bool {
        amount != nil && amount != 0
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
        apply(draft, to: receipt)
        try context.save()
        return receipt
    }

    // MARK: - 수정 / 삭제

    func update(_ receipt: Receipt, with draft: ReceiptDraft) throws {
        apply(draft, to: receipt)
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

    private func apply(_ draft: ReceiptDraft, to receipt: Receipt) {
        receipt.missionName = draft.missionName.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.date = draft.date
        receipt.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.amount = draft.amount ?? 0
        receipt.currency = draft.currency
        receipt.category = ReceiptCategory.normalized(draft.category)
        receipt.memo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.imageData = draft.imageData

        // 기록 당시의 시간대를 남긴다. date 자체는 절대 시각으로 두고
        // 표시할 때만 이 값을 적용해 현지 시각을 복원한다.
        receipt.timeZoneIdentifier = TimeZone.current.identifier

        // 환율은 기록 시점 값을 스냅샷으로 저장한다.
        // 나중에 조회하면 그날의 환율을 알 수 없어 정산 금액을 복원할 수 없다.
        receipt.exchangeRate = snapshotExchangeRate(for: draft.currency)
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
