//
//  ReceiptPhotoMigrator.swift
//  Mwallet
//
//  지출 하나에 붙던 사진 한 장(Expense.imageData)을 여러 장을 담는
//  ReceiptPhoto 로 옮긴다.
//
//  왜 옮기는가 — 사진을 한 장만 담는 칸과 여러 장을 담는 칸이 함께 있으면
//  '어느 쪽이 진짜인가' 를 읽는 자리마다 따져야 하고, 한쪽만 고치는 실수가
//  난다. 옛 칸은 비워서 쓰지 않는 것으로 못박는다.
//
//  왜 한 번만인가 — 옮기고 나면 옛 칸이 비므로 다시 돌아도 할 일이 없지만,
//  지출이 많으면 켤 때마다 훑는 값이 아깝다. 표시를 남겨 건너뛴다.
//
//  옛 칸(imageData) 자체는 모델에 남겨 둔다. 지우려면 모델 판을 하나 더
//  올려야 하고, 그 사이에 사진을 잃을 수 있다. 아무도 쓰지 않는 칸 하나가
//  사진을 잃는 것보다 낫다.
//

import CoreData
import Foundation
import OSLog

enum ReceiptPhotoMigrator {

    private static let migratedKey = "ReceiptPhotoMigrator.migrated.v1"

    static func migrateIfNeeded(in context: NSManagedObjectContext,
                                defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migratedKey) else { return }

        let moved = migrate(in: context)

        // 옮기다 실패하면 표시를 남기지 않는다. 다음에 다시 해야 한다.
        guard moved >= 0 else { return }
        defaults.set(true, forKey: migratedKey)

        if moved > 0 {
            Logger.data.debug("영수증 사진 \(moved)장을 옮겼습니다")
        }
    }

    /// 옮긴 장수. 실패하면 -1.
    @discardableResult
    static func migrate(in context: NSManagedObjectContext) -> Int {
        // Binary 속성에 nil 술어를 거는 것이라 저장소 종류를 탄다.
        // 실제 SQLite 파일에서도 걸리는지는 ReceiptPhotoDiskStoreTests 가 지킨다
        // (인메모리만으로는 이 자리를 확인할 수 없다).
        let request = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "imageData != nil")

        do {
            let expenses = try context.fetch(request)
            guard !expenses.isEmpty else { return 0 }

            var moved = 0
            for expense in expenses {
                guard let data = expense.imageData, !data.isEmpty else {
                    // 빈 데이터가 들어 있던 것도 비워 둔다. 그래야 predicate 에
                    // 다시 걸리지 않는다.
                    expense.imageData = nil
                    continue
                }

                // 이미 옮겨진 것이 있으면 손대지 않는다. 두 번 돌아도 늘지 않는다.
                if expense.photoDataList.isEmpty {
                    let photo = ReceiptPhoto(context: context)
                    photo.id = UUID()
                    photo.data = data
                    photo.order = 0
                    photo.expense = expense
                    moved += 1
                }
                expense.imageData = nil
            }

            guard context.hasChanges else { return moved }
            try context.save()
            return moved
        } catch {
            context.rollback()
            Logger.data.error("영수증 사진 이전 실패: \(error.localizedDescription, privacy: .public)")
            return -1
        }
    }
}
