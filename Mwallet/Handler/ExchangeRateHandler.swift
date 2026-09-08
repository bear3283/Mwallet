//
//  ExchangeRateHandler.swift
//  Mwallet
//
//  Created by 김태현 on 10/30/23.
//

import Foundation
import OSLog

struct ExchangeRate: Codable {
    let base_code: String
    let conversion_rates: [String: Double]
    let time_last_update_utc: String
    let time_last_update_unix: Int
    // 구버전 캐시에는 없는 필드이므로 옵셔널로 둔다.
    let time_next_update_unix: Int?
}

extension ExchangeRate {
    // API가 공지한 다음 갱신 시각. 값이 없으면 마지막 갱신 + 24시간으로 대체한다.
    var nextUpdateDate: Date {
        if let next = time_next_update_unix {
            return Date(timeIntervalSince1970: TimeInterval(next))
        }
        return Date(timeIntervalSince1970: TimeInterval(time_last_update_unix) + 24 * 60 * 60)
    }
}

// 쿼터 초과나 잘못된 키일 때 API가 200과 함께 내려주는 응답
private struct ExchangeRateErrorResponse: Decodable {
    let result: String
    let errorType: String

    enum CodingKeys: String, CodingKey {
        case result
        case errorType = "error-type"
    }
}

// 여러 화면의 onAppear 가 동시에 부를 수 있다. 가변 상태(isFetching)는
// NSLock 으로, 캐시는 UserDefaults 로 보호된다.
final class ExchangeRateHandler: @unchecked Sendable {

    static let shared = ExchangeRateHandler()

    private init() {}

    private let cacheKey = "SavedExchangeRates"
    /// 마지막으로 받아 오기를 시도한 시각. 성공했든 실패했든 적는다.
    private let lastAttemptKey = "ExchangeRate.lastAttemptAt"
    private let lock = NSLock()
    private var isFetching = false

    /// 하루에 두 번까지 다시 물어본다.
    ///
    /// 여행 중에는 연결이 자주 끊긴다. 하루 한 번만 물어보면 그 한 번이
    /// 비행기 안이었을 때 그날 내내 옛 환율로 적힌다.
    static let recheckInterval: TimeInterval = 12 * 60 * 60

    // 갱신 진입점. 캐시가 만료되었을 때만 네트워크를 탄다.
    // 호출부마다 만료 판단을 중복 구현하지 않도록 이 메서드로 단일화한다.
    func refreshExchangeRatesIfNeeded() {
        guard needsRefresh() else { return }
        markAttempt()
        fetchAndSaveExchangeRates()
    }

    // 캐시 만료 여부를 API가 내려준 절대 시각(time_next_update_unix)으로 판정한다.
    // 기기 로컬 캘린더로 "오늘 갱신분인가"를 따지면, API가 UTC 자정에 갱신되는 탓에
    // KST 기준 00~09시 구간에서 방금 받은 캐시도 만료로 오판해 매 실행마다 재요청이 나간다.
    //
    // ── 하루 두 번 ────────────────────────────────────────────────
    //
    // 캐시가 살아 있어도 열두 시간이 지났으면 한 번 더 물어본다.
    //
    // API 는 하루에 한 번만 갱신하므로(time_next_update_unix 를 재 보면 정확히
    // 24시간이다) 두 번째 물음이 새 환율을 가져오지는 않는다. 그런데도 다시
    // 묻는 까닭은 **첫 번째가 실패했을 수 있어서**다. 여행 중에는 연결이 자주
    // 끊기고, 하루 한 번만 물어보면 그 한 번이 비행기 안이었을 때 그날 내내
    // 옛 환율로 적힌다. 환율은 지출에 박아 저장되므로 그날 기록이 통째로
    // 어긋난 채 남는다.
    //
    // 대신 '열두 시간마다 무조건' 은 아니다. 마지막 시도 시각을 적어 두고
    // 그로부터 열두 시간이 지났을 때만 다시 묻는다. 앱을 하루에 스무 번 열어도
    // 요청은 두 번을 넘지 않는다 — 무료 할당량을 쓰는 자리라 아껴야 한다.
    /// - Parameters:
    ///   - now: 지금 시각.
    ///   - lastAttempt: 마지막으로 물어본 시각. 넘기지 않으면 저장된 값을 쓴다.
    ///     시험이 이 자리를 넘겨 '열두 시간이 지난 상태' 를 만든다.
    func needsRefresh(now: Date = Date(), lastAttempt: Date? = nil) -> Bool {
        guard let cached = loadExchangeRatesFromUserDefaults() else { return true }

        // 캐시가 만료됐으면 두말할 것 없이 받아 온다.
        if now >= cached.nextUpdateDate { return true }

        // 아직 살아 있어도 열두 시간이 지났으면 한 번 더 물어본다.
        //
        // 물어본 적이 없으면 캐시를 받은 시각을 기준으로 삼는다. 그때가
        // 마지막으로 성공한 순간이라 뜻이 같다.
        let reference = lastAttempt
            ?? lastAttemptDate
            ?? Date(timeIntervalSince1970: TimeInterval(cached.time_last_update_unix))

        // 기기 시계를 뒤로 돌린 경우. 미래에 물어본 것으로 남아 있으면 영영
        // 다시 묻지 않게 되므로, 그때는 곧바로 다시 묻는다.
        guard reference <= now else { return true }

        return now >= reference.addingTimeInterval(Self.recheckInterval)
    }

