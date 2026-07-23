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
//            MainView()
            SplashView()
//            TestView()
        }
    }
}
