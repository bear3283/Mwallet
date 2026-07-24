//
//  MainView.swift
//  Mwallet
//
//  Created by 김태현 on 10/11/23.
//

import SwiftUI

struct MainView: View {
    
    @StateObject private var viewModel = MainViewModel.shared
    @State private var selectedTab = 0
    let exchangeRateHandler = ExchangeRateHandler.shared
    
    var body: some View {
        TabView(selection: $viewModel.selection) {
            
            TravelListView(month: Date())
                .tabItem {
                    VStack {
                        if viewModel.selection == 0 {
                            Image("tabitem1_active")
                        } else {
                            Image("tabitem1_unactive")
                        }
                        Text("여행 관리")
                            .font(.caption1)
                    }
                }
                .tag(0)
            
            BudgetView()
                .tabItem {
                    VStack {
                        if viewModel.selection == 1 {
                            Image("tabitem3_active")
                        } else {
                            Image("tabitem3_unactive")
                        }
                        Text("예결산")
                            .font(.caption1)
                    }
                }
                .tag(1)

            RecordView()
                .tabItem {
                    VStack {
                        if viewModel.selection == 2 {
                            Image("tabitem2_active")
                        } else {
                            Image("tabitem2_unactive")
                        }
                        Text("지출 기록")
                            .font(.caption1)

                    }
                }
                .tag(2)

            ReceiptHomeView()
                .tabItem {
                    VStack {
                        if viewModel.selection == 3 {
                            Image("tabitem4_active")
                        } else {
                            Image("tabitem4_unactive")
                        }
                        Text("영수증")
                            .font(.caption1)
                    }
                }
                .tag(3)
        }

        .onAppear {
//            UITabBar.appearance().backgroundColor = .white
//            UITabBar.appearance().barTintColor = .white
            
            let appearance = UITabBarAppearance()
            appearance.shadowColor = UIColor.gray100
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
            
            exchangeRateHandler.refreshExchangeRatesIfNeeded()

            // 위치 권한은 여기서 묻지 않는다. 앱을 켜자마자 물으면 맥락 없는 요청이 되고,
            // 위치를 쓰지 않는 사역 재정 탭 사용자에게도 팝업이 뜬다.
            // 실제로 위치가 필요한 지출 기록 시작 지점에서 요청한다.
        }
        .accentColor(Color.mainGreen)
        .environmentObject(viewModel)
        
    }
}

#Preview {
    MainView()
}
