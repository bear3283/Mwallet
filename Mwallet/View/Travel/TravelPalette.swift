//
//  TravelPalette.swift
//  Mwallet
//
//  여행마다 색 하나를 준다.
//
//  여행 탭은 위에 지도, 아래에 여행 그리드가 놓인다. 둘을 잇는 것이 이 색이다 —
//  지도의 점과 그리드 칸의 테두리가 같은 색이면, 어느 점이 어느 여행인지
//  설명 없이 읽힌다.
//
//  색은 목록 차례대로 준다. 여행이 여덟 개 이하이면 서로 같은 색이 나오지
//  않는다. 지도에서 색이 곧 이름표이므로 겹치지 않는 것이 가장 중요하다.
//  (여행 ID 로 색을 뽑으면 여행을 더해도 색이 안 변하지만, 우연히 두 여행이
//  같은 색을 받을 수 있어 지도가 읽히지 않는다)
//
//  카테고리 색과는 다른 계열을 쓴다. 여행 상세의 지도는 카테고리로 색을
//  나누므로, 두 지도가 같은 색을 다른 뜻으로 쓰면 헷갈린다.
//

import SwiftUI

enum TravelPalette {

    /// 지도 위 작은 점으로 찍혀도 서로 구별되도록 채도를 높게 잡았다.
    private static let colors: [Color] = [
        Color(red: 0.894, green: 0.341, blue: 0.180),   // 주홍
        Color(red: 0.106, green: 0.604, blue: 0.667),   // 청록
        Color(red: 0.482, green: 0.369, blue: 0.655),   // 보라
        Color(red: 0.910, green: 0.639, blue: 0.239),   // 호박
        Color(red: 0.180, green: 0.525, blue: 0.671),   // 쪽빛
        Color(red: 0.820, green: 0.286, blue: 0.357),   // 진홍
        Color(red: 0.243, green: 0.557, blue: 0.353),   // 초록
        Color(red: 0.710, green: 0.396, blue: 0.114)    // 갈색
    ]

    static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}
