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
    static let preview: PersistenceController = {
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
        // 전역 var NSMergeByPropertyObjectTrumpMergePolicy 는 공유 가변 상태로
        // 잡힌다. 같은 정책의 타입 프로퍼티를 쓴다.
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
      }

    private func configureStore(inMemory: Bool, useCloudKit: Bool) {
        guard let description = container.persistentStoreDescriptions.first else { return }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // 앱과 위젯이 같은 장부를 보도록 App Group 안에 둔다. 예전 자리에
            // 있던 것은 처음 한 번 옮긴다. 옮기지 못하면 옛 자리를 그대로 쓴다.
            description.url = StoreLocation.resolve(StoreLocation.plan(),
                                                    model: container.managedObjectModel)
        }
        // CloudKit 미러링의 전제 조건. 스토어를 만들 때부터 켜 두어야
        // 나중에 동기화를 활성화할 때 저장소를 다시 만들지 않아도 된다.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        description.cloudKitContainerOptions = useCloudKit
            ? NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerIdentifier)
            : nil
    }

    // MARK: - CloudKit 스키마 배포

    /// Core Data 모델을 CloudKit 의 **개발 환경** 레코드 타입으로 올린다.
    ///
    /// CloudKit 은 스키마를 스스로 만들지 않는다. 앱이 처음 저장할 때 없는
    /// 레코드 타입을 만들어 주기는 하지만, 그러려면 그 타입의 데이터가 실제로
    /// 한 번은 올라가야 한다. 쓰지 않은 필드는 영영 만들어지지 않고, 그 상태로
    /// 운영 환경에 올리면 다른 기기에서 그 필드만 조용히 비어 온다.
    ///
    /// 이 함수는 모델에 적힌 모든 엔티티·속성·관계를 한 번에 올려 그 구멍을 막는다.
    ///
    /// ## 쓰는 법
    ///
    /// 1. 유료 개발자 계정으로 서명한 빌드를 실기기나 시뮬레이터에 올린다
    /// 2. 기기가 iCloud 에 로그인되어 있어야 한다
    /// 3. 설정 화면의 'CloudKit 스키마 올리기' 를 누른다
    /// 4. CloudKit Dashboard 에서 개발 → 운영으로 승격한다
    ///
    /// 4번은 여기서 할 수 없다. 되돌릴 수 없는 일이라 Apple 이 대시보드에서만
    /// 허용한다. 승격한 뒤에는 필드를 지울 수 없으므로, 모델이 굳은 뒤에 한다.
    ///
    /// ## 왜 디버그 빌드에서만인가
    ///
    /// 이 호출은 개발 환경에만 쓴다. App Store 로 나간 앱은 운영 환경을 보는데,
    /// 거기서는 스키마를 바꿀 수 없어 실패한다. 게다가 모델 전체를 올리느라
    /// 느리고 무겁다. 사용자의 기기에서 돌 이유가 없다.
    #if DEBUG
    func deployCloudKitSchema() throws {
        guard Self.isCloudKitSyncEnabled else {
            throw CloudKitSchemaError.syncDisabled
        }
        guard container.persistentStoreDescriptions.first?.cloudKitContainerOptions != nil else {
            throw CloudKitSchemaError.storeNotUsingCloudKit
        }
        // 실제로 레코드를 남기지는 않는다. 타입만 만들고 지운다.
        try container.initializeCloudKitSchema(options: [])
    }
    #endif
}

enum CloudKitSchemaError: LocalizedError {
    case syncDisabled
    case storeNotUsingCloudKit

    var errorDescription: String? {
        switch self {
        case .syncDisabled:
            return String(localized: "CloudKit 동기화가 꺼져 있습니다.")
        case .storeNotUsingCloudKit:
            return String(localized: "저장소가 CloudKit 없이 열렸습니다. iCloud 권한(entitlement)과 로그인 상태를 확인하세요.")
        }
    }
}
