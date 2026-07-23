//
//  Receipt+Extension.swift
//  Mwallet
//
//  Receipt 의 도메인 규칙을 모아 둔다.
//  Core Data 속성은 CloudKit 제약 때문에 전부 optional 이므로,
//  화면과 통계는 원시 속성 대신 이 확장의 프로퍼티를 통해 값을 읽는다.
//

import Foundation

// MARK: - 카테고리

enum ReceiptCategory {
    // 기본 제공 목록. 사용자가 직접 입력한 값도 category 에 그대로 저장된다.
    static let presets = ["식비", "숙박비", "교통비", "사역비", "물품비", "기타"]
    static let fallback = "기타"

    // 입력값 정리. 앞뒤 공백을 제거하고 비어 있으면 기본값으로 되돌린다.
    // 직접 입력을 허용하면 " 식비" 와 "식비" 가 다른 항목으로 집계되기 때문이다.
    static func normalized(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}

// MARK: - 통화

enum ReceiptCurrency {
    static let presets = ["KRW", "USD", "EUR", "JPY", "PHP", "THB", "VND", "IDR"]
    static let base = "KRW"
}

// MARK: - 값 읽기

extension Receipt {

    // 환율을 얻지 못한 채 저장된 상태를 나타내는 값.
    // Expense 와 동일한 규약을 쓴다. 0 은 기본값이므로 함께 미확보로 취급한다.
    static let unknownExchangeRate: Double = 0

    var categoryName: String { ReceiptCategory.normalized(category) }
    var currencyCode: String { (currency?.isEmpty == false ? currency : nil) ?? ReceiptCurrency.base }
    var merchantName: String { (merchant?.isEmpty == false ? merchant : nil) ?? "상호 미입력" }
    var missionTitle: String { (missionName?.isEmpty == false ? missionName : nil) ?? "미분류" }
    var memoText: String { memo ?? "" }
    var paidDate: Date { date ?? createdAt ?? .distantPast }

    // 기록 당시의 시간대. 없으면 현재 기기 시간대로 대체한다.
    // date 는 절대 시각으로 저장하고 표시할 때만 시간대를 적용한다.
    var recordedTimeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    // 유효한 환율만 돌려준다. 미확보이거나 음수면 nil.
    var validExchangeRate: Double? {
        exchangeRate > 0 ? exchangeRate : nil
    }

    // 원화 환산 금액. 원화 영수증은 환율 없이도 금액 그대로 쓴다.
    // 환율이 필요한데 없으면 nil 을 돌려주어, 호출부가 합계에서 제외하거나
    // "-" 로 표시하도록 한다. 임의의 값을 곱해 금액을 지어내지 않는다.
    var amountInKRW: Double? {
        guard amount >= 0 else { return nil }
        if currencyCode == ReceiptCurrency.base { return amount }
        guard let rate = validExchangeRate else { return nil }
        return amount * rate
    }

    // 영수증 사진이 아직 없는 기록인지.
    // 현장에서 금액만 먼저 남기고 사진은 나중에 붙이는 흐름을 위해 따로 센다.
    var needsPhoto: Bool {
        (imageData?.isEmpty ?? true)
    }

    // 원화 환산이 불가능한 기록인지. 목록에서 경고를 띄우는 데 쓴다.
    var needsExchangeRate: Bool {
        currencyCode != ReceiptCurrency.base && validExchangeRate == nil
    }
}

// MARK: - 표시용 포맷

extension Receipt {

    func formattedDate(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = recordedTimeZone
        formatter.dateStyle = style
        formatter.timeStyle = .short
        return formatter.string(from: paidDate)
    }

    // 기록 당시 현지 시각만 표기. 기기 시간대와 다르면 약어를 덧붙여
    // "22:15 PHT" 처럼 어느 지역 시각인지 알 수 있게 한다.
    var formattedTimeOnly: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = recordedTimeZone
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: paidDate)

        guard recordedTimeZone.identifier != TimeZone.current.identifier,
              let abbreviation = recordedTimeZone.abbreviation(for: paidDate) else {
            return time
        }
        return "\(time) \(abbreviation)"
    }

    // 현지 통화 기준 금액 표기. 예: "$ 24.50"
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(currencyCode) \(number)"
    }

    // 원화 환산 표기. 환산할 수 없으면 "-" 를 돌려준다.
    var formattedAmountInKRW: String {
        guard let value = amountInKRW else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + "원"
    }
}
