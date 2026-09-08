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
    // 어느 탭인지 푸는 일은 AppDestination 이 맡는다 — 홈 화면 바로가기와
    // 같은 곳으로 가야 하므로 표를 두 벌 두지 않는다.
    private func handleDeepLink(_ url: URL) {
        guard let destination = AppDestination(deepLink: url) else { return }
        MainViewModel.shared.selection = destination.tab
        // 탭만 여는 링크와, 그 위에 직접 기록까지 여는 링크가 있다.
        if AppDestination.opensManualEntry(url) {
            MainViewModel.shared.opensManualEntry = true
        }
    }
}
