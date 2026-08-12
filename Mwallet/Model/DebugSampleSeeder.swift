//
//  DebugSampleSeeder.swift
//  Mwallet
//
//  화면을 채워 놓고 확인하기 위한 예시 데이터.
//
//  ⚠️ DEBUG 빌드에서만 컴파일된다. 릴리스에는 들어가지 않는다.
//     사용자의 실제 기록에 예시가 섞이면 결산이 틀어지기 때문이다.
//     (첫 실행의 '예시: 제주 워크숍' 은 FirstLaunchSeeder 에 따로 있다)
//
//  들어 있는 것: 여행 4개 · 지출 30건.
//
//  여행을 여러 해에 흩어 놓은 것은 뜻이 있다. 여행 선택 시트가 연도로
//  나뉘고 오른쪽 위에서 한 해만 골라 볼 수 있는데, 같은 해에 모두 몰려
//  있으면 그 두 가지가 도는지 눈으로 볼 수 없다.
//
//  통화도 일부러 섞었다 — 원(1:1), 바트(수십 배), 동(0.05배), 투그릭
//  (0.4배). 자릿수가 크게 다른 통화가 합계와 칸 너비에서 깨지지 않는지
//  본다. 환율을 받지 못한 건도 하나 넣어, 합계에서 빠지는 경로까지
//  확인할 수 있다.
//

#if DEBUG

import CoreData
import CoreLocation
import Foundation
import OSLog

@MainActor
enum DebugSampleSeeder {

    // 여행이 하나뿐이던 v1 에서 늘렸다. 이름이 같은 여행은 건너뛰므로
    // 이미 예시를 받은 기기에도 새것만 더해진다.
    private static let seededKey = "DebugSampleSeeder.seeded.v2"

    private struct Stop {
        let merchant: String
        let amount: Double
        /// 1 단위당 원화. nil 이면 환율을 받지 못한 것으로 둔다.
        let rate: Double?
        let category: ExpenseInfoCategory
        let latitude: Double
        let longitude: Double
        /// 여행이 시작하고 몇 시간 뒤인지.
        let hoursFromStart: Int
        let memo: String
        /// 이 지출을 함께 쓴 사람. 비워 두면 그 여행에 간 사람이 다 낀 것으로 둔다.
        var sharedBy: [String]?
    }

    private struct Sample {
        let name: String
        /// CountryList.csv 의 영어 국가명.
        let country: String
        let currency: String
        let timeZone: String
        /// 오늘로부터 며칠 전에 떠났는지. 끝나는 날도 같은 방식이다.
        let startDaysAgo: Int
        let endDaysAgo: Int
        /// '나' 를 뺀 동행. Travel.participants 의 규칙이다.
        let companions: [String]
        let budgets: [(ExpenseInfoCategory, Double)]
        let stops: [Stop]

        /// 지출에 적을 사람. 이쪽은 '나' 를 포함한다.
        var everyone: [String] { ["나"] + companions }
    }

    // MARK: - 예시 여행

    /// 지금 다니는 중인 여행. 방콕 시내 여러 좌표에 흩어져 있어 지도의 순서
    /// 핀과 여정 레일, 카드의 축소 레일이 모두 채워진 상태로 보인다.
    private static let bangkok = Sample(
        name: "예시: 방콕 단기사역",
        country: "Thailand", currency: "THB", timeZone: "Asia/Bangkok",
        startDaysAgo: 4, endDaysAgo: -1,
        companions: ["지훈", "예린", "간사님"],
        budgets: [(.room, 150_000), (.food, 90_000), (.transportation, 40_000),
                  (.ministry, 120_000), (.offering, 80_000)],
        stops: [
            .init(merchant: "수완나품 공항 리무진", amount: 260, rate: 39.5,
                  category: .transportation, latitude: 13.6900, longitude: 100.7501,
                  hoursFromStart: 20, memo: "공항 → 숙소"),
            .init(merchant: "반뜨랏 게스트하우스", amount: 3_200, rate: 39.5,
                  category: .room, latitude: 13.7563, longitude: 100.5018,
                  hoursFromStart: 22, memo: "3박", sharedBy: ["나", "지훈"]),
            .init(merchant: "쏨땀 콘반", amount: 480, rate: 39.5,
                  category: .food, latitude: 13.7460, longitude: 100.5340,
                  hoursFromStart: 26, memo: "팀 첫 식사"),
            .init(merchant: "현지 교회 헌금", amount: 2_000, rate: 39.4,
                  category: .offering, latitude: 13.7370, longitude: 100.5600,
                  hoursFromStart: 36, memo: "주일 예배", sharedBy: ["나"]),
            .init(merchant: "아동센터 간식", amount: 850, rate: 39.4,
                  category: .ministry, latitude: 13.7220, longitude: 100.5250,
                  hoursFromStart: 38, memo: "40명분"),
            .init(merchant: "BTS 하루권", amount: 150, rate: 39.4,
                  category: .transportation, latitude: 13.7440, longitude: 100.5480,
                  hoursFromStart: 44, memo: "", sharedBy: ["나", "예린", "간사님"]),
            .init(merchant: "짜뚜짝 시장 물품", amount: 1_180, rate: 39.2,
                  category: .ministry, latitude: 13.7999, longitude: 100.5502,
                  hoursFromStart: 50, memo: "교구 준비물"),
            .init(merchant: "카오산 로드 저녁", amount: 620, rate: 39.2,
                  category: .food, latitude: 13.7590, longitude: 100.4970,
                  hoursFromStart: 52, memo: ""),
            .init(merchant: "왓 포 사원 입장료", amount: 300, rate: 39.2,
                  category: .tour, latitude: 13.7465, longitude: 100.4930,
                  hoursFromStart: 66, memo: "팀 자유시간"),
            // 오프라인에서 기록해 환율을 받지 못한 건. 합계에서 빠지고 화면에 알림이 뜬다.
            .init(merchant: "차이나타운 노점", amount: 240, rate: nil,
                  category: .food, latitude: 13.7400, longitude: 100.5100,
                  hoursFromStart: 70, memo: "오프라인 기록"),
            .init(merchant: "선물 - 현지 간사", amount: 900, rate: 39.0,
                  category: .gift, latitude: 13.7300, longitude: 100.5400,
                  hoursFromStart: 84, memo: "", sharedBy: ["나", "지훈", "예린"]),
            .init(merchant: "귀국 공항철도", amount: 45, rate: 39.0,
                  category: .transportation, latitude: 13.6900, longitude: 100.7501,
                  hoursFromStart: 92, memo: "")
        ])

