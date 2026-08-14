//
//  ExpenseCategory+Extension.swift
//  Mwallet
//
//  분류 한 줄을 화면에서 쓰기 좋게 감싼다.
//
//  Core Data 가 만든 속성은 모두 옵셔널이다(CloudKit 이 그렇게 요구한다).
//  화면마다 물음표를 붙이는 대신 여기서 한 번 푼다.
//

import CoreData
import Foundation

extension ExpenseCategory {

    /// 화면에 적을 이름. 비어 있으면 번호로 되짚는다.
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return ExpenseInfoCategory(rawValue: Int(code))?.description
            ?? ExpenseInfoCategory.unknown.description
    }

    /// 밝은 화면과 어두운 화면의 색 한 쌍.
    var color: CategoryColor {
        CategoryColor(light: colorHex ?? "9A9A9A", dark: darkColorHex)
    }
}
