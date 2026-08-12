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
//  크기는 모두 사용자의 글자 크기 설정을 따른다(relativeTo). 예전에는
//  fixedSize 라 설정을 키워도 이 앱만 그대로였다 — 눈이 어두운 분에게는
//  앱이 통째로 닫힌 것이나 같다. 붙인 스타일은 크기가 가장 가까운 것이고,
//  큰 스타일일수록 접근성 크기에서 덜 커진다(제목이 본문보다 덜 불어난다).
//

import Foundation
import SwiftUI

// MARK: - 제목

extension Font {
    /// 내비게이션 제목·항목 제목·여행 이름
    static let title1 = Font.custom(FontsManager.WantedSans.semiBold, size: 18, relativeTo: .headline)
    /// 모달 제목
    static let title2 = Font.custom(FontsManager.WantedSans.semiBold, size: 20, relativeTo: .title3)
    /// 탭·화면 제목
    static let title3 = Font.custom(FontsManager.WantedSans.semiBold, size: 24, relativeTo: .title2)
    /// 기록 화면의 안내 문구와 받아 적은 문장
    static let title4 = Font.custom(FontsManager.WantedSans.semiBold, size: 28, relativeTo: .title)
}

// MARK: - 크기로 이름 붙은 것들

extension Font {
    static let display1 = Font.custom(FontsManager.WantedSans.semiBold, size: 20, relativeTo: .title3)
    static let display2 = Font.custom(FontsManager.WantedSans.semiBold, size: 24, relativeTo: .title2)
    static let display3 = Font.custom(FontsManager.WantedSans.semiBold, size: 28, relativeTo: .title)
    static let display4 = Font.custom(FontsManager.WantedSans.semiBold, size: 32, relativeTo: .largeTitle)

    static let subhead1 = Font.custom(FontsManager.WantedSans.semiBold, size: 14, relativeTo: .footnote)
    static let subhead2_1 = Font.custom(FontsManager.WantedSans.semiBold, size: 16, relativeTo: .callout)
    static let subhead2_2 = Font.custom(FontsManager.WantedSans.medium, size: 16, relativeTo: .callout)
    static let subhead3_1 = Font.custom(FontsManager.WantedSans.semiBold, size: 18, relativeTo: .headline)
    static let subhead3_2 = Font.custom(FontsManager.WantedSans.medium, size: 18, relativeTo: .headline)

    static let body1 = Font.custom(FontsManager.WantedSans.regular, size: 16, relativeTo: .callout)
    static let body2 = Font.custom(FontsManager.WantedSans.medium, size: 16, relativeTo: .callout)
    static let body3 = Font.custom(FontsManager.WantedSans.medium, size: 18, relativeTo: .headline)
    static let body4 = Font.custom(FontsManager.WantedSans.regular, size: 24, relativeTo: .title2)

    static let caption1 = Font.custom(FontsManager.WantedSans.medium, size: 12, relativeTo: .caption)
    static let caption2 = Font.custom(FontsManager.WantedSans.medium, size: 14, relativeTo: .footnote)
    static let caption3 = Font.custom(FontsManager.WantedSans.regular, size: 16, relativeTo: .callout)

    static let calendar1 = Font.custom(FontsManager.WantedSans.medium, size: 20, relativeTo: .title3)
    static let calendar2 = Font.custom(FontsManager.WantedSans.regular, size: 20, relativeTo: .title3)
}
