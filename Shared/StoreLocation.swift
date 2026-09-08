//
//  StoreLocation.swift
//  Mwallet · MwalletWidgetExtension
//
//  장부 파일이 어디에 있는가.
//
//  왜 옮기는가 — 여태 저장소는 앱 안쪽(Application Support)에 있었다. 위젯은
//  다른 프로세스라 그 안을 들여다볼 수 없고, 그래서 위젯에서 담은 지출은
//  UserDefaults 큐에 쌓였다가 앱을 열 때에야 기록으로 옮겨졌다. 그동안
//  예산·결산 위젯은 옛 숫자를 보여 준다.
//
//  App Group 안으로 옮기면 앱과 위젯이 같은 파일을 본다. 배관(entitlement)은
//  양쪽에 이미 있고, 옮기지 않은 것은 저장소뿐이었다.
//
//  옮기는 일의 무게 — 이 파일이 사용자의 장부 전체다. 그래서 옮기는 판단과
//  옮기는 행위를 나눠 두었다. 판단(`plan`)은 파일을 만지지 않아 마음껏
//  시험할 수 있고, 행위는 Core Data 가 제공하는 `replacePersistentStore` 를
//  쓴다 — .sqlite 만 옮기고 -wal·-shm 을 두고 오면 최근 기록이 사라진다.
//

import CoreData
import Foundation
import OSLog

/// 앱과 위젯 두 타깃이 함께 컴파일할 파일이라 로거를 여기서 만든다.
/// `Logger.data` 는 앱 타깃에만 있어 위젯에서 컴파일되지 않는다.
private let storeLog = Logger(subsystem: MwalletShared.appGroupID, category: "store")

enum StoreLocation {

    static let fileName = "Mwallet.sqlite"

    /// 앱과 위젯이 함께 보는 자리. App Group 을 못 열면 nil.
    static func shared(_ fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: MwalletShared.appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// 예전 자리. Core Data 가 기본으로 잡던 곳이다.
    static func legacy(_ fileManager: FileManager = .default) -> URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName)
    }

    // MARK: - 판단

    enum Plan: Equatable {
        // 옮기는 일에 붙는 이름은 from·to 다. source·destination 으로 늘리면
        // 규칙은 통과하지만 부르는 자리가 길어질 뿐 더 또렷해지지 않는다.
        // (disable:next 를 쓰면 주석이 case 에서 떨어져 다른 규칙에 걸린다)
        /// 옛 자리에 있는 것을 새 자리로 옮기고, 새 자리를 쓴다.
        case move(from: URL, to: URL) // swiftlint:disable:this identifier_name
        /// 옮길 것 없이 새 자리를 쓴다.
        case useShared(URL)
        /// App Group 을 열 수 없다. 옛 자리를 그대로 쓴다.
        case stayLegacy(URL)
    }

    /// 어느 자리를 쓸지, 옮길 것이 있는지 정한다. 파일은 건드리지 않는다.
    ///
    /// 양쪽에 다 있으면 옮기지 않는다. 새 자리 것이 최신이고, 덮어쓰면
    /// 그 사이에 적은 기록을 잃는다. 한 번 옮긴 뒤 남은 옛 파일은
    /// `move` 를 마치며 지우므로, 보통은 이 경우가 생기지 않는다.
    static func plan(shared sharedURL: URL?,
                     legacy legacyURL: URL,
                     fileManager: FileManager = .default) -> Plan {
        guard let sharedURL else { return .stayLegacy(legacyURL) }

        let hasShared = fileManager.fileExists(atPath: sharedURL.path)
        let hasLegacy = fileManager.fileExists(atPath: legacyURL.path)

        if hasLegacy && !hasShared {
            return .move(from: legacyURL, to: sharedURL)
        }
        return .useShared(sharedURL)
    }

    static func plan(_ fileManager: FileManager = .default) -> Plan {
        plan(shared: shared(fileManager), legacy: legacy(fileManager), fileManager: fileManager)
    }

    // MARK: - 옮기기

    /// 계획대로 옮기고, 실제로 쓸 자리를 돌려준다.
    ///
    /// 옮기다 실패하면 옛 자리를 그대로 쓴다. 옮기지 못한 것보다 장부를
    /// 못 여는 쪽이 훨씬 나쁘다.
    @discardableResult
    static func resolve(_ plan: Plan, model: NSManagedObjectModel) -> URL {
        switch plan {
        case .stayLegacy(let url), .useShared(let url):
            return url

        case .move(let source, let destination):
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            do {
                // .sqlite 하나만 옮기면 안 된다. -wal 에 아직 반영되지 않은
                // 기록이 들어 있어, 파일만 복사하면 최근 몇 건이 사라진다.
                try coordinator.replacePersistentStore(at: destination,
                                                       destinationOptions: nil,
                                                       withPersistentStoreFrom: source,
                                                       sourceOptions: nil,
                                                       type: .sqlite)
                try coordinator.destroyPersistentStore(at: source, type: .sqlite, options: nil)
                removeLeftovers(at: source)
                storeLog.notice("장부를 App Group 으로 옮겼습니다")
                return destination
            } catch {
                storeLog.error("""
                    장부를 옮기지 못해 옛 자리를 그대로 씁니다: \
                    \(error.localizedDescription, privacy: .public)
                    """)
                return source
            }
        }
    }

    /// 비워진 옛 파일을 실제로 치운다.
    ///
    /// `destroyPersistentStore` 는 파일을 지우지 않고 0바이트로 비워만 둔다.
    /// 껍데기가 남으면 `plan` 이 "옛 자리에 장부가 있다" 로 읽는다. 지금은
    /// 새 자리에도 있어 넘어가지만, 새 자리가 어떤 이유로든 사라지면 그
    /// 빈 껍데기를 장부로 알고 옮겨 온다 — 자료를 잃은 것처럼 보인다.
    private static func removeLeftovers(at url: URL, fileManager: FileManager = .default) {
        for suffix in ["", "-wal", "-shm"] {
            let sidecar = URL(fileURLWithPath: url.path + suffix)
            try? fileManager.removeItem(at: sidecar)
        }
    }
}
