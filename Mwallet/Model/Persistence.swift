//
//  Persistence.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/10/23.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Dummy data will go here later
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    // CloudKit 동기화 스위치.
    // 켜기 전에 준비할 것: 유료 Apple Developer 계정, Signing & Capabilities 에
    // iCloud(CloudKit) + Background Modes(Remote notifications) 추가,
    // 아래 컨테이너 식별자와 같은 이름의 iCloud 컨테이너 생성.
    // 끈 상태에서는 완전한 로컬 저장소로 동작하므로 개발과 시연에 지장이 없다.
    static let isCloudKitSyncEnabled = false
    static let cloudKitContainerIdentifier = "iCloud.com.Mwallet.app"

    let container: NSPersistentCloudKitContainer
      init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Mwallet")

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            // CloudKit 미러링의 전제 조건. 스토어를 만들 때부터 켜 두어야
            // 나중에 동기화를 활성화할 때 저장소를 다시 만들지 않아도 된다.
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            if Self.isCloudKitSyncEnabled && !inMemory {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
            } else {
                // 스위치가 꺼져 있으면 미러링을 명시적으로 해제해 로컬 전용으로 둔다.
                description.cloudKitContainerOptions = nil
            }
        }

        container.loadPersistentStores { _, error in
          if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
          }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
        /// - Tag: viewContextMergePolicy
        container.viewContext.mergePolicy =
        NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
      }
    
    func deleteItems(object: Travel?) {

        var travelToBeDeleted: Travel?
        do {
            travelToBeDeleted = try self.container.viewContext.fetch(Travel.fetchRequest()).filter { travel in
                if let object {
                    return object.id == travel.id
                }
                return false
            }.first
        } catch {
            print("error fetching travel: \(error.localizedDescription)")
        }
        
        if travelToBeDeleted != nil {
            self.container.viewContext.delete(travelToBeDeleted!)
        }

        try? self.container.viewContext.save()
    }
    
    func deleteExpenseFromTravel(travel: Travel?, expenseId: ObjectIdentifier) {
        guard let travel = travel,
              let expenses = travel.expenseArray as? Set<Expense>,
              let expenseToDelete = expenses.first(where: { $0.id == expenseId }) else { return }

        do {
            let object = try self.container.viewContext.existingObject(with: expenseToDelete.objectID)
            self.container.viewContext.delete(object)
            try self.container.viewContext.save()
            
        } catch {
            let nsError = error as NSError
            print("error while deleteExpenseFromTravel: \(nsError.localizedDescription)")
        }
    }
}
