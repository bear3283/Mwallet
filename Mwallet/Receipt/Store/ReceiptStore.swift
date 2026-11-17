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
    /// 붙인 사진들. 앞에서부터 차례가 그대로 저장된다.
    var photos: [Data] = []
    var coordinate: CLLocationCoordinate2D?
    var placeName: String?
    var paymentMethod: PaymentMethod = .unknown
    /// 이 지출을 함께 쓴 사람들(저장용 이름). 인원별 정산이 이 값으로 나뉜다.
    var participants: [String] = [Travel.selfParticipantName]
    /// CountryList.csv 의 행 번호. 모르면 unknownCountry.
    var country: Int64 = ExpenseCode.unknownCountry

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
        self.photos = expense.photoDataList
        self.coordinate = expense.coordinate
        self.placeName = expense.location
        self.paymentMethod = PaymentMethod(rawValue: Int(expense.paymentMethod)) ?? .unknown
        self.participants = expense.participants
        self.country = expense.country
    }

    var amount: Double? { Self.parseAmount(amountText) }

    /// 적힌 글자를 금액으로 읽는다.
    ///
    /// 쉼표를 무조건 걷어내면 쉼표를 소수점으로 쓰는 언어(독일어·프랑스어 등)
    /// 에서 `15,50` 이 1550 이 된다. 어느 쪽이 자릿점인지는 기기에 묻는다.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let normalized = SentenceRules.normalizingSeparators(trimmed, locale: locale)
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    var isValid: Bool {
        amount != nil && amount != 0
    }

    // 24.5 는 "24.5", 3200 은 "3200" 으로 보여 준다.
    // 소수점 없는 금액에 ".0" 이 붙으면 편집할 때 거슬린다.
    ///
    /// 소수점은 기기 언어의 것으로 적는다. 읽을 때(parseAmount) 기기에 묻기
    /// 때문에, 여기서 '.' 로 못 박으면 독일어 기기에서 24.5 가 245 로 읽힌다.
    static func editableAmountText(_ value: Double, locale: Locale = .current) -> String {
        guard value > 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? ""
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
        expense.exchangeRate = snapshotExchangeRate(for: draft.currency, travel: draft.travel)

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
            expense.exchangeRate = snapshotExchangeRate(for: draft.currency, travel: draft.travel)
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
        // 이미 붙은 것 뒤에 더한다. 목록에서 바로 붙이는 길이라 갈아 끼우면
        // 앞서 붙여 둔 사진이 말없이 사라진다.
        expense.replacePhotos(with: expense.photoDataList + [data], in: context)
        try context.save()
    }

    // 오프라인에서 기록해 환율을 못 받은 건에 현재 환율을 채운다.
    // 그날의 환율이 아니라 지금 환율이므로, 화면에서 그 사실을 알리고 쓴다.
    func applyCurrentExchangeRate(to expense: Expense) throws {
        expense.exchangeRate = snapshotExchangeRate(for: expense.currencyCode, travel: expense.travel)
        try context.save()
    }

    // MARK: - 새 초안

    /// 새 지출의 초안. 여행에서 미리 알 수 있는 것을 채워 둔다.
    ///
    /// 통화와 나라는 그 여행에서 마지막으로 적은 지출의 것을 물려받는다 —
    /// 위젯과 같은 규칙이다. 방콕에서 계속 바트로 적고 있었다면 다음 것도
    /// 바트다. 물려받을 것이 없으면 원화로 두고 화면이 위치를 보고 맞춘다.
    func newDraft(for travel: Travel?, coordinate: CLLocationCoordinate2D? = nil) -> ReceiptDraft {
        var draft = ReceiptDraft()
        let travel = travel?.isUserCreated == true ? travel : nil
        draft.travel = travel
        draft.participants = [Travel.selfParticipantName] + (travel?.participants ?? [])
        draft.coordinate = coordinate
        if let money = inheritedMoney(for: travel) {
            draft.currency = ExpenseCode.currencyCode(for: money.currency)
            draft.country = money.country
        }
        return draft
    }

    /// 이 여행(없으면 미분류)에서 마지막으로 적은 지출의 통화·나라.
    func inheritedMoney(for travel: Travel?) -> QuickExpenseStore.Money? {
        if let travel { return QuickExpenseStore.inheritedMoney(of: travel) }

        let request = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "travel == nil OR travel.isDefault == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.payDate, ascending: false)]
        request.fetchLimit = 20
        let recent = (try? context.fetch(request)) ?? []
        guard let latest = recent.first(where: { $0.exchangeRate > 0 }) else { return nil }
        return QuickExpenseStore.Money(currency: latest.currency,
                                       exchangeRate: latest.exchangeRate,
                                       country: latest.country)
    }

    /// 좌표만 있고 장소 이름이 없는 지출에 이름과 나라를 채운다.
    ///
    /// 말로 적은 지출은 묻지 않고 바로 저장하므로, 주소를 찾는 왕복을
    /// 기다리지 않고 저장한 뒤에 채운다. 실패하면 좌표만 남는다.
    func fillPlace(_ place: ExpensePlace, for expense: Expense) {
        guard !expense.isDeleted, expense.managedObjectContext != nil else { return }
        if (expense.location ?? "").isEmpty, let name = place.name { expense.location = name }
        if expense.country == ExpenseCode.unknownCountry, let country = place.country { expense.country = country }
        do {
            try context.save()
        } catch {
            Logger.data.error("장소 채우기 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 조회 보조

    // 여행 목록. 영수증을 어느 여행에 넣을지 고르는 데 쓴다.
    // '임시 기록' 여행은 사용자가 만든 일정이 아니라 목록에서 뺀다.
    /// 화면에 올릴 여행 목록. 고르는 규칙은 TravelStore 한 곳에 있다.
    func availableTravels() -> [Travel] {
        TravelStore(context: context).availableTravels()
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
        expense.replacePhotos(with: draft.photos, in: context)
        expense.setCoordinate(draft.coordinate)
        expense.location = draft.placeName
        expense.paymentMethod = Int64(draft.paymentMethod.rawValue)
        expense.participants = draft.participants
        expense.country = draft.country
        draft.travel?.lastUpdate = Date()
    }

    // 원화면 환산이 필요 없으므로 1 을 쓴다.
    // 조회에 실패하면 unknownExchangeRate 를 넣고, 화면과 통계는
    // amountInKRW 가 nil 임을 보고 합계에서 제외하거나 "-" 로 표시한다.
    /// 이 지출에 박을 환율.
    ///
    /// 그 여행이 이 통화로 처음 쓴 환율을 이어 쓴다. 한 여행 안에서 환율이
    /// 여러 개가 되면 돌아와서 손으로 검산할 수 없다.
    /// 그 여행의 첫 지출이면 오늘 환율이 곧 그 여행의 환율이 된다.
    private func snapshotExchangeRate(for currency: String, travel: Travel?) -> Double {
        guard currency != ExpenseCode.baseCurrency else { return 1 }
        return TravelExchangeRate.anchoredRate(for: travel, currencyCode: currency)
            ?? exchangeRateHandler.getExchangeRateFromKRW(currencyCode: currency)
            ?? Expense.unknownExchangeRate
    }
}

// MARK: - 좌표에서 장소 찾기

/// 좌표가 가리키는 곳의 이름과 나라.
struct ExpensePlace: Sendable {
    let name: String?
    /// CountryList.csv 의 행 번호.
    let country: Int64?

    /// 좌표로 주소를 찾는다. 네트워크 왕복이라 몇 초 걸리고 실패할 수 있다.
    static func resolve(_ coordinate: CLLocationCoordinate2D) async -> ExpensePlace? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let name = placemark.locality ?? placemark.name
        return ExpensePlace(name: name, country: placemark.isoCountryCode.flatMap(countryIndex(forISO:)))
    }

    /// ISO 나라 코드('TH')를 CountryList.csv 의 행 번호로.
    static func countryIndex(forISO code: String) -> Int64? {
        CountryInfoModel.shared.countryResult.first { _, info in
            let pair = info.locationNm.components(separatedBy: "-")
            return pair.count == 2 && pair[1] == code
        }.map { Int64($0.key) }
    }

    /// 그 나라에서 주로 쓰는 통화 코드. 표에 없거나 모르는 코드면 nil.
    static func primaryCurrency(of country: Int64) -> String? {
        let codes = CountryInfoModel.shared.countryResult[Int(country)]?.relatedCurrencyArray ?? []
        return codes.first { code in
            ExpenseCode.currencyCode(for: ExpenseCode.currencyIndex(for: code)).uppercased() == code.uppercased()
        }
    }
}
