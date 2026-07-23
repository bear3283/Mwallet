//
//  MwalletApp.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/5/23.
//

import SwiftUI

@main
struct MwalletApp: App {
    let tempSave = TempSave.shared
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                // @FetchRequest 를 쓰는 화면이 동작하려면 환경에 컨텍스트가 있어야 한다.
                // 기존 화면들은 viewContext 를 직접 참조하므로 이 주입에 영향받지 않는다.
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
