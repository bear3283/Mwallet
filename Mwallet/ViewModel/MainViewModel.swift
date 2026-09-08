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
    @Published var selectedTravel: Travel? {
        didSet {
            if selectedTravel?.isDefault != true {
                if selectedTravel != selectedTravelInExpense {
                    updateSelectedTravelInExpense()
                }
            }
        }
    }
    @Published var selectedTravelInExpense: Travel? {
        didSet {
            if selectedTravelInExpense == nil {
                selectedTravelInExpense = findCurrentTravel()
            }
            if selectedTravelInExpense != selectedTravel {
                updateSelectedTravel()
            }
        }
    }
    @Published var chosenTravelInManualRecord: Travel?

    /// 밖에서 '직접 기록' 화면까지 열어 달라고 들어온 요청.
    ///
    /// 큰 위젯의 ＋ 칸이 이 길로 온다. 직접 기록 화면은 RecordView 가 제
    /// 뷰모델로 들고 있어 밖에서 곧장 열 수 없다. 여기에 신호를 두면
    /// 그 화면이 보고 열고, 열면서 도로 내린다.
    @Published var opensManualEntry = false
    
    private init() {
        selectedTravelInExpense = findInitialTravelInExpense()
        selectedTravel = findCurrentTravel() // defaultTravel이면 selectedTravelInExpense를 업데이트하지 않는다.
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
    
    private func updateSelectedTravelInExpense() {
        selectedTravelInExpense = selectedTravel
    }
    
    private func updateSelectedTravel() {
        selectedTravel = selectedTravelInExpense
    }
}
