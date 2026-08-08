//
//  Font+Extension.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/18.
//
//  글꼴은 두 벌을 쓴다.
//
//    제목    마루 부리(세리프)   — title1~4
//    그 밖   Pretendard(산세리프) — display·subhead·body·caption·calendar
//
//  가르는 기준은 크기가 아니라 역할이다.
//
//    세리프  탭·화면·모달 제목, 항목 제목, 여행 이름, 안내 문구
//    산세리프 금액, 입력란, 본문, 캡션, 달력
//
//  금액을 산세리프로 남기는 이유는 또렷함이다. 세리프의 굴곡은 읽는 맛을
//  주지만 숫자에서는 자릿수를 세기 어렵게 만든다. 금액은 대부분
//  monospacedDigit() 과 함께 쓰여 자리가 맞아야 한다.
//  입력란도 같은 이유로 산세리프다 — 고치는 글자는 또렷한 편이 낫다.
//
//  아래 이름들은 크기를 가리킨다(display4 = 32pt). 그래서 '큰 제목' 과
//  '큰 금액' 이 한 이름에 섞여 있다. 새로 더한 title1~4 는 역할을 가리킨다.
//

import Foundation
import SwiftUI

// MARK: - 제목 (마루 부리)

extension Font {
    /// 내비게이션 제목·항목 제목·여행 이름
    static let title1 = Font.custom(FontsManager.MaruBuri.semiBold, fixedSize: 18)
    /// 모달 제목
    static let title2 = Font.custom(FontsManager.MaruBuri.semiBold, fixedSize: 20)
    /// 탭·화면 제목
    static let title3 = Font.custom(FontsManager.MaruBuri.semiBold, fixedSize: 24)
    /// 기록 화면의 안내 문구와 받아 적은 문장
    static let title4 = Font.custom(FontsManager.MaruBuri.semiBold, fixedSize: 28)
}

// MARK: - 본문·숫자 (Pretendard)

extension Font {
    static let display1 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 20)
    static let display2 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 24)
    static let display3 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 28)
    static let display4 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 32)

    static let subhead1 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 14)
    static let subhead2_1 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 16)
    static let subhead2_2 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 16)
    static let subhead3_1 = Font.custom(FontsManager.Pretendard.semiBold, fixedSize: 18)
    static let subhead3_2 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 18)

    static let body1 = Font.custom(FontsManager.Pretendard.regular, fixedSize: 16)
    static let body2 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 16)
    static let body3 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 18)
    static let body4 = Font.custom(FontsManager.Pretendard.regular, fixedSize: 24)

    static let caption1 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 12)
    static let caption2 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 14)
    static let caption3 = Font.custom(FontsManager.Pretendard.regular, fixedSize: 16)

    static let calendar1 = Font.custom(FontsManager.Pretendard.medium, fixedSize: 20)
    static let calendar2 = Font.custom(FontsManager.Pretendard.regular, fixedSize: 20)
}

// MARK: - _fixed 이름

// 두 벌 모두 fixedSize 라 값이 똑같다. 예전에는 같은 정의를 두 번 적어 두어,
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
