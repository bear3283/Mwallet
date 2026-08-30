//
//  DebugSampleSeeder.swift
//  Mwallet
//
//  화면을 채워 놓고 확인하기 위한 예시 데이터.
//
//  ⚠️ DEBUG 빌드에서만 컴파일된다. 릴리스에는 들어가지 않는다.
//     사용자의 실제 기록에 예시가 섞이면 결산이 틀어지기 때문이다.
//     (첫 실행의 '예시: 속초 수련회' 는 FirstLaunchSeeder 에 따로 있다)
//
//  들어 있는 것: 여행 6개 · 지출 45건.
//
//  여행을 여러 해에 흩어 놓은 것은 뜻이 있다. 여행 선택 시트가 연도로
//  나뉘고 오른쪽 위에서 한 해만 골라 볼 수 있는데, 같은 해에 모두 몰려
//  있으면 그 두 가지가 도는지 눈으로 볼 수 없다.
//
//  통화도 일부러 섞었다 — 페소(24배), 대만 달러(42배), 엔(9배),
//  동(0.05배), 유로(1,490배), 홍콩 달러(176배). 1 단위가 원화로 얼마인지가
//  0.05 부터 1,490 까지 벌어져 있어, 자릿수가 크게 다른 통화가 합계와 칸
//  너비에서 깨지지 않는지 본다.
//
//  일부러 넣어 둔 자리가 셋 더 있다.
//   - 세부의 '시장 점심' 은 환율을 받지 못한 건이다. 합계에서 빠지고
//     화면에 알림이 뜨는 경로를 본다.
//   - 타이베이는 예산을 조금 넘겨 두었다. 넘긴 상태의 색과 문구는 안 넘긴
//     화면만 보아서는 확인할 수 없다.
//   - 세부는 지금 다니는 중이고, 첫 실행 예시(속초)와 기간이 겹친다.
//     겹치면 늦게 시작한 것이 '지금 있는 곳' 이라는 규칙이 있어서(세부가
//     하루 늦게 떠났다), 위젯으로 담은 것이 세부로 간다. 겹치는 여행이
//     하나도 없으면 그 규칙이 도는지 볼 수 없다.
//

#if DEBUG

import CoreData
import CoreLocation
import Foundation
import OSLog

@MainActor
enum DebugSampleSeeder {

    // 예시를 통째로 갈아끼울 때마다 올린다. 이름이 같은 여행은 건너뛰므로
    // 예전 예시가 남아 있는 기기에는 새것만 더해진다.
    private static let seededKey = "DebugSampleSeeder.seeded.v3"

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

