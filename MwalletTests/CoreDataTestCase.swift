//
//  CoreDataTestCase.swift
//  MwalletTests
//
//  Core Data 를 쓰는 테스트의 공통 바탕.
//  메모리 전용 저장소라 디스크와 CloudKit 을 건드리지 않는다.
//

import CoreData
import CoreLocation
import XCTest
@testable import Mwallet

class CoreDataTestCase: XCTestCase {

    var context: NSManagedObjectContext!
    private var container: NSPersistentContainer!

    private let exchangeCacheKey = "SavedExchangeRates"
    private var savedExchangeCache: Data?

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = PersistenceController(inMemory: true).container
        context = container.viewContext

        // 기기에 남아 있던 실제 환율 캐시를 테스트가 덮어쓰지 않도록 보관한다.
        savedExchangeCache = UserDefaults.standard.data(forKey: exchangeCacheKey)
    }

    override func tearDown() {
        if let savedExchangeCache {
            UserDefaults.standard.set(savedExchangeCache, forKey: exchangeCacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: exchangeCacheKey)
        }
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - 만들기

    @discardableResult
    func makeTravel(name: String = "제주 워크숍",
                    start: Date = Date(timeIntervalSince1970: 1_700_000_000),
                    end: Date? = nil,
                    participants: [String] = [],
                    isDefault: Bool = false) -> Travel {
        let travel = Travel(context: context)
        travel.id = UUID()
        travel.isDefault = isDefault
        travel.name = isDefault ? Travel.defaultTravelName : name
        travel.startDate = start
        travel.endDate = end ?? start.addingTimeInterval(3 * 86_400)
        travel.participants = participants
        return travel
    }

    @discardableResult
    func makeExpense(travel: Travel? = nil,
                     amount: Double = 10_000,
                     currency: String = "KRW",
                     rate: Double = 1,
                     category: ExpenseInfoCategory = .food,
                     merchant: String = "식당",
                     memo: String = "",
                     paidAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
                     coordinate: CLLocationCoordinate2D? = nil,
                     hasPhoto: Bool = false,
                     participants: [String] = []) -> Expense {
        let expense = Expense(context: context)
        expense.travel = travel
        expense.payAmount = amount
        expense.currency = ExpenseCode.currencyIndex(for: currency)
        expense.exchangeRate = rate
        expense.category = Int64(category.rawValue)
        expense.info = merchant
        expense.memo = memo
        expense.payDate = paidAt
        expense.timeZoneIdentifier = "Asia/Seoul"
        expense.setCoordinate(coordinate)
        if hasPhoto { expense.imageData = Data([0x01]) }
        // 함께 쓴 사람. 비워 두면 나눌 수 없는 지출이 된다.
        expense.participants = participants
        return expense
    }

    @discardableResult
    func makeBudget(travel: Travel, category: ExpenseInfoCategory, amount: Double) -> Budget {
        let budget = Budget(context: context)
        budget.travel = travel
        budget.category = Int64(category.rawValue)
        budget.amount = amount
        return budget
    }

    // MARK: - 환율 캐시

    /// 테스트가 기대하는 환율을 UserDefaults 캐시에 심는다.
    /// ExchangeRateHandler 는 싱글턴이고 init 이 private 이라 교체할 수 없어,
    /// 캐시를 통해 값을 정해 준다.
    func stubExchangeRates(_ rates: [String: Double]) {
        let rate = ExchangeRate(base_code: "KRW",
                                conversion_rates: rates,
                                time_last_update_utc: "",
                                time_last_update_unix: 0,
                                time_next_update_unix: Int(Date().timeIntervalSince1970) + 86_400)
        UserDefaults.standard.set(try? JSONEncoder().encode(rate), forKey: exchangeCacheKey)
    }
}
