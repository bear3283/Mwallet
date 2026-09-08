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

    static func seedIfNeeded(into context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

        let existing = Set(existingNames(in: context))
        let pending = DebugSampleData.samples.filter { !existing.contains($0.name) }
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

    private static func insert(_ sample: DebugSampleData.Sample, into context: NSManagedObjectContext) {
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
