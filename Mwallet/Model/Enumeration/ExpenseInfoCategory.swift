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

    var visibleDescription: String {
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
        default:
            return "기타"
        }
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

    static func descriptionFor(rawValue: Int) -> String {
        return ExpenseInfoCategory(rawValue: rawValue)?.description ?? "전체"
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
}