    /// 지금 다니는 중인 여행. 세부 시내 여러 좌표에 흩어져 있어 지도의 순서
    /// 핀과 여정 레일, 카드의 축소 레일이 모두 채워진 상태로 보인다.
    ///
    /// 첫 실행 예시(속초)보다 하루 늦게 떠난다. 기간이 겹칠 때 늦게 시작한
    /// 것을 고르는 규칙이 있어, 위젯으로 담은 것이 이리로 온다 — 원화가
    /// 아닌 통화를 물려받는 길을 눈으로 볼 수 있다.
    private static let cebu = Sample(
        name: "예시: 세부 의료봉사",
        country: "Philippine", currency: "PHP", timeZone: "Asia/Manila",
        startDaysAgo: 3, endDaysAgo: -2,
        companions: ["민서", "재현", "간사님"],
        budgets: [(.room, 220_000), (.food, 120_000), (.transportation, 60_000),
                  (.ministry, 300_000), (.offering, 60_000)],
        stops: [
            .init(merchant: "막탄 공항 밴", amount: 1_200, rate: 24.1,
                  category: .transportation, latitude: 10.3075, longitude: 123.9791,
                  hoursFromStart: 3, memo: "공항 → 숙소"),
            .init(merchant: "라푸라푸 게스트하우스", amount: 4_500, rate: 24.1,
                  category: .room, latitude: 10.3103, longitude: 123.9494,
                  hoursFromStart: 5, memo: "4박", sharedBy: ["나", "재현"]),
            .init(merchant: "첫날 저녁 - 씨푸드", amount: 890, rate: 24.1,
                  category: .food, latitude: 10.3157, longitude: 123.8854,
                  hoursFromStart: 9, memo: "팀 첫 식사"),
            .init(merchant: "의약품 구입", amount: 8_200, rate: 24.0,
                  category: .ministry, latitude: 10.2960, longitude: 123.9020,
                  hoursFromStart: 26, memo: "진료소 준비"),
            .init(merchant: "현지 교회 헌금", amount: 2_500, rate: 24.0,
                  category: .offering, latitude: 10.3020, longitude: 123.8930,
                  hoursFromStart: 30, memo: "주일 예배", sharedBy: ["나"]),
            .init(merchant: "진료소 천막 대여", amount: 3_400, rate: 24.0,
                  category: .ministry, latitude: 10.2880, longitude: 123.8760,
                  hoursFromStart: 34, memo: "이틀분"),
            .init(merchant: "지프니 이동", amount: 180, rate: 23.9,
                  category: .transportation, latitude: 10.3110, longitude: 123.8910,
                  hoursFromStart: 50, memo: "", sharedBy: ["나", "민서", "간사님"]),
            // 오프라인에서 기록해 환율을 받지 못한 건. 합계에서 빠지고 화면에 알림이 뜬다.
            .init(merchant: "시장 점심", amount: 620, rate: nil,
                  category: .food, latitude: 10.2940, longitude: 123.9010,
                  hoursFromStart: 54, memo: "오프라인 기록"),
            .init(merchant: "산토니뇨 성당", amount: 150, rate: 23.9,
                  category: .tour, latitude: 10.2945, longitude: 123.9020,
                  hoursFromStart: 58, memo: "팀 자유시간"),
            .init(merchant: "선물 - 현지 통역", amount: 1_100, rate: 23.9,
                  category: .gift, latitude: 10.3170, longitude: 123.9050,
                  hoursFromStart: 68, memo: "", sharedBy: ["나", "민서", "재현"])
        ])

    /// 예산을 조금 넘긴 여행. 넘긴 상태의 색과 문구를 보려면 하나는 넘겨야 한다.
    private static let taipei = Sample(
        name: "예시: 타이베이 청년집회",
        country: "Taiwan", currency: "TWD", timeZone: "Asia/Taipei",
        startDaysAgo: 45, endDaysAgo: 41,
        companions: ["지연", "현우"],
        budgets: [(.room, 180_000), (.food, 120_000), (.transportation, 60_000),
                  (.ministry, 150_000)],
        stops: [
            .init(merchant: "타오위안 공항철도", amount: 160, rate: 42.3,
                  category: .transportation, latitude: 25.0797, longitude: 121.2342,
                  hoursFromStart: 2, memo: ""),
            .init(merchant: "시먼딩 호스텔", amount: 3_600, rate: 42.3,
                  category: .room, latitude: 25.0421, longitude: 121.5074,
                  hoursFromStart: 4, memo: "3박", sharedBy: ["나", "현우"]),
            .init(merchant: "스린 야시장 저녁", amount: 520, rate: 42.3,
                  category: .food, latitude: 25.0880, longitude: 121.5240,
                  hoursFromStart: 10, memo: "팀 첫 식사"),
            .init(merchant: "집회 장소 대관", amount: 6_800, rate: 42.1,
                  category: .ministry, latitude: 25.0330, longitude: 121.5654,
                  hoursFromStart: 28, memo: "이틀 대관"),
            .init(merchant: "지하철 하루권", amount: 150, rate: 42.1,
                  category: .transportation, latitude: 25.0478, longitude: 121.5170,
                  hoursFromStart: 32, memo: "", sharedBy: ["나", "지연"]),
            .init(merchant: "딘타이펑 점심", amount: 980, rate: 42.0,
                  category: .food, latitude: 25.0330, longitude: 121.5640,
                  hoursFromStart: 52, memo: ""),
            .init(merchant: "예류 지질공원", amount: 120, rate: 42.0,
                  category: .tour, latitude: 25.2077, longitude: 121.6900,
                  hoursFromStart: 74, memo: "팀 자유시간")
        ])

