//
//  Font+Extension.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/18.
//
//  글꼴은 Wanted Sans 한 벌이다. 크기와 굵기만으로 층을 만든다.
//
//  이름이 두 갈래인 것은 가리키는 것이 다르기 때문이다.
//
//    title1~4        역할을 가리킨다 — 이 글자는 제목이다
//    display·subhead 크기를 가리킨다 — display4 는 32pt 라는 뜻이다
//
//  크기로 이름 붙인 쪽은 역할이 뒤섞여 있다. display4 여덟 곳은 모두
//  금액이고, subhead3_1 일곱 곳은 제목 다섯에 금액 둘이 섞여 있다.
//  글꼴을 바꾸거나 제목만 손볼 때 크기로는 가릴 수 없어, 제목 열아홉 곳에
//  title1~4 를 붙여 두었다.
//
//  지금은 두 갈래가 같은 얼굴로 풀린다. 그래도 표시를 남겨 두는 것은
//  '이 글자가 제목인지' 가 코드에 적혀 있어야 다음에 갈라낼 수 있어서다.
//

import Foundation
import SwiftUI

// MARK: - 제목

extension Font {
    /// 내비게이션 제목·항목 제목·여행 이름
    static let title1 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 18)
    /// 모달 제목
    static let title2 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 20)
    /// 탭·화면 제목
    static let title3 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 24)
    /// 기록 화면의 안내 문구와 받아 적은 문장
    static let title4 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 28)
}

// MARK: - 크기로 이름 붙은 것들

extension Font {
    static let display1 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 20)
    static let display2 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 24)
    static let display3 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 28)
    static let display4 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 32)

    static let subhead1 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 14)
    static let subhead2_1 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 16)
    static let subhead2_2 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 16)
    static let subhead3_1 = Font.custom(FontsManager.WantedSans.semiBold, fixedSize: 18)
    static let subhead3_2 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 18)

    static let body1 = Font.custom(FontsManager.WantedSans.regular, fixedSize: 16)
    static let body2 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 16)
    static let body3 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 18)
    static let body4 = Font.custom(FontsManager.WantedSans.regular, fixedSize: 24)

    static let caption1 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 12)
    static let caption2 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 14)
    static let caption3 = Font.custom(FontsManager.WantedSans.regular, fixedSize: 16)

    static let calendar1 = Font.custom(FontsManager.WantedSans.medium, fixedSize: 20)
    static let calendar2 = Font.custom(FontsManager.WantedSans.regular, fixedSize: 20)
}

// MARK: - _fixed 이름

// 두 갈래 모두 fixedSize 라 값이 똑같다. 예전에는 같은 정의를 두 번 적어 두어,
// 한쪽만 고치면 화면마다 크기가 어긋날 수 있었다. 이름만 남기고 값을 잇는다.

extension Font {
    static let title1_fixed = title1
    static let title2_fixed = title2
    static let title3_fixed = title3
    static let title4_fixed = title4

    static let display1_fixed = display1
    static let display2_fixed = display2
    static let display3_fixed = display3
    static let display4_fixed = display4

    static let subhead1_fixed = subhead1
    static let subhead2_1_fixed = subhead2_1
    static let subhead2_2_fixed = subhead2_2
    static let subhead3_1_fixed = subhead3_1
    static let subhead3_2_fixed = subhead3_2

    static let body1_fixed = body1
    static let body2_fixed = body2
    static let body3_fixed = body3
    static let body4_fixed = body4

    static let caption1_fixed = caption1
    static let caption2_fixed = caption2
    static let caption3_fixed = caption3

    static let calendar1_fixed = calendar1
    static let calendar2_fixed = calendar2
}
