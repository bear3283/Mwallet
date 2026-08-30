//
//  ReceiptSummary.swift
//  Mwallet
//
//  영수증 목록의 필터링과 집계를 담당하는 순수 타입.
//  목록 화면뿐 아니라 통계 차트와 CSV 내보내기도 같은 결과를 쓰도록
//  View 바깥에 두었다. 화면마다 합계를 다시 계산하면 값이 갈라진다.
//

import Foundation

// MARK: - 기간

/// 언제 쓴 것만 볼지.
///
/// 여행으로 좁히는 것과는 결이 다르다. 여행은 '어느 일정' 이고 기간은
/// '그중 언제' 라, 둘을 함께 걸 수 있다.
///
/// 기준은 기기의 달력이다. 지출마다 기록된 시간대(timeZoneIdentifier)로
/// 따지지 않는 것은, 보는 사람이 지금 있는 곳에서 '오늘' 을 묻기 때문이다.
/// 방콕에서 쓴 것을 서울에서 볼 때 서울의 오늘로 세는 편이 덜 놀랍다.
enum ReceiptPeriod: String, CaseIterable, Identifiable {
    case all
    case today
    case lastWeek
    case thisMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "전체 기간")
        case .today: return String(localized: "오늘")
        case .lastWeek: return String(localized: "최근 7일")
        case .thisMonth: return String(localized: "이번 달")
        }
    }

    /// 이 기간의 시작. nil 이면 끝이 없다(전체).
    func start(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .all:
            return nil
        case .today:
            return calendar.startOfDay(for: now)
        case .lastWeek:
            // 오늘을 포함해 7일. 6일 전의 0시부터 센다.
            let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            return calendar.startOfDay(for: sixDaysAgo)
        case .thisMonth:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        }
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let start = start(from: now, calendar: calendar) else { return true }
        // 끝은 묶지 않는다. 앞날에 적힌 지출(시간대 차이로 생길 수 있다)을
        // 걸러 내면 '왜 안 보이지' 가 된다.
        return date >= start
    }
}

// MARK: - 필터

struct ReceiptFilter {
    // nil 이면 전체 사역
    var missionName: String?
    var searchText: String = ""
    // 영수증 사진이 없는 것만 모아 보기
    var onlyMissingPhoto = false
    var period: ReceiptPeriod = .all

    /// - Parameter now: '오늘' 의 기준. 테스트에서 못 박기 위해 받는다.
    ///   자정 언저리에 돌 때 결과가 달라지지 않게 한다.
    func matches(_ expense: Expense, now: Date = Date()) -> Bool {
        if onlyMissingPhoto && !expense.needsPhoto { return false }
        if let missionName, expense.missionTitle != missionName { return false }
        if !period.contains(expense.paidDate, now: now) { return false }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }

        let haystack = [
            expense.merchantName,
            expense.memoText,
            expense.categoryName,
            expense.missionTitle
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
    // 영수증 사진이 아직 없는 건수. 증빙 제출 전에 채워야 할 숙제다.
    let missingPhotoCount: Int
    let byCategory: [CategoryTotal]
    let byCurrency: [CurrencyTotal]

    var totalCount: Int { convertibleCount + unconvertibleCount }
    var hasUnconvertible: Bool { unconvertibleCount > 0 }
    var hasMissingPhoto: Bool { missingPhotoCount > 0 }

    init(expenses: [Expense]) {
        var total: Double = 0
        var convertible = 0
        var unconvertible = 0
        var missingPhoto = 0
        var categoryAmounts: [String: (amount: Double, count: Int)] = [:]
        var currencyAmounts: [String: (amount: Double, count: Int)] = [:]

        for expense in expenses {
            if expense.needsPhoto { missingPhoto += 1 }
            let currency = expense.currencyCode
            let currencyEntry = currencyAmounts[currency] ?? (0, 0)
            currencyAmounts[currency] = (currencyEntry.amount + expense.payAmount, currencyEntry.count + 1)

            guard let krw = expense.amountInKRW else {
                unconvertible += 1
                continue
            }
            convertible += 1
            total += krw

            let category = expense.categoryName
            let categoryEntry = categoryAmounts[category] ?? (0, 0)
            categoryAmounts[category] = (categoryEntry.amount + krw, categoryEntry.count + 1)
        }

        self.totalInKRW = total
        self.convertibleCount = convertible
        self.unconvertibleCount = unconvertible
        self.missingPhotoCount = missingPhoto
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
    let expenses: [Expense]

    var id: Date { day }

    var dayTotal: ReceiptSummary { ReceiptSummary(expenses: expenses) }
}

enum ReceiptGrouping {

    // 기기의 현재 달력을 기준으로 날짜별로 묶는다.
    // 영수증마다 기록 당시 시간대가 다를 수 있지만, 그 기준으로 묶으면
    // 절대 시각 정렬과 어긋나 구간이 끊길 수 있어 목록에서는 기기 기준을 쓴다.
    // 각 행에는 기록 당시의 현지 시각을 그대로 보여준다.
    static func byDay(_ expenses: [Expense], calendar: Calendar = .current) -> [ReceiptDaySection] {
        let grouped = Dictionary(grouping: expenses) { expense in
            calendar.startOfDay(for: expense.paidDate)
        }
        return grouped
            .map { ReceiptDaySection(day: $0.key, expenses: $0.value.sorted { $0.paidDate > $1.paidDate }) }
            .sorted { $0.day > $1.day }
    }

    static func missionNames(in expenses: [Expense]) -> [String] {
        Array(Set(expenses.map { $0.missionTitle })).sorted()
    }
}

// MARK: - 표시용 포맷

enum ReceiptFormat {

    // 원화로 환산할 수 있는 항목이 하나도 없으면 0원 대신 "-" 로 적는다.
    // 0원은 실제로 0원을 쓴 것으로 읽힌다.
    static func krwOrDash(_ summary: ReceiptSummary) -> String {
        summary.convertibleCount == 0 ? "-" : krw(summary.totalInKRW)
    }

    /// 원화 금액. 숫자는 기기 언어의 자릿점으로, 단위는 그 언어가 읽는 방식으로.
    ///
    /// 한국어는 '1,234원' 이지만 '원' 은 다른 언어에서 읽히지 않는다. 단위를
    /// 문자열 표에 맡겨 두면 언어마다 제자리에 붙는다 — 영어 '₩1,234' 처럼
    /// 앞에 오는 언어도 있다.
    static func krw(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? "0"
        return String(localized: "\(number)원")
    }

    // 환율은 소수점을 버리면 안 된다. 24.5 를 24 로 보여 주면
    // 사용자가 환산 금액을 검산했을 때 맞지 않는다.
    static func exchangeRate(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? "0"
        return String(localized: "\(number)원")
    }

    static func dayTitle(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "오늘") }
        if calendar.isDateInYesterday(date) { return String(localized: "어제") }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd(E)")
        return formatter.string(from: date)
    }
}
