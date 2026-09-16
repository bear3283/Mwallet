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
            // 비면 여행 중인 것으로 메운다. 메울 것이 있을 때만 대입한다.
            //
            // 예전에는 `findCurrentTravel()` 의 답을 그대로 넣었는데, 그 함수도
            // nil 을 돌려주면 nil 을 도로 넣는 꼴이라 didSet 이 자기를 다시 불렀다.
            // 멈출 자리가 없어 여행이 하나도 없는 장부에서는 되풀이하다
            // 스택을 넘어 프로세스가 죽었다 — 부를 때마다 Core Data 를 한 번씩
            // 뒤지므로 조용히 느려지다 터진다.
            //
            // 여행이 없는 장부는 드물지 않다. 지금 보던 여행을 지운 직후가 그렇다.
            if selectedTravelInExpense == nil, let current = findCurrentTravel() {
                // 이 대입이 didSet 을 다시 부른다. 뒷일은 그쪽이 맡으므로 여기서 멈춘다.
                selectedTravelInExpense = current
                return
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