    /// 국내. 환율이 1:1 이라 외화 환산이 끼지 않은 화면을 볼 수 있다.
    private static let busan = Sample(
        name: "예시: 부산 수련회",
        country: "Korea", currency: "KRW", timeZone: "Asia/Seoul",
        startDaysAgo: 384, endDaysAgo: 381,
        companions: ["지훈", "수민"],
        budgets: [(.room, 240_000), (.food, 150_000), (.transportation, 120_000),
                  (.ministry, 90_000)],
        stops: [
            .init(merchant: "서울역 KTX", amount: 59_800, rate: 1,
                  category: .transportation, latitude: 37.5547, longitude: 126.9707,
                  hoursFromStart: 2, memo: "3인 왕복 중 편도"),
            .init(merchant: "해운대 게스트하우스", amount: 186_000, rate: 1,
                  category: .room, latitude: 35.1587, longitude: 129.1604,
                  hoursFromStart: 6, memo: "3박"),
            .init(merchant: "광안리 저녁", amount: 62_000, rate: 1,
                  category: .food, latitude: 35.1532, longitude: 129.1187,
                  hoursFromStart: 10, memo: "첫날 모임"),
            .init(merchant: "수련회 교재 인쇄", amount: 48_000, rate: 1,
                  category: .ministry, latitude: 35.1550, longitude: 129.0600,
                  hoursFromStart: 28, memo: "30부"),
            .init(merchant: "감천문화마을 입장", amount: 12_000, rate: 1,
                  category: .tour, latitude: 35.0975, longitude: 129.0107,
                  hoursFromStart: 52, memo: "", sharedBy: ["나", "수민"]),
            .init(merchant: "돌아오는 KTX", amount: 59_800, rate: 1,
                  category: .transportation, latitude: 35.1150, longitude: 129.0420,
                  hoursFromStart: 70, memo: "")
        ])

    /// 해외 하나. 동(VND)은 자릿수가 커서 금액 칸이 밀리지 않는지 보기 좋다.
    private static let danang = Sample(
        name: "예시: 다낭 건축봉사",
        country: "Vietnam", currency: "VND", timeZone: "Asia/Ho_Chi_Minh",
        startDaysAgo: 520, endDaysAgo: 513,
        companions: ["예린", "간사님"],
        budgets: [(.room, 300_000), (.food, 180_000), (.ministry, 400_000),
                  (.transportation, 90_000)],
        stops: [
            .init(merchant: "다낭 공항 택시", amount: 320_000, rate: 0.053,
                  category: .transportation, latitude: 16.0439, longitude: 108.1994,
                  hoursFromStart: 3, memo: "공항 → 숙소"),
            .init(merchant: "미케비치 숙소", amount: 4_200_000, rate: 0.053,
                  category: .room, latitude: 16.0678, longitude: 108.2470,
                  hoursFromStart: 5, memo: "6박"),
            .init(merchant: "반미 프엉", amount: 90_000, rate: 0.053,
                  category: .food, latitude: 16.0544, longitude: 108.2022,
                  hoursFromStart: 26, memo: "팀 점심"),
            .init(merchant: "건축 자재 - 시멘트", amount: 5_600_000, rate: 0.052,
                  category: .ministry, latitude: 16.0300, longitude: 108.2100,
                  hoursFromStart: 50, memo: "교회 증축분"),
            .init(merchant: "현지 교회 헌금", amount: 1_500_000, rate: 0.052,
                  category: .offering, latitude: 16.0470, longitude: 108.2190,
                  hoursFromStart: 122, memo: "주일 예배", sharedBy: ["나"]),
            .init(merchant: "한강 야시장 저녁", amount: 260_000, rate: 0.052,
                  category: .food, latitude: 16.0610, longitude: 108.2270,
                  hoursFromStart: 146, memo: "")
        ])

