//
//  ExchangeRateHandlerTests.swift
//  MwalletTests
//
//  환율 캐시 만료 판정과 환산 계산.
//  잘못된 환율이 Core Data 에 스냅샷으로 굳으면 나중에 고칠 수 없으므로
//  경계값(0, 음수, 없음)을 특히 확인한다.
//

import XCTest
@testable import Mwallet

final class ExchangeRateHandlerTests: XCTestCase {

    private let cacheKey = "SavedExchangeRates"
    private var savedCache: Data?

    override func setUp() {
        super.setUp()
        // 실기기/시뮬레이터에 남아 있던 실제 캐시를 건드리지 않도록 보관해 둔다.
        savedCache = UserDefaults.standard.data(forKey: cacheKey)
    }

    override func tearDown() {
        if let savedCache {
            UserDefaults.standard.set(savedCache, forKey: cacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
        super.tearDown()
    }

    private func writeCache(rates: [String: Double], lastUpdate: Int, nextUpdate: Int?) {
        let rate = ExchangeRate(base_code: "KRW",
                                conversion_rates: rates,
                                time_last_update_utc: "",
                                time_last_update_unix: lastUpdate,
                                time_next_update_unix: nextUpdate)
        UserDefaults.standard.set(try? JSONEncoder().encode(rate), forKey: cacheKey)
    }

    // MARK: - 만료 판정

    func test_캐시가_없으면_갱신이_필요하다() {
        UserDefaults.standard.removeObject(forKey: cacheKey)

        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: Date()))
    }

    func test_다음_갱신_시각_이전에는_다시_받지_않는다() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        writeCache(rates: ["USD": 0.00075], lastUpdate: 990_000, nextUpdate: 1_010_000)

        XCTAssertFalse(ExchangeRateHandler.shared.needsRefresh(now: now))
    }

    func test_다음_갱신_시각이_지나면_갱신한다() {
        let now = Date(timeIntervalSince1970: 1_020_000)
        writeCache(rates: ["USD": 0.00075], lastUpdate: 990_000, nextUpdate: 1_010_000)

        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: now))
    }

    // 구버전 캐시에는 time_next_update_unix 가 없다. 마지막 갱신 + 24시간으로 본다.
    func test_다음_갱신_시각이_없으면_마지막_갱신_24시간_뒤로_본다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: nil)

        let justBefore = Date(timeIntervalSince1970: 1_000_000 + 86_399)
        let justAfter = Date(timeIntervalSince1970: 1_000_000 + 86_401)

        XCTAssertFalse(ExchangeRateHandler.shared.needsRefresh(now: justBefore))
        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: justAfter))
    }

    // MARK: - 환산

    func test_환율을_뒤집어_원화_가치를_준다() {
        writeCache(rates: ["USD": 0.0008], lastUpdate: 0, nextUpdate: nil)

        let rate = ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "USD")

        XCTAssertEqual(try XCTUnwrap(rate), 1250, accuracy: 0.0001)
    }

    func test_통화_코드는_대소문자를_가리지_않는다() {
        writeCache(rates: ["USD": 0.0008], lastUpdate: 0, nextUpdate: nil)

        XCTAssertEqual(ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "usd"),
                       ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "USD"))
    }

    // 0 이면 1/0 = 무한대, 음수면 금액 부호가 뒤집힌다. 둘 다 nil 이어야 한다.
    func test_환율이_0이거나_음수면_값을_주지_않는다() {
        writeCache(rates: ["AAA": 0, "BBB": -0.5], lastUpdate: 0, nextUpdate: nil)

        XCTAssertNil(ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "AAA"))
        XCTAssertNil(ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "BBB"))
    }

    func test_목록에_없는_통화는_값을_주지_않는다() {
        writeCache(rates: ["USD": 0.0008], lastUpdate: 0, nextUpdate: nil)

        XCTAssertNil(ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: "ZZZ"))
    }
}
