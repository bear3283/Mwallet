//
//  FirstLaunchSeeder.swift
//  Mwallet
//
//  Created by 김태현 on 10/17/23.
//
//  첫 실행 때 '임시 기록' 기본 여행을 만든다.
//  여행에 배정되지 않은 지출이 담길 곳이라 이 레코드가 없으면
//  기록 화면이 저장할 대상을 찾지 못한다. 지워도 되는 더미 데이터가 아니다.
//
//  (이전 이름: Dummy/TempSave.swift — 더미 데이터로 오인되기 쉬워 옮겼다)
//

import CoreData
import CoreLocation
import Foundation
import OSLog

private struct SampleExpense {
    let merchant: String
    let amount: Double
    let category: ExpenseInfoCategory
    let latitude: Double
    let longitude: Double
    let hoursAgo: Int
    /// 함께 쓴 사람. 인원별 정산이 이 값으로 나뉜다.
    let sharedBy: [String]
}

// 앱이 뜰 때 메인에서 한 번 돈다.
@MainActor
final class FirstLaunchSeeder {

    static let shared = FirstLaunchSeeder()

    // 키 이름은 바꾸지 않는다. 바꾸면 기존 설치에서 기본 여행이 하나 더 생긴다.
    private static let seededKey = "TempSave.isFirst"
    // 둘러볼 수 있게 예시 여행 1개 + 지출 2건을 넣는다. 처음 한 번만.
    private static let sampleSeededKey = "FirstLaunchSeeder.sampleSeeded"

    private let viewContext = PersistenceController.shared.container.viewContext

    private init() {
        // 이름으로 기본함을 구분하던 시절의 기록을 플래그로 옮긴다.
        // 새로 만드는 것보다 먼저 해야 기본함이 두 개가 되지 않는다.
        migrateLegacyDefaultTravel()

        // 값이 없으면 첫 실행이고, true 로 남아 있어도 아직 시딩 전으로 본다.
        let needsSeeding = (UserDefaults.standard.object(forKey: Self.seededKey) as? Bool) ?? true
        UserDefaults.standard.set(false, forKey: Self.seededKey)

        // 표시가 옮겨졌거나 이미 있으면 다시 만들지 않는다.
        if needsSeeding && Travel.fetchDefault(in: viewContext) == nil {
            addDefaultTravel()
        }

        // 기본 여행 시딩과 별도 키로 관리한다. 기존 설치에도 예시를 한 번 넣어
        // 지도·목록·예결산이 빈 화면이 아니라 채워진 상태로 보이게 한다.
        if !UserDefaults.standard.bool(forKey: Self.sampleSeededKey) {
            UserDefaults.standard.set(true, forKey: Self.sampleSeededKey)
            addSampleTrip()
        }

        // 화면을 채워 놓고 확인하기 위한 예시. 릴리스에는 들어가지 않는다.
        #if DEBUG
        DebugSampleSeeder.seedIfNeeded(into: viewContext)
        #endif
    }

    private func addDefaultTravel() {
        let now = Date()
        let travel = Travel(context: viewContext)
        travel.id = UUID()
        travel.isDefault = true
        travel.name = Travel.defaultTravelName
        travel.startDate = now
        travel.endDate = now
        travel.lastUpdate = now

        save(context: "기본 여행")
    }

    // 이미 설치된 기기에는 기본함이 이모지 이름으로 남아 있다.
    // isDefault 로 표시를 옮기고 이름도 읽을 수 있게 바꾼다.
    // 이 이름은 화면에 뜨지 않았지만, 여행 편집 화면이 생긴 뒤로는
    // 사용자가 열어 볼 수 있는 값이 됐다.
    private func migrateLegacyDefaultTravel() {
        let request = Travel.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", Travel.legacyDefaultName)

        guard let legacy = try? viewContext.fetch(request), !legacy.isEmpty else { return }

        for travel in legacy {
            travel.isDefault = true
            travel.name = Travel.defaultTravelName
        }
        save(context: "기본 여행 표시 이전")
    }

    // 앱을 처음 열었을 때 무엇을 하는 앱인지 한눈에 보이도록,
    // 실제 흐름을 그대로 담은 예시 여행과 지출 2건을 넣는다.
    private func addSampleTrip() {
        let calendar = Calendar.current
        let now = Date()

        let travel = Travel(context: viewContext)
        travel.id = UUID()
        travel.name = "예시: 제주 워크숍"
        travel.startDate = calendar.date(byAdding: .day, value: -2, to: now)
        travel.endDate = calendar.date(byAdding: .day, value: 1, to: now)
        travel.lastUpdate = now
        // '나' 는 넣지 않는다. 화면이 늘 앞에 붙여 세므로 넣으면 3명이 된다.
        travel.participants = ["동료"]

        let samples = [
            SampleExpense(merchant: "제주 흑돼지집", amount: 48000, category: .food,
                          latitude: 33.2496, longitude: 126.5600, hoursAgo: 5,
                          sharedBy: ["나", "동료"]),
            SampleExpense(merchant: "바다뷰 게스트하우스", amount: 90000, category: .room,
                          latitude: 33.4586, longitude: 126.9425, hoursAgo: 20,
                          sharedBy: ["나", "동료"])
        ]

        for sample in samples {
            let expense = Expense(context: viewContext)
            expense.travel = travel
            expense.info = sample.merchant
            expense.payAmount = sample.amount
            expense.category = Int64(sample.category.rawValue)
            expense.currency = ExpenseCode.currencyIndex(for: "KRW")
            expense.exchangeRate = 1
            // 예시는 제주라 국가를 명시한다. country 기본값은 '알 수 없음' 이므로
            // 적어 두지 않으면 여행 상세의 국가 칸이 비어 보인다.
            expense.country = 0
            expense.payDate = calendar.date(byAdding: .hour, value: -sample.hoursAgo, to: now)
            expense.timeZoneIdentifier = TimeZone.current.identifier
            expense.location = sample.merchant
            expense.setCoordinate(CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude))
            expense.participants = sample.sharedBy
        }

        // 예결산도 채워지도록 카테고리별 예산을 세워 둔다.
        for (category, amount) in [(ExpenseInfoCategory.food, 60000.0), (.room, 100000.0), (.transportation, 40000.0)] {
            let budget = Budget(context: viewContext)
            budget.travel = travel
            budget.category = Int64(category.rawValue)
            budget.amount = amount
        }

        save(context: "예시 여행")
    }

    private func save(context: String) {
        do {
            try viewContext.save()
        } catch {
            Logger.data.error("첫 실행 \(context, privacy: .public) 생성 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
