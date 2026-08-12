//
//  ReceiptPhotoTests.swift
//  MwalletTests
//
//  영수증 사진 여러 장.
//
//  사진은 한 번 잃으면 되돌릴 수 없다. 옛 자리에서 새 자리로 옮기는 길과,
//  갈아 끼울 때 남아야 할 것이 남는지를 지킨다.
//

import CoreData
import XCTest
@testable import Mwallet

final class ReceiptPhotoTests: CoreDataTestCase {

    private func bytes(_ value: UInt8) -> Data { Data([value]) }

    // MARK: - 붙이기

    func test_붙인_차례대로_돌려준다() {
        let expense = makeExpense()
        expense.replacePhotos(with: [bytes(1), bytes(2), bytes(3)], in: context)

        XCTAssertEqual(expense.photoDataList, [bytes(1), bytes(2), bytes(3)])
        XCTAssertEqual(expense.photos.map(\.order), [0, 1, 2])
    }

    func test_갈아_끼우면_옛_사진은_남지_않는다() throws {
        let expense = makeExpense()
        expense.replacePhotos(with: [bytes(1), bytes(2)], in: context)
        try context.save()

        expense.replacePhotos(with: [bytes(9)], in: context)
        try context.save()

        XCTAssertEqual(expense.photoDataList, [bytes(9)])
        XCTAssertEqual(try context.count(for: ReceiptPhoto.fetchRequest()), 1,
                       "떼어 낸 사진이 주인 없이 남아 있습니다")
    }

    func test_빈_사진은_붙이지_않는다() {
        let expense = makeExpense()
        expense.replacePhotos(with: [bytes(1), Data(), bytes(2)], in: context)

        XCTAssertEqual(expense.photoDataList, [bytes(1), bytes(2)])
    }

    func test_사진이_없으면_아직_필요한_것으로_센다() {
        let expense = makeExpense()

        XCTAssertTrue(expense.needsPhoto)

        expense.replacePhotos(with: [bytes(1)], in: context)
        XCTAssertFalse(expense.needsPhoto)
    }

    // 지출을 지우면 사진도 함께 사라져야 한다. 남으면 저장소만 불어난다.
    func test_지출을_지우면_사진도_사라진다() throws {
        let expense = makeExpense()
        expense.replacePhotos(with: [bytes(1), bytes(2)], in: context)
        try context.save()

        context.delete(expense)
        try context.save()

        XCTAssertEqual(try context.count(for: ReceiptPhoto.fetchRequest()), 0)
    }

    // MARK: - 옛 자리에서 옮기기

    func test_한_장만_담던_사진을_옮긴다() throws {
        let expense = makeExpense()
        expense.imageData = bytes(7)
        try context.save()

        let moved = ReceiptPhotoMigrator.migrate(in: context)

        XCTAssertEqual(moved, 1)
        XCTAssertEqual(expense.photoDataList, [bytes(7)])
        XCTAssertNil(expense.imageData, "옛 자리를 비우지 않으면 어느 쪽이 진짜인지 알 수 없습니다")
    }

    // 표시가 날아가 두 번 돌더라도 사진이 늘어나면 안 된다.
    func test_두_번_옮겨도_늘어나지_않는다() throws {
        let expense = makeExpense()
        expense.imageData = bytes(7)
        try context.save()

        ReceiptPhotoMigrator.migrate(in: context)
        let second = ReceiptPhotoMigrator.migrate(in: context)

        XCTAssertEqual(second, 0)
        XCTAssertEqual(expense.photoDataList, [bytes(7)])
    }

    // 이미 새 자리에 사진이 있으면 옛 자리 것은 버린다. 앞에 끼워 넣으면
    // 사용자가 정한 차례가 말없이 바뀐다.
    func test_이미_옮겨진_지출은_건드리지_않는다() throws {
        let expense = makeExpense()
        expense.replacePhotos(with: [bytes(1), bytes(2)], in: context)
        expense.imageData = bytes(7)
        try context.save()

        let moved = ReceiptPhotoMigrator.migrate(in: context)

        XCTAssertEqual(moved, 0)
        XCTAssertEqual(expense.photoDataList, [bytes(1), bytes(2)])
        XCTAssertNil(expense.imageData)
    }