    /// 해외 둘. 가장 오래된 여행이라 시트에서 아래쪽 연도 묶음을 채운다.
    private static let ulaanbaatar = Sample(
        name: "예시: 울란바토르 캠프",
        country: "Mongolia", currency: "MNT", timeZone: "Asia/Ulaanbaatar",
        startDaysAgo: 890, endDaysAgo: 881,
        companions: ["지훈", "예린"],
        budgets: [(.room, 350_000), (.food, 200_000), (.ministry, 500_000)],
        stops: [
            .init(merchant: "칭기즈칸 공항 픽업", amount: 45_000, rate: 0.40,
                  category: .transportation, latitude: 47.8464, longitude: 106.7669,
                  hoursFromStart: 4, memo: "팀 승합차"),
            .init(merchant: "게르 캠프 숙소", amount: 780_000, rate: 0.40,
                  category: .room, latitude: 47.9210, longitude: 106.9050,
                  hoursFromStart: 7, memo: "8박"),
            .init(merchant: "허르헉 저녁", amount: 120_000, rate: 0.40,
                  category: .food, latitude: 47.9186, longitude: 106.9177,
                  hoursFromStart: 12, memo: "환영 식사"),
            .init(merchant: "캠프 물품 - 담요", amount: 640_000, rate: 0.39,
                  category: .ministry, latitude: 47.9050, longitude: 106.8800,
                  hoursFromStart: 34, memo: "아동 60명분"),
            .init(merchant: "아동 간식", amount: 210_000, rate: 0.39,
                  category: .ministry, latitude: 47.9120, longitude: 106.9300,
                  hoursFromStart: 106, memo: ""),
            .init(merchant: "선물 - 통역 자매", amount: 95_000, rate: 0.39,
                  category: .gift, latitude: 47.9186, longitude: 106.9177,
                  hoursFromStart: 200, memo: "", sharedBy: ["나", "예린"])
        ])

    private static let samples: [Sample] = [bangkok, busan, danang, ulaanbaatar]

    // MARK: - 넣기

    /// 아직 없는 예시 여행만 넣는다. 두 번 불러도 늘어나지 않는다.
    static func seedIfNeeded(into context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

        let existing = Set(existingNames(in: context))
        let pending = samples.filter { !existing.contains($0.name) }
        guard !pending.isEmpty else { return }

        for sample in pending {
            insert(sample, into: context)
        }

        do {
            try context.save()
            let stops = pending.reduce(0) { $0 + $1.stops.count }
            Logger.data.debug("예시 여행 \(pending.count)개를 넣었습니다: 지출 \(stops)건")
        } catch {
            context.rollback()
            Logger.data.error("예시 여행 생성 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func existingNames(in context: NSManagedObjectContext) -> [String] {
        do {
            return try context.fetch(Travel.fetchRequest()).compactMap(\.name)
        } catch {
            // 못 읽었으면 없는 셈 친다. 예시가 겹치는 편이 아예 안 들어오는 것보다 낫다.
            Logger.data.error("예시 확인 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func insert(_ sample: Sample, into context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let now = Date()

        let travel = Travel(context: context)
        travel.id = UUID()
        travel.name = sample.name
        travel.startDate = calendar.date(byAdding: .day, value: -sample.startDaysAgo, to: now)
        travel.endDate = calendar.date(byAdding: .day, value: -sample.endDaysAgo, to: now)
        travel.lastUpdate = now
        travel.participants = sample.companions

        for (category, amount) in sample.budgets {
            let budget = Budget(context: context)
            budget.travel = travel
            budget.category = Int64(category.rawValue)
            budget.amount = amount
        }

        // CountryList.csv 의 인덱스. 못 찾으면 '알 수 없음' 으로 둔다.
        let country = CountryInfoModel.shared.countryResult
            .first { $0.value.englishNm == sample.country }?.key

        for stop in sample.stops {
            let expense = Expense(context: context)
            expense.travel = travel
            expense.info = stop.merchant
            expense.memo = stop.memo
            expense.payAmount = stop.amount
            expense.category = Int64(stop.category.rawValue)
            expense.currency = ExpenseCode.currencyIndex(for: sample.currency)
            expense.exchangeRate = stop.rate ?? Expense.unknownExchangeRate
            expense.country = Int64(country ?? Int(ExpenseCode.unknownCountry))
            expense.payDate = calendar.date(byAdding: .hour,
                                            value: stop.hoursFromStart,
                                            to: travel.startDate ?? now)
            expense.timeZoneIdentifier = sample.timeZone
            expense.location = stop.merchant
            expense.setCoordinate(CLLocationCoordinate2D(latitude: stop.latitude,
                                                         longitude: stop.longitude))
            // 함께 쓴 사람. 인원별 정산이 이 값으로 나뉜다.
            // 다 낀 것도 있고 둘만 낀 것도 있어야 정산이 고르지 않게 나온다.
            expense.participants = stop.sharedBy ?? sample.everyone
        }
    }
}

#endif