    /// 지난해 가을. 엔은 원화와 자릿수가 가까워, 환산이 끼어도 눈에 덜 띄는 쪽이다.
    private static let osaka = Sample(
        name: "예시: 오사카 교회방문",
        country: "Japan", currency: "JPY", timeZone: "Asia/Tokyo",
        startDaysAgo: 330, endDaysAgo: 327,
        companions: ["수아"],
        budgets: [(.room, 200_000), (.food, 150_000), (.transportation, 80_000),
                  (.ministry, 100_000)],
        stops: [
            .init(merchant: "간사이 공항 특급", amount: 1_800, rate: 9.25,
                  category: .transportation, latitude: 34.4320, longitude: 135.2304,
                  hoursFromStart: 2, memo: ""),
            .init(merchant: "난바 비즈니스호텔", amount: 21_000, rate: 9.25,
                  category: .room, latitude: 34.6660, longitude: 135.5010,
                  hoursFromStart: 4, memo: "2박", sharedBy: ["나", "수아"]),
            .init(merchant: "도톤보리 저녁", amount: 3_600, rate: 9.25,
                  category: .food, latitude: 34.6687, longitude: 135.5013,
                  hoursFromStart: 9, memo: "팀 첫 식사"),
            .init(merchant: "교회 방문 선물", amount: 4_500, rate: 9.18,
                  category: .gift, latitude: 34.6900, longitude: 135.5100,
                  hoursFromStart: 26, memo: "떡과 차"),
            .init(merchant: "지하철 1일권", amount: 800, rate: 9.18,
                  category: .transportation, latitude: 34.6750, longitude: 135.4960,
                  hoursFromStart: 30, memo: ""),
            .init(merchant: "청년부 간식", amount: 6_200, rate: 9.18,
                  category: .ministry, latitude: 34.6930, longitude: 135.5020,
                  hoursFromStart: 34, memo: "20명분"),
            .init(merchant: "오사카성 입장", amount: 600, rate: 9.10,
                  category: .tour, latitude: 34.6873, longitude: 135.5262,
                  hoursFromStart: 50, memo: "")
        ])

    /// 지난해 겨울. 동(VND)은 자릿수가 커서 금액 칸이 밀리지 않는지 보기 좋다.
    private static let hochiminh = Sample(
        name: "예시: 호치민 건축봉사",
        country: "Vietnam", currency: "VND", timeZone: "Asia/Ho_Chi_Minh",
        startDaysAgo: 250, endDaysAgo: 242,
        companions: ["재현", "예은", "간사님"],
        budgets: [(.room, 320_000), (.food, 200_000), (.ministry, 450_000),
                  (.transportation, 90_000)],
        stops: [
            .init(merchant: "떤선녓 공항 택시", amount: 380_000, rate: 0.053,
                  category: .transportation, latitude: 10.8188, longitude: 106.6520,
                  hoursFromStart: 3, memo: "공항 → 숙소"),
            .init(merchant: "1군 숙소", amount: 5_200_000, rate: 0.053,
                  category: .room, latitude: 10.7769, longitude: 106.7009,
                  hoursFromStart: 5, memo: "7박"),
            .init(merchant: "반미 후인호아", amount: 150_000, rate: 0.053,
                  category: .food, latitude: 10.7830, longitude: 106.6900,
                  hoursFromStart: 26, memo: "팀 점심"),
            .init(merchant: "건축 자재 - 벽돌", amount: 6_900_000, rate: 0.052,
                  category: .ministry, latitude: 10.7550, longitude: 106.6700,
                  hoursFromStart: 50, memo: "교회 증축분"),
            .init(merchant: "현지 교회 헌금", amount: 2_000_000, rate: 0.052,
                  category: .offering, latitude: 10.7620, longitude: 106.6820,
                  hoursFromStart: 122, memo: "주일 예배", sharedBy: ["나"]),
            .init(merchant: "벤탄시장 저녁", amount: 340_000, rate: 0.052,
                  category: .food, latitude: 10.7723, longitude: 106.6980,
                  hoursFromStart: 146, memo: ""),
            .init(merchant: "목수 사례", amount: 3_500_000, rate: 0.051,
                  category: .ministry, latitude: 10.7540, longitude: 106.6690,
                  hoursFromStart: 170, memo: "이틀 품삯")
        ])

