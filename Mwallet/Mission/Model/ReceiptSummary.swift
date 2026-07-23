//
//  ReceiptSummary.swift
//  Mwallet
//
//  영수증 목록의 필터링과 집계를 담당하는 순수 타입.
//  목록 화면뿐 아니라 통계 차트와 CSV 내보내기도 같은 결과를 쓰도록
//  View 바깥에 두었다. 화면마다 합계를 다시 계산하면 값이 갈라진다.
//

import Foundation

// MARK: - 필터

struct ReceiptFilter {
    // nil 이면 전체 사역
    var missionName: String?
    var searchText: String = ""

    func matches(_ receipt: Receipt) -> Bool {
        if let missionName, receipt.missionTitle != missionName { return false }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }

        let haystack = [
            receipt.merchantName,
            receipt.memoText,
            receipt.categoryName,
            receipt.missionTitle
        ]
        return haystack.contains { $0.localizedCaseInsensitiveContains(keyword) }
    }
}

// MARK: - 집계 결과

struct CategoryTotal: Identifiable {
    let category: String
    let amountInKRW: Double
    let count: Int

    var id: String { category }
}

struct CurrencyTotal: Identifiable {
    let currency: String
    let amount: Double
    let count: Int

    var id: String { currency }
}

struct ReceiptSummary {

    let totalInKRW: Double
    let convertibleCount: Int
    // 환율을 얻지 못해 원화 합계에 넣지 못한 건수.
    // 합계를 지어내는 대신 몇 건이 빠졌는지 사용자에게 알린다.
    let unconvertibleCount: Int
    let byCategory: [CategoryTotal]
    let byCurrency: [CurrencyTotal]

    var totalCount: Int { convertibleCount + unconvertibleCount }
    var hasUnconvertible: Bool { unconvertibleCount > 0 }

    init(receipts: [Receipt]) {
        var total: Double = 0
        var convertible = 0
        var unconvertible = 0
        var categoryAmounts: [String: (amount: Double, count: Int)] = [:]
        var currencyAmounts: [String: (amount: Double, count: Int)] = [:]

        for receipt in receipts {
            let currency = receipt.currencyCode
            let currencyEntry = currencyAmounts[currency] ?? (0, 0)
            currencyAmounts[currency] = (currencyEntry.amount + receipt.amount, currencyEntry.count + 1)

            guard let krw = receipt.amountInKRW else {
                unconvertible += 1
                continue
            }
            convertible += 1
            total += krw

            let category = receipt.categoryName
            let categoryEntry = categoryAmounts[category] ?? (0, 0)
            categoryAmounts[category] = (categoryEntry.amount + krw, categoryEntry.count + 1)
        }

        self.totalInKRW = total
        self.convertibleCount = convertible
        self.unconvertibleCount = unconvertible
        self.byCategory = categoryAmounts
            .map { CategoryTotal(category: $0.key, amountInKRW: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amountInKRW > $1.amountInKRW }
        self.byCurrency = currencyAmounts
            .map { CurrencyTotal(currency: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.currency < $1.currency }
    }
}

// MARK: - 일자별 묶음

struct ReceiptDaySection: Identifiable {
    let day: Date
    let receipts: [Receipt]

    var id: Date { day }

    var dayTotal: ReceiptSummary { ReceiptSummary(receipts: receipts) }
}

enum ReceiptGrouping {

    // 기기의 현재 달력을 기준으로 날짜별로 묶는다.
    // 영수증마다 기록 당시 시간대가 다를 수 있지만, 그 기준으로 묶으면
    // 절대 시각 정렬과 어긋나 구간이 끊길 수 있어 목록에서는 기기 기준을 쓴다.
    // 각 행에는 기록 당시의 현지 시각을 그대로 보여준다.
    static func byDay(_ receipts: [Receipt], calendar: Calendar = .current) -> [ReceiptDaySection] {
        let grouped = Dictionary(grouping: receipts) { receipt in
            calendar.startOfDay(for: receipt.paidDate)
        }
        return grouped
            .map { ReceiptDaySection(day: $0.key, receipts: $0.value.sorted { $0.paidDate > $1.paidDate }) }
            .sorted { $0.day > $1.day }
    }

    static func missionNames(in receipts: [Receipt]) -> [String] {
        Array(Set(receipts.map { $0.missionTitle })).sorted()
    }
}

// MARK: - 표시용 포맷

enum ReceiptFormat {

    static func krw(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + "원"
    }

    static func dayTitle(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "오늘" }
        if calendar.isDateInYesterday(date) { return "어제" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.setLocalizedDateFormatFromTemplate("MMMd(E)")
        return formatter.string(from: date)
    }
}
