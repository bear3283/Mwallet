//
//  ReceiptCategoryPalette.swift
//  Mwallet
//
//  카테고리별 고정 색상표.
//  색은 항목의 순위가 아니라 카테고리 자체에 붙는다. 필터로 항목이 줄었을 때
//  남은 조각들이 다른 색으로 다시 칠해지면 사용자가 같은 화면을 못 알아본다.
//
//  색 순서는 도넛 링의 인접쌍 기준으로 검증했다.
//  (색각 이상 최소 ΔE 9.1 light / 8.4 dark, 정상시야 19.6 / 19.3, 링 순환 포함)
//  라이트 모드에서 aqua·yellow·magenta 는 배경 대비가 3:1 미만이므로
//  범례에 금액을 함께 적어 색만으로 구분하지 않게 한다.
//

import SwiftUI

enum ReceiptCategoryPalette {

    // 링에 놓이는 순서이자 색 배정 순서. 바꾸면 검증 결과가 무효가 된다.
    // 기록 탭과 같은 목록(ExpenseInfoCategory.selectable)을 쓴다.
    static let order = ExpenseInfoCategory.selectable.map { $0.description }
    static let fallback = ExpenseInfoCategory.unknown.description

    // 마지막 '기타'는 채도 낮은 회색이라 나머지 8색과 성격이 다르다.
    // 앞 8색은 도넛 링의 인접쌍(순환 포함) 기준으로 색각 이상 분리도를 검증했다.
    private static let hexes: [(light: UInt32, dark: UInt32)] = [
        (0x2A78D6, 0x3987E5),   // 식비   blue
        (0xEB6834, 0xD95926),   // 숙소   orange
        (0x1BAF7A, 0x199E70),   // 교통   aqua
        (0xEDA100, 0xC98500),   // 항공   yellow
        (0xE87BA4, 0xD55181),   // 사역비 magenta
        (0x008300, 0x008300),   // 헌금   green
        (0x4A3AA7, 0x9085E9),   // 쇼핑   violet
        (0xE34948, 0xE66767),   // 선물   red
        (0x9A9A9A, 0x8A8A8A)    // 기타   gray
    ]

    static func color(for category: String) -> Color {
        let index = order.firstIndex(of: category) ?? (order.count - 1)
        let pair = hexes[min(index, hexes.count - 1)]
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        })
    }

    // 기본 목록에 없는 카테고리(사용자가 직접 만든 것)는 '기타' 로 접는다.
    // 색을 새로 만들어 붙이면 검증한 인접쌍이 깨진다.
    static func bucket(for category: String) -> String {
        order.contains(category) ? category : fallback
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
