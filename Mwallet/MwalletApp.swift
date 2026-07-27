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
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                // @FetchRequest 를 쓰는 화면이 동작하려면 환경에 컨텍스트가 있어야 한다.
                // 기존 화면들은 viewContext 를 직접 참조하므로 이 주입에 영향받지 않는다.
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .onOpenURL(perform: handleDeepLink)
        }
    }

    // 위젯·단축어에서 mwallet://record 로 진입하면 곧장 기록 탭을 연다.
    // (홈 화면 위젯을 눌러 바로 지출을 기록하는 통로)
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mwallet" else { return }
        switch url.host {
        case "record":
            MainViewModel.shared.selection = MainViewModel.Tab.record
        default:
            break
        }
    }
}