    var lastAttemptDate: Date? {
        let stamp = UserDefaults.standard.double(forKey: lastAttemptKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// 물어본 사실을 적는다. 받아 오기에 실패해도 적는다 — 실패했다고 곧바로
    /// 다시 물으면, 연결이 없는 동안 앱을 열 때마다 요청이 나간다.
    private func markAttempt(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastAttemptKey)
    }

    // MARK: - 어디로 물어보는가

    /// 중계 주소. 있으면 이리로 묻고 키는 싣지 않는다.
    static var proxyEndpoint: String? {
        let value = (Bundle.main.infoDictionary?["EXCHANGE_RATE_ENDPOINT"] as? String)?
            .trimmingCharacters(in: .whitespaces)
        return (value?.isEmpty == false) ? value : nil
    }

    static var apiKey: String? {
        let value = (Bundle.main.infoDictionary?["API_KEY"] as? String)?
            .trimmingCharacters(in: .whitespaces)
        return (value?.isEmpty == false) ? value : nil
    }

    /// 환율을 물어볼 주소.
    ///
    /// 중계(프록시)가 설정돼 있으면 그리로 간다. 그 편이 두 가지에서 낫다.
    ///
    ///   * 키가 앱에 실리지 않는다. 지금은 Info.plist 에 그대로 들어가
    ///     IPA 를 열면 꺼낼 수 있다.
    ///   * 중계가 하루치 답을 담아 두었다가 모두에게 나눠 준다. 지금은
    ///     사용자마다 제 몫의 요청을 써서, 무료 요금제라면 사용자 스물몇
    ///     명에서 한도가 찬다.
    ///
    /// 중계가 없으면 예전처럼 키로 직접 부른다. 아직 중계를 세우지 않은
    /// 개발 기기에서도 그대로 돌아야 하기 때문이다.
    static func requestURL(baseCode: String,
                           endpoint: String? = proxyEndpoint,
                           key: String? = apiKey) -> URL? {
        if let endpoint {
            let trimmed = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
            return URL(string: "\(trimmed)/latest/\(baseCode)")
        }
        guard let key else { return nil }
        return URL(string: "https://v6.exchangerate-api.com/v6/\(key)/latest/\(baseCode)")
    }

    func fetchAndSaveExchangeRates() {
        // 여러 화면의 onAppear가 겹쳐 같은 요청이 중복으로 나가는 것을 막는다.
        lock.lock()
        if isFetching {
            lock.unlock()
            return
        }
        isFetching = true
        lock.unlock()

        guard let url = Self.requestURL(baseCode: "KRW") else {
            Logger.exchangeRate.error("환율을 부를 주소를 만들지 못했습니다 — 중계 주소도 키도 없습니다")
            endFetching()
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] (data, _, error) in
            guard let self else { return }
            defer { self.endFetching() }

            if let error = error {
                Logger.exchangeRate.error("환율 요청 실패: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let data = data else {
                Logger.exchangeRate.error("환율 응답이 비어 있습니다")
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(ExchangeRate.self, from: data)
                if let encodedData = try? JSONEncoder().encode(decodedResponse) {
                    UserDefaults.standard.set(encodedData, forKey: self.cacheKey)
                }
            } catch {
                // 쿼터 초과 / 키 오류는 정상 스키마가 아니라 에러 응답으로 돌아온다.
                if let apiError = try? JSONDecoder().decode(ExchangeRateErrorResponse.self, from: data) {
                    Logger.exchangeRate.error("환율 API 오류: \(apiError.errorType, privacy: .public)")
                } else {
                    Logger.exchangeRate.error("환율 응답 해석 실패: \(error.localizedDescription, privacy: .public)")
                }
            }
        }.resume()
    }

    private func endFetching() {
        lock.lock()
        isFetching = false
        lock.unlock()
    }

    func loadExchangeRatesFromUserDefaults() -> ExchangeRate? {
        guard let savedData = UserDefaults.standard.data(forKey: cacheKey) else {
            Logger.exchangeRate.debug("환율 캐시가 아직 없습니다")
            return nil
        }
        do {
            return try JSONDecoder().decode(ExchangeRate.self, from: savedData)
        } catch let error {
            Logger.exchangeRate.error("환율 캐시 해석 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // 1 KRW 당 환율(rate)을 뒤집어 해당 통화 1단위의 원화 가치를 돌려준다.
    // rate 가 0 이면 무한대가 나오고 음수면 금액 부호가 뒤집히므로 양수인 경우에만 계산한다.
    func getExchangeRateFromKRW(currencyCode: String) -> Double? {
        guard let loadedData = loadExchangeRatesFromUserDefaults(),
              let rate = loadedData.conversion_rates[currencyCode.uppercased()],
              rate > 0 else {
            return nil
        }
        return 1 / rate
    }
}
