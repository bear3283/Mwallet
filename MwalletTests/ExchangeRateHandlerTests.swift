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
    private let lastAttemptKey = "ExchangeRate.lastAttemptAt"
    private var savedCache: Data?
    private var savedAttempt: Any?

    override func setUp() {
        super.setUp()
        // 실기기/시뮬레이터에 남아 있던 실제 캐시를 건드리지 않도록 보관해 둔다.
        savedCache = UserDefaults.standard.data(forKey: cacheKey)
        savedAttempt = UserDefaults.standard.object(forKey: lastAttemptKey)
        // 시도 기록이 남아 있으면 '다시 물을 때' 판정이 시험마다 달라진다.
        UserDefaults.standard.removeObject(forKey: lastAttemptKey)
    }

    override func tearDown() {
        if let savedCache {
            UserDefaults.standard.set(savedCache, forKey: cacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
        if let savedAttempt {
            UserDefaults.standard.set(savedAttempt, forKey: lastAttemptKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastAttemptKey)
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
    // 이 시험이 지키는 것은 '만료 시각' 이다. 하루 두 번 다시 묻는 규칙이
    // 끼어들면 12시간에서 참이 되어 무엇을 재는지 흐려지므로, 방금 물어본
    // 것으로 두어 다시 묻기를 잠재운다.
    func test_다음_갱신_시각이_없으면_마지막_갱신_24시간_뒤로_본다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: nil)

        let justBefore = Date(timeIntervalSince1970: 1_000_000 + 86_399)
        let justAfter = Date(timeIntervalSince1970: 1_000_000 + 86_401)

        XCTAssertFalse(ExchangeRateHandler.shared.needsRefresh(now: justBefore,
                                                              lastAttempt: justBefore))
        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: justAfter,
                                                             lastAttempt: justAfter))
    }

    // MARK: - 하루 두 번 다시 묻기

    // API 는 하루에 한 번만 갱신한다(캐시의 time_next_update_unix 를 재 보면
    // 정확히 24시간이다). 그런데도 열두 시간 뒤에 한 번 더 묻는 까닭은 첫
    // 번째가 실패했을 수 있어서다 — 여행 중에는 연결이 자주 끊기고, 그 한
    // 번이 비행기 안이었으면 그날 기록이 통째로 옛 환율로 굳는다.
    func test_열두_시간이_지나면_캐시가_살아_있어도_다시_묻는다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: 1_086_400)
        let attempt = Date(timeIntervalSince1970: 1_000_000)
        let twelveHoursLater = attempt.addingTimeInterval(ExchangeRateHandler.recheckInterval)

        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: twelveHoursLater,
                                                             lastAttempt: attempt))
    }

    // 앱을 하루에 스무 번 열어도 요청은 두 번을 넘지 않아야 한다.
    // 무료 할당량을 쓰는 자리라 아껴야 한다.
    func test_열두_시간_전에는_다시_묻지_않는다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: 1_086_400)
        let attempt = Date(timeIntervalSince1970: 1_000_000)
        let elevenHours = attempt.addingTimeInterval(11 * 60 * 60)

        XCTAssertFalse(ExchangeRateHandler.shared.needsRefresh(now: elevenHours,
                                                              lastAttempt: attempt))
    }

    // 물어본 적이 없으면 캐시를 받은 시각을 기준으로 삼는다.
    // 그때가 마지막으로 성공한 순간이라 뜻이 같다.
    func test_물어본_기록이_없으면_캐시를_받은_시각을_기준으로_센다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: 1_086_400)

        let elevenHours = Date(timeIntervalSince1970: 1_000_000 + 11 * 3_600)
        let thirteenHours = Date(timeIntervalSince1970: 1_000_000 + 13 * 3_600)

        XCTAssertFalse(ExchangeRateHandler.shared.needsRefresh(now: elevenHours))
        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: thirteenHours))
    }

    // 기기 시계를 뒤로 돌린 경우. 미래에 물어본 것으로 남아 있으면 영영
    // 다시 묻지 않게 된다.
    func test_시계가_뒤로_가도_멈추지_않는다() {
        writeCache(rates: ["USD": 0.00075], lastUpdate: 1_000_000, nextUpdate: 1_086_400)
        let now = Date(timeIntervalSince1970: 1_010_000)
        let futureAttempt = Date(timeIntervalSince1970: 1_080_000)

        XCTAssertTrue(ExchangeRateHandler.shared.needsRefresh(now: now,
                                                             lastAttempt: futureAttempt))
    }

    // 하루에 두 번이지 그 이상은 아니다.
    func test_다시_묻는_사이는_열두_시간이다() {
        XCTAssertEqual(ExchangeRateHandler.recheckInterval, 12 * 60 * 60)
    }

    // MARK: - 어디로 물어보는가

    // 중계를 세우면 키가 앱에 실리지 않는다. 주소에 키가 섞여 나가면
    // 중계를 세운 뜻이 통째로 사라진다.
    func test_중계가_있으면_키_없이_그리로_묻는다() throws {
        let url = try XCTUnwrap(ExchangeRateHandler.requestURL(
            baseCode: "KRW",
            endpoint: "https://rates.example.workers.dev",
            key: "SECRET"))

        XCTAssertEqual(url.absoluteString, "https://rates.example.workers.dev/latest/KRW")
        XCTAssertFalse(url.absoluteString.contains("SECRET"), "키가 주소에 섞이면 안 된다")
    }

    // 주소 끝에 / 를 붙여 적는 사람이 있다. 그것 때문에 //latest 가 되면
    // 중계가 404 를 돌려주고, 환율이 조용히 안 온다.
    func test_주소_끝의_빗금을_받아_준다() throws {
        let url = try XCTUnwrap(ExchangeRateHandler.requestURL(
            baseCode: "KRW",
            endpoint: "https://rates.example.workers.dev/",
            key: nil))

        XCTAssertEqual(url.absoluteString, "https://rates.example.workers.dev/latest/KRW")
    }

    // 중계를 아직 안 세운 개발 기기에서도 그대로 돌아야 한다.
    func test_중계가_없으면_키로_직접_묻는다() throws {
        let url = try XCTUnwrap(ExchangeRateHandler.requestURL(
            baseCode: "KRW", endpoint: nil, key: "SECRET"))

        XCTAssertEqual(url.absoluteString,
                       "https://v6.exchangerate-api.com/v6/SECRET/latest/KRW")
    }

    // 둘 다 없으면 부를 곳이 없다. 엉뚱한 주소를 만들어 조용히 실패하는
    // 것보다 아무것도 만들지 않는 편이 낫다.
    func test_중계도_키도_없으면_주소를_만들지_않는다() {
        XCTAssertNil(ExchangeRateHandler.requestURL(baseCode: "KRW", endpoint: nil, key: nil))
    }

    // xcconfig 가 비어 있으면 Info.plist 에 빈 문자열이 들어온다.
    // 그것을 '설정됨' 으로 보면 주소가 '/latest/KRW' 가 되어 버린다.
    func test_빈_문자열은_설정되지_않은_것으로_본다() throws {
        let url = try XCTUnwrap(ExchangeRateHandler.requestURL(
            baseCode: "KRW", endpoint: nil, key: "SECRET"))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://"))
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
