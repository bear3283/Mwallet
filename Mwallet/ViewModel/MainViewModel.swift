//
//  MainViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/02.
//

import Foundation
import SwiftUI

class MainViewModel: ObservableObject {
    
    static let shared = MainViewModel()

    // 탭 순서: 0 여행 · 1 가계부(예결산) · 2 기록 · 3 영수증
    // 앱을 열면 가장 자주 쓰는 기록 탭으로 시작한다.
    @Published var selection: Int = Tab.record
    @Published var selectedTravel: Travel? {
        didSet {
            if selectedTravel?.name != tempTravelName {
                if selectedTravel != selectedTravelInExpense {
                    updateSelectedTravelInExpense()
                }
            }
        }
    }
    @Published var selectedTravelInExpense: Travel? {
        didSet {
            print("selectedTravelInExpense 변경됨 !!!")
            if selectedTravelInExpense == nil {
                selectedTravelInExpense = findCurrentTravel()
            }
            if selectedTravelInExpense != selectedTravel {
                updateSelectedTravel()
            }
        }
    }
    @Published var chosenTravelInManualRecord: Travel?
    
    private init() {
        print("mainViewModel init")
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
