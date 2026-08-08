//
//  FontsManager.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/16.
//

import Foundation
import SwiftUI

struct FontsManager {

    /// 본문·숫자·값 표시. 획이 고르고 자간이 일정해 금액이 또렷하게 읽힌다.
    struct Pretendard {
        static let medium = "Pretendard-Medium"
        static let regular = "Pretendard-Regular"
        static let semiBold = "Pretendard-SemiBold"
    }

    /// 제목. 세리프의 굴곡이 '손으로 적은 기록' 쪽으로 인상을 끈다.
    ///
    /// 네이버 마루 부리 v2.000. 개인·기업 모두 무료이며 앱에 넣어 배포할 수 있다.
    /// 자세한 것은 DesignSystem/Fonts/LICENSE.md 를 본다.
    struct MaruBuri {
        static let semiBold = "MaruBuriot-SemiBold"
    }
}
