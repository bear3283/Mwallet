//
//  CategoryCatalog.swift
//  Mwallet
//
//  분류의 표. '3' 이라는 숫자를 '식비' 와 그 색으로 푸는 곳이다.
//
//  왜 표를 따로 두는가 — 분류는 여태 열거형(ExpenseInfoCategory)이었고,
//  지출과 예산에는 그 rawValue 숫자가 박혀 저장된다. 사용자가 분류를 만들려면
//  목록이 코드가 아니라 데이터여야 하는데, 저장된 숫자까지 바꾸면 이미 쌓인
//  기록이 통째로 어긋난다.
//
//  그래서 숫자는 그대로 둔다. 붙박이 분류는 예전 rawValue(-1, 0…8)를 code 로
//  그대로 물려받고, 사용자가 만든 분류는 100번부터 받는다. 지출은 예나 지금이나
//  숫자 하나만 들고 있고, 그 숫자를 이름과 색으로 푸는 일만 이 표가 맡는다.
//

import CoreData
import Foundation
import OSLog
import SwiftUI

enum CategoryCatalog {

    /// 사용자가 만든 분류가 받기 시작하는 번호.
    ///
    /// 붙박이가 8번까지 쓰고 있어 여유를 두고 100 부터 시작한다. 나중에 붙박이를
    /// 몇 개 더하더라도 사용자 분류와 부딪히지 않는다.
    static let firstUserCode: Int64 = 100

    // MARK: - 읽기

    /// 화면에 올릴 분류. 감춘 것은 뺀다.
    static func visible(in context: NSManagedObjectContext) -> [ExpenseCategory] {
        all(in: context).filter { !$0.isHidden }
    }

    /// 감춘 것까지 모두. 차례대로.
    static func all(in context: NSManagedObjectContext) -> [ExpenseCategory] {
        let request = ExpenseCategory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseCategory.order, ascending: true)]
        do {
            return try context.fetch(request)
        } catch {
            Logger.data.error("분류 목록 조회 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func category(code: Int64, in context: NSManagedObjectContext) -> ExpenseCategory? {
        all(in: context).first { $0.code == code }
    }

    /// 숫자를 이름으로. 표에 없으면 열거형이 알던 이름으로 되돌아간다.
    ///
    /// 표가 아직 안 채워진 순간(첫 실행의 아주 이른 시점)에도 화면이 빈
    /// 이름을 보이지 않도록 남겨 둔 길이다.
    static func name(code: Int64, in context: NSManagedObjectContext) -> String {
        category(code: code, in: context)?.name
            ?? ExpenseInfoCategory(rawValue: Int(code))?.description
            ?? ExpenseInfoCategory.unknown.description
    }

    // MARK: - 쓰기

    /// 새 분류를 만든다. 번호는 쓰이지 않은 것 중 가장 작은 100번대를 준다.
    @discardableResult
    static func add(name: String, color: CategoryColor,
                    in context: NSManagedObjectContext) -> ExpenseCategory {
        let existing = all(in: context)
        let nextCode = max(firstUserCode, (existing.map(\.code).max() ?? 0) + 1)
        let nextOrder = (existing.map(\.order).max() ?? 0) + 1

        let category = ExpenseCategory(context: context)
        category.id = UUID()
        category.code = nextCode
        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.colorHex = color.light
        category.darkColorHex = color.dark
        category.order = nextOrder
        category.isBuiltIn = false
        category.isHidden = false
        return category
    }

    /// 이 분류를 쓰고 있는 지출의 수. 지우기 전에 묻는다.
    static func usageCount(of category: ExpenseCategory,
                           in context: NSManagedObjectContext) -> Int {
        let request = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "category == %lld", category.code)
        return (try? context.count(for: request)) ?? 0
    }

    /// 분류를 지운다.
    ///
    /// 붙박이는 지우지 않고 감춘다. 이미 그 숫자로 저장된 기록이 있는데 표에서
    /// 지워 버리면 이름을 풀 수 없는 지출이 생긴다. 감추면 새로 고를 때만
    /// 빠지고 옛 기록은 그대로 읽힌다.
    ///
    /// 사용자가 만든 분류도 쓰이고 있으면 감춘다. 아무도 안 쓸 때만 실제로 지운다.
    static func remove(_ category: ExpenseCategory, in context: NSManagedObjectContext) {
        if category.isBuiltIn || usageCount(of: category, in: context) > 0 {
            category.isHidden = true
        } else {
            context.delete(category)
        }
    }
}

// MARK: - 색

/// 밝은 화면과 어두운 화면에서 쓸 색 한 쌍.
struct CategoryColor: Equatable {

    /// "RRGGBB" 여섯 자리. 앞의 # 는 붙이지 않는다.
    let light: String
    let dark: String

    init(light: String, dark: String? = nil) {
        let cleaned = CategoryColor.normalize(light)
        self.light = cleaned
        self.dark = dark.map(CategoryColor.normalize) ?? CategoryColor.derivedDark(from: cleaned)
    }

    static func normalize(_ hex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        return trimmed.count == 6 ? trimmed : "9A9A9A"
    }

    /// 어두운 화면용 색을 밝은 색에서 만든다.
    ///
    /// 어두운 바탕에서는 같은 색이 더 어둡게 읽혀 묻힌다. 사용자가 한 가지만
    /// 고르게 하고 나머지는 여기서 만든다 — 두 번 고르게 하면 대개 한쪽을
    /// 대충 정한다.
    static func derivedDark(from light: String) -> String {
        let rgb = CategoryColor.components(light)

        // 밝은 쪽으로 15% 당긴다. 흰색까지 가지 않도록 상한을 둔다.
        func lift(_ value: Double) -> Int {
            let raised: Double = value + (1.0 - value) * 0.15
            let scaled: Double = raised * 255.0
            return Swift.min(Swift.max(Int(scaled), 0), 255)
        }
        return String(format: "%02X%02X%02X",
                      lift(Double(rgb.red)), lift(Double(rgb.green)), lift(Double(rgb.blue)))
    }

    /// 0~1 로 정규화한 빨강·초록·파랑.
    struct Components: Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
    }

    static func components(_ hex: String) -> Components {
        let value: UInt32 = UInt32(normalize(hex), radix: 16) ?? 0x9A9A9A
        return Components(red: CGFloat((value >> 16) & 0xFF) / 255.0,
                          green: CGFloat((value >> 8) & 0xFF) / 255.0,
                          blue: CGFloat(value & 0xFF) / 255.0)
    }

    var swiftUIColor: Color {
        // 클로저 안에서 self 를 잡지 않도록 값을 먼저 꺼내 둔다.
        let lightRGB = CategoryColor.components(light)
        let darkRGB = CategoryColor.components(dark)
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? darkRGB : lightRGB
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }
}
