//
//  MwalletApp.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/5/23.
//

import SwiftUI

@main
struct MwalletApp: App {
    // 첫 실행 때 '임시 기록' 기본 여행을 만든다. 접근하는 것만으로 초기화된다.
    private let seeder = FirstLaunchSeeder.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SplashView()
                // @FetchRequest 를 쓰는 화면이 동작하려면 환경에 컨텍스트가 있어야 한다.
                // 기존 화면들은 viewContext 를 직접 참조하므로 이 주입에 영향받지 않는다.
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .onOpenURL(perform: handleDeepLink)
        }
        .onChange(of: scenePhase) { _, phase in
            // 앱이 활성화될 때 위젯에서 담긴 대기 지출을 Core Data 로 반영한다.
            if phase == .active {
                MwalletBridge.flushPendingExpenses(
                    into: PersistenceController.shared.container.viewContext
                )
            }
        }
    }

    // 위젯·단축어에서 mwallet:// 링크로 진입하면 해당 탭을 곧장 연다.
    // record: 기록 탭 · receipt: 영수증 탭 · budget: 예결산 탭
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mwallet" else { return }
        switch url.host {
        case "record":
            MainViewModel.shared.selection = MainViewModel.Tab.record
        case "receipt":
            MainViewModel.shared.selection = MainViewModel.Tab.receipt
        case "budget":
            MainViewModel.shared.selection = MainViewModel.Tab.ledger
        default:
            break
        }
    }
}
