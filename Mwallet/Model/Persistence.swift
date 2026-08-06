//
//  Persistence.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/10/23.
//

import CoreData
import OSLog

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
    //
    // ⚠️ Signing & Capabilities 에 iCloud(CloudKit) 를 추가하기 전에 켜면 앱이 죽는다.
    // entitlement 가 없으면 Core Data 의 CloudKit 미러링이 별도 큐에서 os_crash 를
    // 호출하는데, loadPersistentStores 는 성공으로 끝난 뒤라 코드로 막을 방법이 없다.
    // (iOS 에는 자기 자신의 entitlement 를 읽는 API 가 없다)
    //
    // 켜기 전 준비: 유료 Apple Developer 계정, iCloud 컨테이너 생성,
    // Signing & Capabilities 에 iCloud(CloudKit) + Background Modes(Remote notifications).
    // 자세한 절차는 docs/CloudKit-활성화.md 참고.
    static var isCloudKitSyncEnabled: Bool {
        // 테스트 중에는 끈다.
        //
        // 단위 테스트는 이 앱을 호스트로 띄우는데, CI 처럼 서명 없이 빌드하면
        // entitlement 가 없다. 그 상태로 미러링이 켜지면 위에 적은 이유로
        // 별도 큐에서 죽고, 테스트는 시작조차 못 한 채 실패한다.
        // (Testing failed: Early unexpected exit ... signal trap before starting)
        //
        // 테스트는 어차피 메모리 전용 저장소를 쓰므로 동기화가 필요 없다.
        // 실제 앱 실행에는 영향이 없다.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        return true
    }

    static let cloudKitContainerIdentifier = "iCloud.com.Mwallet.app"

    let container: NSPersistentCloudKitContainer

      init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Mwallet")

        let wantsCloudKit = Self.isCloudKitSyncEnabled && !inMemory
        configureStore(inMemory: inMemory, useCloudKit: wantsCloudKit)

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }

        // 스토어를 여는 단계에서 실패하면(컨테이너 식별자 불일치 등) 동기화를 포기하고
        // 로컬 저장소로 되돌린다. 여기서 죽으면 이미 기록해 둔 영수증에도 접근할 수 없다.
        //
        // 다만 entitlement 자체가 없는 경우는 이 분기로 오지 않는다.
        // 그때는 스토어가 정상적으로 열린 뒤 CloudKit 미러링이 별도 큐에서 죽는다.
        if let error = loadError, wantsCloudKit {
            Logger.data.error("CloudKit 스토어를 열지 못해 로컬 전용으로 되돌립니다: \(error.localizedDescription, privacy: .public)")
            configureStore(inMemory: inMemory, useCloudKit: false)
            loadError = nil
            container.loadPersistentStores { _, error in loadError = error }
        }

        if let error = loadError as NSError? {
            // 로컬 저장소마저 열 수 없는 상태로, 앱이 할 수 있는 복구 수단이 없다.
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
        /// - Tag: viewContextMergePolicy
        container.viewContext.mergePolicy =
        NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
      }

    private func configureStore(inMemory: Bool, useCloudKit: Bool) {
        guard let description = container.persistentStoreDescriptions.first else { return }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        // CloudKit 미러링의 전제 조건. 스토어를 만들 때부터 켜 두어야
        // 나중에 동기화를 활성화할 때 저장소를 다시 만들지 않아도 된다.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        description.cloudKitContainerOptions = useCloudKit
            ? NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerIdentifier)
            : nil
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
            Logger.data.error("여행 조회 실패: \(error.localizedDescription, privacy: .public)")
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
            Logger.data.error("지출 삭제 실패: \(nsError.localizedDescription, privacy: .public)")
        }
    }
}
