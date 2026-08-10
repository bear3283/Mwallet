//
//  RecordLayout.swift
//  Mwallet
//
//  기록 화면의 여백 값. 화면 크기에 따라 두 벌 중 하나를 쓴다.
//
//  SE 계열(4.7인치)은 세로가 짧아 넉넉한 여백으로는 아래가 잘린다.
//  예전에는 화면 전체를 두 벌 적어 두고 갈랐는데, 54줄 중 46줄이 같았고
//  다른 것은 아래 네 값뿐이었다. 한쪽만 고치면 작은 화면에서만 어긋나는
//  일이 생겨, 짜임은 한 벌로 두고 값만 갈아 끼우기로 했다.
//

import SwiftUI

struct RecordLayout {

    /// 맨 위 여백. 여행 선택 위쪽이다.
    let topInset: CGFloat
    /// '직접 기록' 위의 틈.
    let manualTopGap: CGFloat
    /// '직접 기록' 아래로 남겨 두는 최소 여백.
    let manualBottomInset: CGFloat
    /// 떠 있는 탭바가 녹음 버튼을 가리지 않도록 비우는 높이.
    ///
    /// 탭바 높이를 코드로 구할 수 있으면 이 값을 대신할 수 있다.
    let tabBarInset: CGFloat

    static let compact = RecordLayout(topInset: 24,
                                      manualTopGap: 20,
                                      manualBottomInset: 24,
                                      tabBarInset: 18 + 43)

    static let regular = RecordLayout(topInset: 60,
                                      manualTopGap: 40,
                                      manualBottomInset: 40,
                                      tabBarInset: 18 + 83)

    /// 375×667(4.7인치)만 좁은 쪽을 쓴다. 그 밖에는 넉넉한 쪽이다.
    static var forCurrentScreen: RecordLayout {
        let size = UIScreen.main.bounds.size
        let isCompact = abs(size.width - 375) < 2 && abs(size.height - 667) < 2
        return isCompact ? .compact : .regular
    }
}
