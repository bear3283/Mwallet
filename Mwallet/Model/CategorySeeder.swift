//
//  CategorySeeder.swift
//  Mwallet
//
//  붙박이 분류를 표에 옮겨 심는다. 한 번만 돈다.
//
//  옮기는 것이지 새로 만드는 것이 아니다. code 는 예전 rawValue 를 그대로 쓰고
//  색과 차례도 팔레트에 있던 것을 그대로 가져온다. 그래서 심고 나서도 화면은
//  달라지지 않는다 — 달라지는 것은 '이제 고칠 수 있다' 는 사실뿐이다.
//
//  붙박이가 늘어날 수 있으므로 매번 확인한다. 표에 없는 붙박이만 더하고,
//  이미 있는 것은 손대지 않는다(사용자가 이름이나 색을 고쳤을 수 있다).
//

import CoreData
import Foundation
import OSLog

enum CategorySeeder {

    static func seedIfNeeded(in context: NSManagedObjectContext) {
        let existing = Set(CategoryCatalog.all(in: context).map(\.code))
        let builtIns = ExpenseInfoCategory.selectable
        var added = 0

        for (index, category) in builtIns.enumerated() {
            let code = Int64(category.rawValue)
            guard !existing.contains(code) else { continue }

            let row = ExpenseCategory(context: context)
            row.id = UUID()
            row.code = code
            row.name = category.description
            row.order = Int16(index)
            row.isBuiltIn = true
            row.isHidden = false

            // 색은 팔레트에 있던 그대로 가져온다. 심은 뒤에도 화면이 같아야 한다.
            let color = ReceiptCategoryPalette.storedColor(for: category.description)
            row.colorHex = color.light
            row.darkColorHex = color.dark
            added += 1
        }

        guard added > 0 else { return }
        do {
            try context.save()
            Logger.data.debug("붙박이 분류 \(added)개를 표에 옮겼습니다")
        } catch {
            context.rollback()
            Logger.data.error("분류 옮기기 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
