//
//  Travel+Extension.swift
//  Mwallet
//
//  '임시 기록' 기본함을 가려내는 규칙.
//
//  예전에는 이름이 특정 이모지 문자열인지로 판별했다.
//
//      let tempTravelName = "🧚🧚🧚🂥☮︎🂾⑃☣︎%>>#"
//
//  이름은 사용자가 고칠 수 있는 값인 데다, 여행 편집 화면이 생기면서 실제로
//  고칠 수 있게 됐다. 이름을 바꾸는 순간 기본함이 일반 여행으로 바뀌어
//  지출이 갈 곳을 잃는다. 역할은 이름이 아니라 플래그로 표시한다.
//

import CoreData
import Foundation

extension Travel {

    /// 사용자에게 보여 주는 기본함 이름.
    static let defaultTravelName = "임시 기록"

    /// isDefault 로 옮기기 전에 쓰던 이름. 이미 설치된 기기의 기록을 찾을 때만 쓴다.
    static let legacyDefaultName = "🧚🧚🧚🂥☮︎🂾⑃☣︎%>>#"

    /// 사용자가 만든 일정인지. 목록·선택지에는 이것만 올린다.
    var isUserCreated: Bool { !isDefault }

    /// 화면에 적을 이름.
    var displayName: String {
        if isDefault { return Self.defaultTravelName }
        let name = name ?? ""
        return name.isEmpty ? "이름 없는 여행" : name
    }

    /// 기본함 하나를 찾는다. 없으면 nil.
    static func fetchDefault(in context: NSManagedObjectContext) -> Travel? {
        let request = Travel.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
