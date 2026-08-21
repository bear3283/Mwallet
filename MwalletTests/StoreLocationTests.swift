//
//  StoreLocationTests.swift
//  MwalletTests
//
//  장부를 App Group 으로 옮기는 일.
//
//  이 파일이 사용자의 장부 전체다. 한 번 잘못 옮기면 되돌릴 것이 없다.
//  그래서 판단과 행위를 따로 지킨다 — 어느 자리를 쓸지 정하는 규칙과,
//  실제로 옮겼을 때 안에 있던 것이 그대로 읽히는지.
//

import CoreData
import XCTest
@testable import Mwallet

final class StoreLocationTests: XCTestCase {

    private var folder: URL!

    private var legacyURL: URL { folder.appendingPathComponent("옛자리/Mwallet.sqlite") }
    private var sharedURL: URL { folder.appendingPathComponent("새자리/Mwallet.sqlite") }

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StoreLocationTests-\(UUID().uuidString)")
        for name in ["옛자리", "새자리"] {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(name), withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    // MARK: - 판단

    func test_옛_자리에만_있으면_옮긴다() throws {
        try touch(legacyURL)

        XCTAssertEqual(StoreLocation.plan(shared: sharedURL, legacy: legacyURL),
                       .move(from: legacyURL, to: sharedURL))
    }

    func test_새_자리에_이미_있으면_그대로_쓴다() throws {
        try touch(sharedURL)

        XCTAssertEqual(StoreLocation.plan(shared: sharedURL, legacy: legacyURL),
                       .useShared(sharedURL))
    }

    // 둘 다 있으면 덮지 않는다. 새 자리 것이 최신이라, 옛 것으로 덮으면
    // 옮긴 뒤에 적은 기록이 통째로 사라진다.
    func test_양쪽에_다_있으면_덮지_않는다() throws {
        try touch(legacyURL)
        try touch(sharedURL)

        XCTAssertEqual(StoreLocation.plan(shared: sharedURL, legacy: legacyURL),
                       .useShared(sharedURL))
    }

    func test_아직_아무것도_없으면_새_자리에서_시작한다() {
        XCTAssertEqual(StoreLocation.plan(shared: sharedURL, legacy: legacyURL),
                       .useShared(sharedURL))
    }

    // App Group 을 열지 못하는 상황. 옮길 곳이 없으니 옛 자리를 그대로 쓴다.
    // 여기서 새 자리를 고집하면 장부를 아예 열지 못한다.
    func test_App_Group_을_못_열면_옛_자리를_쓴다() {
        XCTAssertEqual(StoreLocation.plan(shared: nil, legacy: legacyURL),
                       .stayLegacy(legacyURL))
    }

    // MARK: - 실제로 옮기기

    func test_옮긴_뒤에도_안에_있던_것이_그대로_읽힌다() throws {
        let model = try XCTUnwrap(NSPersistentContainer(name: "Mwallet").managedObjectModel)

        // 옛 자리에 장부를 만들고 지출 하나를 적는다.
        let old = try open(model, at: legacyURL)
        let expense = Expense(context: old.viewContext)
        expense.info = "게스트하우스"
        expense.payAmount = 42_000
        try old.viewContext.save()
        try close(old)

        let used = StoreLocation.resolve(.move(from: legacyURL, to: sharedURL), model: model)
        XCTAssertEqual(used, sharedURL, "새 자리를 쓰지 못했습니다")

        let moved = try open(model, at: sharedURL)
        let saved = try moved.viewContext.fetch(Expense.fetchRequest())
        XCTAssertEqual(saved.count, 1, "옮긴 장부에 지출이 없습니다")
        XCTAssertEqual(saved.first?.info, "게스트하우스")
        XCTAssertEqual(saved.first?.payAmount, 42_000)
        try close(moved)
    }

    // 옮기고 나면 옛 파일은 치워야 한다.
    //
    // destroyPersistentStore 는 파일을 지우지 않고 0바이트로 비워만 둔다.
    // 그 껍데기가 남으면 plan 이 '옛 자리에 장부가 있다' 로 읽고, 새 자리가
    // 사라진 날 빈 껍데기를 옮겨 온다 — 장부를 통째로 잃은 것처럼 보인다.
    func test_옮긴_뒤_옛_자리는_남지_않는다() throws {
        let model = try XCTUnwrap(NSPersistentContainer(name: "Mwallet").managedObjectModel)
        let old = try open(model, at: legacyURL)
        try old.viewContext.save()
        try close(old)

        StoreLocation.resolve(.move(from: legacyURL, to: sharedURL), model: model)

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path),
                       "옛 장부가 남아 있습니다")
    }

    // 옮길 것이 없는데 옮기라고 하면 새 자리를 못 만든다. 그때 장부를 못
    // 여는 대신 옛 자리로 되돌아와야 한다.
    func test_옮기다_실패하면_옛_자리로_되돌아온다() throws {
        let model = try XCTUnwrap(NSPersistentContainer(name: "Mwallet").managedObjectModel)
        let missing = folder.appendingPathComponent("없는자리/Mwallet.sqlite")

        let used = StoreLocation.resolve(.move(from: missing, to: sharedURL), model: model)

        XCTAssertEqual(used, missing, "실패했는데 새 자리를 쓰려 합니다")
    }

    // MARK: - 거들기

    private func touch(_ url: URL) throws {
        try Data([0x01]).write(to: url)
    }

    private func open(_ model: NSManagedObjectModel, at url: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Mwallet", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }

    private func close(_ container: NSPersistentContainer) throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
