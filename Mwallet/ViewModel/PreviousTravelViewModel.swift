//
//  PreviousTravelViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/19.
//

import Foundation
import CoreData
import OSLog

class PreviousTravelViewModel: ObservableObject {
    let viewContext = PersistenceController.shared.container.viewContext
    
    @Published var previousTravel: [Travel] = []
    @Published var savedExpensesByTravel: [Expense] = []
    
    func fetchTravel() {
        let request = NSFetchRequest<Travel>(entityName: "Travel")
        do {
            previousTravel = try viewContext.fetch(request)
        } catch let error {
            Logger.data.error("여행 조회 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func fetchExpense() {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        do {
        savedExpensesByTravel = try viewContext.fetch(request)
        } catch let error {
            Logger.data.error("지출 조회 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func filterExpensesByTravel(selectedTravelID: UUID) -> [Expense] {
        return savedExpensesByTravel.filter { expense in
            if let travelID = expense.travel?.id {
                return travelID == selectedTravelID
            } else {
                return false
            }
        }
    }
    
    func filterPreviousTravel(todayDate: Date) -> [Travel] {
        return previousTravel.filter { travel in
            if let endDate = travel.endDate {
                return endDate < todayDate
            } else {
                return false
            }
        }
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YY.MM.dd"
        
        return formatter
    }()
    
    func differenceBetweenToday(today: Date, startDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: today)
        return components.day ?? 0
    }
}
