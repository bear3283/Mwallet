//
//  ExchangeRateHandler.swift
//  Mwallet
//
//  Created by 김태현 on 10/30/23.
//

import Foundation

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

class ExchangeRateHandler {

    static let shared = ExchangeRateHandler()

    private init() {}

    private let cacheKey = "SavedExchangeRates"
    private let lock = NSLock()
    private var isFetching = false

    // 갱신 진입점. 캐시가 만료되었을 때만 네트워크를 탄다.
    // 호출부마다 만료 판단을 중복 구현하지 않도록 이 메서드로 단일화한다.
    func refreshExchangeRatesIfNeeded() {
        guard needsRefresh() else { return }
        fetchAndSaveExchangeRates()
    }

    // 캐시 만료 여부를 API가 내려준 절대 시각(time_next_update_unix)으로 판정한다.
    // 기기 로컬 캘린더로 "오늘 갱신분인가"를 따지면, API가 UTC 자정에 갱신되는 탓에
    // KST 기준 00~09시 구간에서 방금 받은 캐시도 만료로 오판해 매 실행마다 재요청이 나간다.
    func needsRefresh(now: Date = Date()) -> Bool {
        guard let cached = loadExchangeRatesFromUserDefaults() else { return true }
        return now >= cached.nextUpdateDate
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

        guard let apiKey = Bundle.main.infoDictionary?["API_KEY"] as? String else {
            endFetching()
            return
        }
        let baseCode = "KRW"
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\(apiKey)/latest/\(baseCode)") else {
            endFetching()
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] (data, _, error) in
            guard let self else { return }
            defer { self.endFetching() }

            if let error = error {
                print("Failed to fetch data from URL: \(error)")
                return
            }
            guard let data = data else {
                print("No data returned from URL")
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
                    print("Exchange rate API error: \(apiError.errorType)")
                } else {
                    print("Failed to decode data: \(error)")
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
            print("No data found in UserDefaults")
            return nil
        }
        do {
            return try JSONDecoder().decode(ExchangeRate.self, from: savedData)
        } catch let error {
            print("Could not load. \(error)")
            return nil
        }
    }

    func getExchangeRateFromKRW(currencyCode: String) -> Double? {
        guard let loadedData = loadExchangeRatesFromUserDefaults(),
              let rate = loadedData.conversion_rates[currencyCode.uppercased()] else {
            return nil
        }
        return 1 / rate
    }
}
