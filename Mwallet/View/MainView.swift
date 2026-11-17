//
//  MainView.swift
//  Mwallet
//
//  Created by 김태현 on 10/11/23.
//

import SwiftUI

struct MainView: View {

    @StateObject private var viewModel = MainViewModel.shared
    let exchangeRateHandler = ExchangeRateHandler.shared

    // 차례는 쓰는 흐름을 따른다 — 적고, 적은 것을 보고, 예산과 견주고, 여행을 돌아본다.
    // tag 는 자리가 아니라 탭의 이름이다(MainViewModel.Tab). 차례를 바꿔도
    // 위젯과 링크가 가리키는 탭은 그대로다.
    var body: some View {
        TabView(selection: $viewModel.selection) {

            RecordView()
                .tabItem { tabLabel("기록", icon: "tabitem2", tab: MainViewModel.Tab.record) }
                .tag(MainViewModel.Tab.record)

            ReceiptHomeView()
                .tabItem { tabLabel("내역", icon: "tabitem4", tab: MainViewModel.Tab.receipt) }
                .tag(MainViewModel.Tab.receipt)

            BudgetView()
                .tabItem { tabLabel("예결산", icon: "tabitem3", tab: MainViewModel.Tab.ledger) }
                .tag(MainViewModel.Tab.ledger)

            TravelListView()
                .tabItem { tabLabel("여행", icon: "tabitem1", tab: MainViewModel.Tab.travel) }
                .tag(MainViewModel.Tab.travel)
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.shadowColor = UIColor.gray100
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance

            exchangeRateHandler.refreshExchangeRatesIfNeeded()

            // 위치 권한은 여기서 묻지 않는다. 앱을 켜자마자 물으면 맥락 없는 요청이 된다.
            // 실제로 위치가 필요한 지출 기록 시작 지점에서 요청한다.
        }
        .accentColor(Color.mainAccent)
        .environmentObject(viewModel)
    }

    private func tabLabel(_ title: LocalizedStringKey, icon: String, tab: Int) -> some View {
        VStack {
            Image(viewModel.selection == tab ? "\(icon)_active" : "\(icon)_unactive")
            Text(title)
                .font(.caption1)
        }
    }
}

#Preview {
    MainView()
}
