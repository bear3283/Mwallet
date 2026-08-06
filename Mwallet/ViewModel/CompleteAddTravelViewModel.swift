//
//  CompleteAddTravelViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/18.
//

import Foundation
import CoreData
import OSLog

// 화면이 직접 들고 있는 상태다. @Published 갱신은 메인에서만 일어나야 하므로
// 클래스 전체를 메인 액터에 묶는다.
@MainActor
class CompleteAddTravelViewModel: ObservableObject {
    let viewContext = PersistenceController.shared.container.viewContext
    
    @Published var savedTravel: [Travel] = []
    @Published var travelID = UUID()
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var travelName: String?
    
    func fetchTravel() {
        let request = NSFetchRequest<Travel>(entityName: "Travel")
        do {
            savedTravel = try viewContext.fetch(request)
        } catch let error {
            Logger.data.error("여행 조회 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func filterTravelByID(selectedTravelID: UUID) -> [Travel] {
        return savedTravel.filter { travel in
            if let id = travel.id {
                return id == selectedTravelID
            } else {
                return false
            }
        }
    }
    
    func saveTravel() {
        do {
            try viewContext.save()
        } catch let error {
            Logger.data.error("여행 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func dateToString(in date: Date?) -> String {
        if date == nil {
            return "미정"
        } else {
            return AddTravelViewModel.startDateFormatter.string(from: date!)
        }
    }
    
    func endDateToString(in date: Date?) -> String {
        if date == nil {
            return "미정"
        } else {
            return AddTravelViewModel.startDateFormatter.string(from: date!)
        }
    }
}