    /// 재작년 겨울. 유로는 1 단위가 원화로 가장 큰 통화라, 적은 숫자가 큰
    /// 합계가 되는 쪽을 본다.
    private static let frankfurt = Sample(
        name: "예시: 프랑크푸르트 선교대회",
        country: "Germany", currency: "EUR", timeZone: "Europe/Berlin",
        startDaysAgo: 620, endDaysAgo: 614,
        companions: ["현우", "간사님"],
        budgets: [(.room, 600_000), (.food, 300_000), (.transportation, 200_000),
                  (.ministry, 400_000)],
        stops: [
            .init(merchant: "프랑크푸르트 공항철도", amount: 12, rate: 1_478,
                  category: .transportation, latitude: 50.0512, longitude: 8.5705,
                  hoursFromStart: 2, memo: ""),
            .init(merchant: "시내 호스텔", amount: 380, rate: 1_478,
                  category: .room, latitude: 50.1109, longitude: 8.6821,
                  hoursFromStart: 4, memo: "5박", sharedBy: ["나", "현우"]),
            .init(merchant: "대회 등록비", amount: 240, rate: 1_478,
                  category: .ministry, latitude: 50.1180, longitude: 8.6620,
                  hoursFromStart: 6, memo: "1인분"),
            .init(merchant: "마인강 근처 저녁", amount: 38, rate: 1_465,
                  category: .food, latitude: 50.1050, longitude: 8.6800,
                  hoursFromStart: 12, memo: "팀 첫 식사"),
            .init(merchant: "트램 주간권", amount: 22, rate: 1_465,
                  category: .transportation, latitude: 50.1070, longitude: 8.6630,
                  hoursFromStart: 30, memo: ""),
            .init(merchant: "자료집 인쇄", amount: 65, rate: 1_465,
                  category: .ministry, latitude: 50.1140, longitude: 8.6700,
                  hoursFromStart: 54, memo: "30부"),
            .init(merchant: "뢰머 광장 커피", amount: 14, rate: 1_452,
                  category: .food, latitude: 50.1103, longitude: 8.6820,
                  hoursFromStart: 100, memo: "", sharedBy: ["나", "간사님"])
        ])

    /// 가장 오래된 여행이라 시트에서 아래쪽 연도 묶음을 채운다.
    private static let hongkong = Sample(
        name: "예시: 홍콩 청년수련회",
        country: "Hongkong", currency: "HKD", timeZone: "Asia/Hong_Kong",
        startDaysAgo: 800, endDaysAgo: 796,
        companions: ["지연", "예은"],
        budgets: [(.room, 300_000), (.food, 180_000), (.transportation, 90_000),
                  (.ministry, 200_000)],
        stops: [
            .init(merchant: "공항 익스프레스", amount: 115, rate: 176.2,
                  category: .transportation, latitude: 22.3160, longitude: 113.9365,
                  hoursFromStart: 2, memo: ""),
            .init(merchant: "침사추이 게스트하우스", amount: 1_450, rate: 176.2,
                  category: .room, latitude: 22.2976, longitude: 114.1722,
                  hoursFromStart: 4, memo: "3박"),
            .init(merchant: "딤섬 점심", amount: 220, rate: 176.2,
                  category: .food, latitude: 22.2980, longitude: 114.1690,
                  hoursFromStart: 10, memo: "팀 첫 식사"),
            .init(merchant: "수련회 교재 인쇄", amount: 680, rate: 175.4,
                  category: .ministry, latitude: 22.3080, longitude: 114.1750,
                  hoursFromStart: 28, memo: "25부"),
            .init(merchant: "옥토퍼스 카드 충전", amount: 150, rate: 175.4,
                  category: .transportation, latitude: 22.3020, longitude: 114.1720,
                  hoursFromStart: 32, memo: "", sharedBy: ["나", "지연"]),
            .init(merchant: "빅토리아 피크 트램", amount: 88, rate: 175.4,
                  category: .tour, latitude: 22.2759, longitude: 114.1455,
                  hoursFromStart: 74, memo: "팀 자유시간"),
            .init(merchant: "현지 교회 헌금", amount: 500, rate: 174.8,
                  category: .offering, latitude: 22.2830, longitude: 114.1580,
                  hoursFromStart: 80, memo: "주일 예배", sharedBy: ["나"])
        ])

    private static let samples: [Sample] = [cebu, taipei, osaka, hochiminh, frankfurt, hongkong]

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
