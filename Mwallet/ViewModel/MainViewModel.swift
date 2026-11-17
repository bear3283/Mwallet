//
//  MainViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/02.
//

import Foundation
import SwiftUI

// 화면이 직접 들고 있는 상태다. @Published 갱신은 메인에서만 일어나야 하므로
// 클래스 전체를 메인 액터에 묶는다.
@MainActor
class MainViewModel: ObservableObject {
    
    static let shared = MainViewModel()

    // 탭 순서: 0 여행 · 1 가계부(예결산) · 2 기록 · 3 영수증
    // 앱을 열면 가장 자주 쓰는 기록 탭으로 시작한다.
    @Published var selection: Int = Tab.record
    /// 지금 보는 여행. 앱에 하나뿐이고 기록·내역·예결산이 함께 쓴다.
    ///
    /// nil 은 '여행을 고르지 않음' 이다. 기록은 미분류로 적히고, 내역은 모든
    /// 여행을 함께 보여 준다.
    ///
    /// 예전에는 같은 것이 다섯 군데에 있었다 — 여기에 셋, 예결산과 영수증
    /// 화면에 하나씩. 서로 didSet 으로 맞추다 스스로를 불러 앱이 죽은 적이
    /// 있고, 한 탭에서 바꾼 여행이 다른 탭에는 닿지 않았다.
    ///
    /// 기본함('임시 기록')은 담지 않는다. 사용자가 만든 여행이 아니라
    /// 고르지 않은 지출이 모이는 자리다.
    @Published var selectedTravel: Travel?

    /// 밖에서 '직접 기록' 화면까지 열어 달라고 들어온 요청.
    ///
    /// 큰 위젯의 ＋ 칸이 이 길로 온다. 직접 기록 화면은 RecordView 가 제
    /// 뷰모델로 들고 있어 밖에서 곧장 열 수 없다. 여기에 신호를 두면
    /// 그 화면이 보고 열고, 열면서 도로 내린다.
    @Published var opensManualEntry = false
    
    private init() {
        selectedTravel = TravelStore().ongoingTravel()
    }

    /// 고른 여행이 지워졌으면 다시 정한다. 화면이 열릴 때마다 부른다.
    func dropSelectionIfDeleted() {
        guard let travel = selectedTravel else { return }
        if travel.isDeleted || travel.managedObjectContext == nil {
            selectedTravel = TravelStore().ongoingTravel()
        }
    }

    // 탭 인덱스를 코드 곳곳에 숫자로 흩뿌리지 않기 위해 한곳에 모은다.
    enum Tab {
        static let travel = 0
        static let ledger = 1
        static let record = 2
        static let receipt = 3
    }

    func navigationToRecordView() {
        self.selection = Tab.record
    }

    func navigationToExpenseView() {
        self.selection = Tab.ledger
    }

    func navigationToTravelView() {
        self.selection = Tab.travel
    }
}
