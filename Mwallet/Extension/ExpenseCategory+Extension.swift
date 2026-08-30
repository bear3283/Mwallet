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
    ///
    /// 붙박이 분류는 표에 한국어로 저장돼 있다 — 그 이름이 저장·색·CSV 의
    /// 열쇠라서 언어를 따라 바꿀 수 없다. 그래서 화면에 내보내기 직전
    /// 여기서 기기 언어로 옮긴다. 사용자가 손수 지은 이름은 건드리지 않는다.
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return isBuiltIn ? ExpenseInfoCategory.displayName(forStored: trimmed) : trimmed
        }
        return ExpenseInfoCategory(rawValue: Int(code))?.visibleDescription
            ?? ExpenseInfoCategory.unknown.visibleDescription
    }

    /// 밝은 화면과 어두운 화면의 색 한 쌍.
    var color: CategoryColor {
        CategoryColor(light: colorHex ?? "9A9A9A", dark: darkColorHex)
    }
}
