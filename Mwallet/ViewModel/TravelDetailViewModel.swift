//
//  TravelDetailViewModel.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/27.
//

import Foundation
import CoreData
import OSLog

// 화면이 직접 들고 있는 상태다. @Published 갱신은 메인에서만 일어나야 하므로
// 클래스 전체를 메인 액터에 묶는다.
@MainActor
class TravelDetailViewModel: ObservableObject {
    
    let viewContext = PersistenceController.shared.container.viewContext
    
    @Published var savedTravel: [Travel] = []
    @Published var selectedTravel: [Travel]?
    @Published var travelID = UUID()
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // 자리 차례는 언어마다 다르다(ko 26.08.30, en 08/30/26). 틀을 주면
        // 시스템이 그 언어의 차례로 놓는다.
        formatter.setLocalizedDateFormatFromTemplate("yyMMdE")
        
        return formatter
    }()
    
    func fetchTravel() {
        let request = NSFetchRequest<Travel>(entityName: "Travel")
        do {
            savedTravel = try viewContext.fetch(request)
        } catch let error {
            Logger.data.error("여행 조회 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func filterByID(selectedTravelID: UUID) -> [Travel] {
        return savedTravel.filter { travel in
            if let id = travel.id {
                return id == selectedTravelID
            } else {
                return false
            }
        }
    }
}
