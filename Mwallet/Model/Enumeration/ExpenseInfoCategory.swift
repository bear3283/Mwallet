//
//  ExpenseInfoCategory.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

import SwiftUI

enum ExpenseInfoCategory: Int {
    case unknown = -1
    case plane
    case room
    case transportation
    case food
    case tour
    case shopping
    case gift
    // 선교 재정용으로 추가. 기존 rawValue(0~6, -1)는 그대로 두어
    // 이미 저장된 기록의 카테고리가 어긋나지 않게 한다.
    case ministry   // 7
    case offering   // 8

    /// 저장하고 맞춰 보는 이름. **번역하지 않는다.**
    ///
    /// 이 값은 화면 글자가 아니라 열쇠다. 분류표(ExpenseCategory.name)에 이대로
    /// 적혀 저장되고, 색 팔레트가 이 이름으로 색을 찾고, from(description:) 이
    /// 이 이름으로 되짚고, 위젯 스냅샷과 CSV 에도 이대로 실린다.
    ///
    /// 여기를 기기 언어로 바꾸면 독일어 기기에서 만든 기록의 분류를 한국어 기기가
    /// 못 알아본다. 같은 iCloud 를 쓰는 두 기기가 서로 다른 분류를 보게 된다.
    /// 화면에 보일 이름은 visibleDescription 이다.
    var description: String {
        switch self {
        case .plane:
            return "항공"
        case .room:
            return "숙소"
        case .transportation:
            return "교통"
        case .food:
            return "식비"
        case .tour:
            return "관광"
        case .shopping:
            return "쇼핑"
        case .gift:
            return "선물"
        case .ministry:
            return "사역비"
        case .offering:
            return "헌금"
        case .unknown:
            return "기타"
        }
    }

    // 색은 ReceiptCategoryPalette 한곳에서만 정한다.
    // 그 팔레트는 도넛 링의 인접쌍 기준으로 색각 이상 분리도를 검증했고,
    // 여기서 따로 색을 만들면 화면마다 같은 카테고리가 다른 색으로 보인다.
    var color: Color {
        ReceiptCategoryPalette.color(for: description)
    }

    /// 화면에 보일 이름. 기기 언어를 따른다.
    ///
    /// description 과 글자가 같아 보여도 쓰임이 다르다. 저장에는 description 을,
    /// 화면에는 이것을 쓴다.
    var visibleDescription: String {
        switch self {
        case .plane:
            return String(localized: "항공")
        case .room:
            return String(localized: "숙소")
        case .transportation:
            return String(localized: "교통")
        case .food:
            return String(localized: "식비")
        case .tour:
            return String(localized: "관광")
        case .shopping:
            return String(localized: "쇼핑")
        case .gift:
            return String(localized: "선물")
        case .ministry:
            return String(localized: "사역비")
        case .offering:
            return String(localized: "헌금")
        default:
            return String(localized: "기타")
        }
    }

    /// 저장된 이름을 화면에 보일 이름으로 푼다. 붙박이가 아니면 nil.
    ///
    /// 분류표에는 붙박이도 사용자가 만든 것도 이름 문자열로 나란히 저장된다.
    /// 둘을 가르는 자리가 여기다 — 붙박이는 번역하고, 사용자가 손수 지은
    /// 이름은 그 사람이 적은 그대로 두어야 한다.
    static func localizedName(forStored stored: String) -> String? {
        // selectable 에 unknown(기타)까지 들어 있어 붙박이 열 가지가 모두 걸린다.
        selectable.first { $0.description == stored }?.visibleDescription
    }
  
    var manualRecordImageString: String {
        switch self {
        case .plane:
            return "manualRecordCategoryPlane"
        case .room:
            return "manualRecordCategoryRoom"
        case .transportation:
            return "manualRecordCategoryTransportation"
        case .food:
            return "manualRecordCategoryFood"
        case .tour:
            return "manualRecordCategoryFun"
        case .shopping:
            return "manualRecordCategoryShopping"
        case .gift:
            return "manualRecordCategoryGift"
        default:
            return "manualRecordCategoryUnknown"
        }
    }
    
    var modalImageString: String {
        switch self {
        case .plane:
            return "modalCategoryPlane"
        case .room:
            return "modalCategoryRoom"
        case .transportation:
            return "modalCategoryTransportation"
        case .food:
            return "modalCategoryFood"
        case .tour:
            return "modalCategoryFun"
        case .shopping:
            return "modalCategoryShopping"
        case .gift:
            return "modalCategoryGift"
        default:
            return "modalCategoryUnknown"
        }
    }
      
    // 새로 추가한 항목은 전용 에셋 아이콘이 없어 SF Symbol 로 그린다.
    // 기존 항목은 nil 을 돌려주어 modalImageString(에셋)을 그대로 쓰게 한다.
    var modalSymbolName: String? {
        switch self {
        case .ministry:
            return "cross.fill"
        case .offering:
            return "heart.fill"
        default:
            return nil
        }
    }

    /// 저장용 이름. 표에 없는 숫자면 '전체'. **번역하지 않는다** — description 과 같은 열쇠다.
    static func descriptionFor(rawValue: Int) -> String {
        return ExpenseInfoCategory(rawValue: rawValue)?.description ?? "전체"
    }

    /// 저장된 이름을 화면에 보일 이름으로. 붙박이면 번역하고, 아니면 적힌 그대로.
    ///
    /// 분류 이름이 문자열로 오가는 자리(영수증 요약, 예결산 막대, CSV 를 뺀 화면들)
    /// 에서 마지막에 한 번 거치는 문이다.
    static func displayName(forStored stored: String) -> String {
        if stored == "전체" { return String(localized: "전체") }
        return localizedName(forStored: stored) ?? stored
    }

    // 사용자가 고를 수 있는 카테고리. 영수증 입력·예결산이 같은 목록을 쓴다.
    // 여행이면 누구나 쓰는 항목을 앞에 두고, 사역비·헌금처럼 쓰는 사람이
    // 정해진 항목은 뒤로 보낸다. unknown(기타)은 맨 끝이다.
    static let selectable: [ExpenseInfoCategory] = [
        .food, .room, .transportation, .plane, .shopping, .tour, .gift, .ministry, .offering, .unknown
    ]

    static func from(description: String) -> ExpenseInfoCategory {
        selectable.first { $0.description == description } ?? .unknown
    }

    /// 분류 모델이 돌려주는 영문 라벨을 카테고리로 옮긴다.
    ///
    /// 라벨 이름은 모델을 학습시킬 때 정해진 것이라 이 enum 과 짝을 이룬다.
    /// 뷰모델에 두면 모델을 쓰는 화면이 늘 때마다 같은 표를 옮겨 적게 된다.
    init(modelLabel: String) {
        switch modelLabel {
        case "plane": self = .plane
        case "room": self = .room
        case "transportation": self = .transportation
        case "food": self = .food
        case "tour": self = .tour
        case "shopping": self = .shopping
        case "gift": self = .gift
        default: self = .unknown
        }
    }
}
