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
import Foundation

final class FirstLaunchSeeder {

    static let shared = FirstLaunchSeeder()

    // 키 이름은 바꾸지 않는다. 바꾸면 기존 설치에서 기본 여행이 하나 더 생긴다.
    private static let seededKey = "TempSave.isFirst"

    private let viewContext = PersistenceController.shared.container.viewContext

    private init() {
        // 값이 없으면 첫 실행이고, true 로 남아 있어도 아직 시딩 전으로 본다.
        let needsSeeding = (UserDefaults.standard.object(forKey: Self.seededKey) as? Bool) ?? true
        UserDefaults.standard.set(false, forKey: Self.seededKey)

        guard needsSeeding else { return }
        addDefaultTravel()
    }

    private func addDefaultTravel() {
        let now = Date()
        let travel = Travel(context: viewContext)
        travel.id = UUID()
        travel.name = tempTravelName
        travel.startDate = now
        travel.endDate = now
        travel.lastUpdate = now

        do {
            try viewContext.save()
        } catch {
            print("FirstLaunchSeeder | 기본 여행 생성 실패: \(error.localizedDescription)")
        }
    }
}