    func test_빈_데이터가_들어_있으면_그냥_비운다() throws {
        let expense = makeExpense()
        expense.imageData = Data()
        try context.save()

        let moved = ReceiptPhotoMigrator.migrate(in: context)

        XCTAssertEqual(moved, 0)
        XCTAssertTrue(expense.photoDataList.isEmpty)
        XCTAssertNil(expense.imageData)
    }

    func test_옮길_것이_없으면_아무_일도_하지_않는다() {
        makeExpense()

        XCTAssertEqual(ReceiptPhotoMigrator.migrate(in: context), 0)
    }

    func test_여러_지출을_한꺼번에_옮긴다() throws {
        for value in UInt8(1)...UInt8(3) {
            makeExpense().imageData = bytes(value)
        }
        try context.save()

        XCTAssertEqual(ReceiptPhotoMigrator.migrate(in: context), 3)
        XCTAssertEqual(try context.count(for: ReceiptPhoto.fetchRequest()), 3)
    }

    // MARK: - 표시

    func test_한_번_옮기면_다시_돌지_않는다() throws {
        let defaults = UserDefaults(suiteName: "ReceiptPhotoTests.\(UUID().uuidString)")!
        let expense = makeExpense()
        expense.imageData = bytes(7)
        try context.save()

        ReceiptPhotoMigrator.migrateIfNeeded(in: context, defaults: defaults)

        // 두 번째에는 훑지 않으므로, 새로 넣은 옛 사진이 그대로 남아 있어야 한다.
        let another = makeExpense()
        another.imageData = bytes(8)
        try context.save()
        ReceiptPhotoMigrator.migrateIfNeeded(in: context, defaults: defaults)

        XCTAssertEqual(another.imageData, bytes(8))
        XCTAssertEqual(expense.photoDataList, [bytes(7)])
    }
}

// MARK: - 디스크 저장소

/// 인메모리가 아니라 실제 SQLite 파일에서 확인한다.
///
/// 옮길 지출을 `imageData != nil` 술어로 고른다. Binary 속성에 술어를 거는
/// 일은 저장소 종류를 타는 자리라, 인메모리에서 통과했다고 실제 파일에서도
/// 된다는 보장이 없다. 사진은 한 번 두고 오면 되찾을 길이 없어 여기만
/// 파일로 연다.
final class ReceiptPhotoDiskStoreTests: XCTestCase {

    private var container: NSPersistentContainer!
    private var folder: URL!

    private var context: NSManagedObjectContext { container.viewContext }

    override func setUpWithError() throws {
        try super.setUpWithError()

        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ReceiptPhotoDiskStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let model = try XCTUnwrap(NSPersistentContainer(name: "Mwallet").managedObjectModel)
        container = NSPersistentContainer(name: "Mwallet", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: folder.appendingPathComponent("Test.sqlite"))
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    override func tearDownWithError() throws {
        container = nil
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    func test_디스크_저장소에서도_옛_사진을_옮긴다() throws {
        let expense = Expense(context: context)
        expense.info = "게스트하우스"
        expense.imageData = Data([0x01, 0x02, 0x03])
        try context.save()

        let moved = ReceiptPhotoMigrator.migrate(in: context)

        XCTAssertEqual(moved, 1, "실제 저장소에서 옮길 사진을 찾지 못했습니다")
        XCTAssertEqual(expense.photoDataList, [Data([0x01, 0x02, 0x03])])
        XCTAssertNil(expense.imageData)
    }

    // 옮기는 코드가 딛고 선 자리. 여기가 깨지면 사진을 조용히 두고 온다.
    func test_사진이_든_지출을_술어로_고를_수_있다() throws {
        let withPhoto = Expense(context: context)
        withPhoto.imageData = Data([0x09])
        _ = Expense(context: context)   // 사진 없는 것
        try context.save()

        let request = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "imageData != nil")

        XCTAssertEqual(try context.fetch(request).count, 1,
                       "Binary 속성 술어가 실제 저장소에서 듣지 않습니다")
    }
}
