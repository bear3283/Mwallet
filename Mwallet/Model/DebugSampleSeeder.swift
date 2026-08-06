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
//  들어 있는 것: 여행 1개 · 카테고리별 예산 5건 · 지출 12건.
//  지출은 방콕 시내 여러 좌표에 흩어져 있어 지도의 순서 핀과 여정 레일,
//  카드의 축소 레일이 모두 채워진 상태로 보인다. 원화·현지 통화가 섞여 있고
//  환율을 받지 못한 건도 하나 넣어, 합계에서 빠지는 경로까지 확인할 수 있다.
//

#if DEBUG

import CoreData
import CoreLocation
import Foundation
import OSLog

@MainActor
enum DebugSampleSeeder {

    private static let seededKey = "DebugSampleSeeder.seeded.v1"

    private struct Stop {
        let merchant: String
        let amount: Double
        let currency: String
        /// 1 단위당 원화. nil 이면 환율을 받지 못한 것으로 둔다.
        let rate: Double?
        let category: ExpenseInfoCategory
        let latitude: Double
        let longitude: Double
        let hoursAgo: Int
        let memo: String
    }

    /// 방콕 시내를 도는 사역 일정. 좌표가 서로 떨어져 있어 지도에 동선이 그려진다.
    private static let stops: [Stop] = [
        .init(merchant: "수완나품 공항 리무진", amount: 260, currency: "THB", rate: 39.5,
              category: .transportation, latitude: 13.6900, longitude: 100.7501, hoursAgo: 76,
              memo: "공항 → 숙소"),
        .init(merchant: "반뜨랏 게스트하우스", amount: 3_200, currency: "THB", rate: 39.5,
              category: .room, latitude: 13.7563, longitude: 100.5018, hoursAgo: 74,
              memo: "3박"),
        .init(merchant: "쏨땀 콘반", amount: 480, currency: "THB", rate: 39.5,
              category: .food, latitude: 13.7460, longitude: 100.5340, hoursAgo: 70,
              memo: "팀 첫 식사"),
        .init(merchant: "현지 교회 헌금", amount: 2_000, currency: "THB", rate: 39.4,
              category: .offering, latitude: 13.7370, longitude: 100.5600, hoursAgo: 60,
              memo: "주일 예배"),
        .init(merchant: "아동센터 간식", amount: 850, currency: "THB", rate: 39.4,
              category: .ministry, latitude: 13.7220, longitude: 100.5250, hoursAgo: 58,
              memo: "40명분"),
        .init(merchant: "BTS 하루권", amount: 150, currency: "THB", rate: 39.4,
              category: .transportation, latitude: 13.7440, longitude: 100.5480, hoursAgo: 52,
              memo: ""),
        .init(merchant: "짜뚜짝 시장 물품", amount: 1_180, currency: "THB", rate: 39.2,
              category: .ministry, latitude: 13.7999, longitude: 100.5502, hoursAgo: 46,
              memo: "교구 준비물"),
        .init(merchant: "카오산 로드 저녁", amount: 620, currency: "THB", rate: 39.2,
              category: .food, latitude: 13.7590, longitude: 100.4970, hoursAgo: 44,
              memo: ""),
        .init(merchant: "왓 포 사원 입장료", amount: 300, currency: "THB", rate: 39.2,
              category: .tour, latitude: 13.7465, longitude: 100.4930, hoursAgo: 30,
              memo: "팀 자유시간"),
        // 오프라인에서 기록해 환율을 받지 못한 건. 합계에서 빠지고 화면에 알림이 뜬다.
        .init(merchant: "차이나타운 노점", amount: 240, currency: "THB", rate: nil,
              category: .food, latitude: 13.7400, longitude: 100.5100, hoursAgo: 26,
              memo: "오프라인 기록"),
        .init(merchant: "선물 - 현지 간사", amount: 900, currency: "THB", rate: 39.0,
              category: .gift, latitude: 13.7300, longitude: 100.5400, hoursAgo: 12,
              memo: ""),
        .init(merchant: "귀국 공항철도", amount: 45, currency: "THB", rate: 39.0,
              category: .transportation, latitude: 13.6900, longitude: 100.7501, hoursAgo: 4,
              memo: "")
    ]

    private static let budgets: [(ExpenseInfoCategory, Double)] = [
        (.room, 150_000),
        (.food, 90_000),
        (.transportation, 40_000),
        (.ministry, 120_000),
        (.offering, 80_000)
    ]

    /// 한 번만 넣는다. 이미 넣었으면 아무 일도 하지 않는다.
    static func seedIfNeeded(into context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

        let calendar = Calendar.current
        let now = Date()

        let travel = Travel(context: context)
        travel.id = UUID()
        travel.name = "예시: 방콕 단기사역"
        travel.startDate = calendar.date(byAdding: .day, value: -4, to: now)
        travel.endDate = calendar.date(byAdding: .day, value: 1, to: now)
        travel.lastUpdate = now
        travel.participantArray = ["지훈", "예린", "간사님"]

        for (category, amount) in budgets {
            let budget = Budget(context: context)
            budget.travel = travel
            budget.category = Int64(category.rawValue)
            budget.amount = amount
        }

        // 태국(CountryList.csv 의 인덱스). 못 찾으면 '알 수 없음' 으로 둔다.
        let thailand = CountryInfoModel.shared.countryResult
            .first { $0.value.englishNm == "Thailand" }?.key

        for stop in stops {
            let expense = Expense(context: context)
            expense.travel = travel
            expense.info = stop.merchant
            expense.memo = stop.memo
            expense.payAmount = stop.amount
            expense.category = Int64(stop.category.rawValue)
            expense.currency = ExpenseCode.currencyIndex(for: stop.currency)
            expense.exchangeRate = stop.rate ?? Expense.unknownExchangeRate
            expense.country = Int64(thailand ?? Int(ExpenseCode.unknownCountry))
            expense.payDate = calendar.date(byAdding: .hour, value: -stop.hoursAgo, to: now)
            expense.timeZoneIdentifier = "Asia/Bangkok"
            expense.location = stop.merchant
            expense.setCoordinate(CLLocationCoordinate2D(latitude: stop.latitude,
                                                         longitude: stop.longitude))
        }

        do {
            try context.save()
            Logger.data.debug("예시 여행을 넣었습니다: 지출 \(stops.count)건")
        } catch {
            context.rollback()
            Logger.data.error("예시 여행 생성 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#endif
