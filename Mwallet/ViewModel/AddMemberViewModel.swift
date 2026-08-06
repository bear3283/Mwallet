//
//  AddMemberViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/18.
//

import Foundation
import CoreData
import OSLog

class AddMemberViewModel: ObservableObject {
    let viewContext = PersistenceController.shared.container.viewContext
    
    @Published var savedParticipant: [Travel] = []
    @Published var participantArr: [String]? = []
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var travelName: String?
    @Published var travelID = UUID()
    
    func addTravel() {
        let travel = Travel(context: viewContext)
        travel.participantArray = participantArr
        travel.startDate = startDate
        travel.endDate = endDate
        travel.name = travelName
        travel.id = travelID
        saveTravel()
    }
    
    func saveTravel() {
        do {
            try viewContext.save()
        } catch let error {
            Logger.data.error("여행 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func updateSelectedTravels() {
        var newTravel: Travel?
        do {
            newTravel = try viewContext.fetch(Travel.fetchRequest()).filter { travel in
                if let id = travel.id {
                    return id == travelID
                } else {
                    return false
                }
            }.first
        } catch {
            Logger.data.error("여행 조회 실패: \(error.localizedDescription, privacy: .public)")
        }
        
        MainViewModel.shared.selectedTravel = newTravel
    }
    
    func filterEmptyStrings(_ array: [String]) -> [String] {
        return array.filter { !$0.isEmpty }
    }
    
    func filterMeFromStrings(_ array: [String]) -> [String] {
        return array.filter { $0 != "나" }
    }
    
    func filterDuplicates(_ array: [String]) -> [String] {
        return Array(Set(array))
    }
}
