//
//  Expense+Extension.swift
//  Mwallet
//

import CoreLocation
import Foundation

extension Expense {

    // 기록 시점에 환율을 얻지 못했음을 나타내는 값.
    // Core Data 의 exchangeRate 가 스칼라 Double 이라 nil 을 담을 수 없어 사용한다.
    // 저장되지 않은 기록의 기본값 0.0 도 같은 의미로 취급한다.
    static let unknownExchangeRate: Double = -1

    // 유효한 환율만 돌려준다. 미확보(-1)거나 기본값(0.0)이면 nil.
    // 이 프로퍼티를 거치지 않고 exchangeRate 를 직접 곱하면
    // 음수 금액이 그대로 화면과 정산 결과에 노출된다.
    var validExchangeRate: Double? {
        exchangeRate > 0 ? exchangeRate : nil
    }

    // 기록 시점 환율로 환산한 원화 금액. 금액이나 환율이 유효하지 않으면 nil.
    var payAmountInKRW: Double? {
        guard payAmount >= 0, let rate = validExchangeRate else { return nil }
        return payAmount * rate
    }
}

// MARK: - 영수증 탭이 쓰는 값 읽기
// 영수증 기능이 Expense 로 통합되면서, 화면들이 기대하는 인터페이스를 여기서 제공한다.
// Expense 는 category/currency 가 Int64 코드라 문자열로 풀어 준다.

extension Expense {

    // 여행에 배정되지 않은 임시 기록은 '미분류' 로 본다.
    var missionTitle: String {
        guard let travel, travel.isUserCreated, let name = travel.name, !name.isEmpty else { return "미분류" }
        return name
    }

    var categoryName: String {
        ExpenseInfoCategory.descriptionFor(rawValue: Int(category))
    }

    var currencyCode: String {
        CurrencyInfoModel.shared.currencyResult[Int(currency)]?.isoCodeNm ?? "KRW"
    }

    var currencySymbol: String {
        CurrencyInfoModel.shared.currencyResult[Int(currency)]?.symbol ?? ""
    }

    var merchantName: String {
        (info?.isEmpty == false ? info : nil) ?? "상호 미입력"
    }

    var memoText: String { memo ?? "" }

    var paidDate: Date { payDate ?? .distantPast }

    // 기록 당시 시간대. 없으면 기기 현재 시간대로 대체한다.
    var recordedTimeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    // 원화면 환율 없이 금액 그대로. 그 외 통화는 유효 환율이 있어야 환산한다.
    var amountInKRW: Double? {
        guard payAmount >= 0 else { return nil }
        if currencyCode == "KRW" { return payAmount }
        return validExchangeRate.map { payAmount * $0 }
    }

    var needsExchangeRate: Bool {
        currencyCode != "KRW" && validExchangeRate == nil
    }

    // 영수증 사진이 아직 없는 기록인지.
    // 현장에서 금액만 먼저 남기고 사진은 나중에 붙이는 흐름을 위해 따로 센다.
    var needsPhoto: Bool {
        imageData?.isEmpty ?? true
    }

    // 지출한 위치의 좌표. 둘 다 있어야 유효하다.
    // Core Data 는 스칼라 nil 을 못 담아 NSNumber? 로 두었으므로 여기서 풀어 준다.
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude?.doubleValue, let lon = longitude?.doubleValue else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func setCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        latitude = coordinate.map { NSNumber(value: $0.latitude) }
        longitude = coordinate.map { NSNumber(value: $0.longitude) }
    }
}

// MARK: - 코드 변환
// 화면은 통화·카테고리를 문자열로 다루는데 Core Data 는 Int64 코드로 저장한다.
// 역방향 변환을 한곳에 모아 두어 각 화면이 제 나름의 방식을 만들지 않게 한다.

enum ExpenseCode {

    static let baseCurrency = "KRW"

    // CountryList.csv 의 '알 수 없음' 행. 기록에 국가가 남지 않았을 때 쓴다.
    // Core Data 의 country 기본값도 이 값이다. 예전 기본값은 0(대한민국)이라
    // 국가를 한 번도 정하지 않은 기록이 전부 국내로 표시됐다.
    static let unknownCountry: Int64 = -1

    // 자주 쓰는 통화만 앞에 세운다. 전체 목록은 166개라 선택지로 늘어놓기 어렵다.
    static let currencyPresets = ["KRW", "USD", "PHP", "THB", "VND", "IDR", "JPY", "EUR"]

    // ISO 코드 → Int64. CurrencyList.csv 는 [Int: CurrencyInfo] 라 역으로 찾는다.
    private static let currencyIndexByCode: [String: Int] = {
        var map: [String: Int] = [:]
        for (index, info) in CurrencyInfoModel.shared.currencyResult {
            // 같은 코드가 여러 번 나오면 더 작은 인덱스를 남긴다.
            if let existing = map[info.isoCodeNm], existing <= index { continue }
            map[info.isoCodeNm] = index
        }
        return map
    }()

    static func currencyIndex(for code: String) -> Int64 {
        Int64(currencyIndexByCode[code.uppercased()] ?? currencyIndexByCode[baseCurrency] ?? 0)
    }

    static func currencyCode(for index: Int64) -> String {
        CurrencyInfoModel.shared.currencyResult[Int(index)]?.isoCodeNm ?? baseCurrency
    }

    static func categoryIndex(for description: String) -> Int64 {
        Int64(ExpenseInfoCategory.from(description: description).rawValue)
    }
}

// MARK: - 표시용 포맷

extension Expense {

    func formattedDate(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = recordedTimeZone
        formatter.dateStyle = style
        formatter.timeStyle = .short
        return formatter.string(from: paidDate)
    }

    // 기록 당시 현지 시각만. 기기 시간대와 다르면 약어를 덧붙인다.
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

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: payAmount)) ?? "0"
        return "\(currencyCode) \(number)"
    }

    var formattedAmountInKRW: String {
        guard let value = amountInKRW else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + "원"
    }

    /// 이 지출을 함께 쓴 사람들. 인원별 정산이 이 값으로 나뉜다.
    ///
    /// 저장은 NSArray 로 한다. Core Data 의 Transformable 은 Objective-C 타입만
    /// 받는데 `[String]` 은 그것이 아니어서, 예전에는 열 때마다 아래 경고가 났다.
    ///
    ///     CoreData: Declared Objective-C type "[String]" for attribute
    ///               named participantArray is not valid
    ///
    /// 값은 예전과 똑같이 담긴다(NSSecureUnarchiveFromData 로 감싼 문자열 배열).
    /// 바뀐 것은 선언뿐이라 이미 저장된 기록을 그대로 읽는다.
    var participants: [String] {
        get { (participantArray as? [String]) ?? [] }
        set { participantArray = newValue as NSArray }
    }
}
