//
//  FontsManager.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/16.
//

import Foundation
import SwiftUI

struct FontsManager {

    /// 앱 전체가 이 한 벌을 쓴다.
    ///
    /// Wanted Sans v1.003. 자간이 좁고 획 끝이 각져, 같은 크기에서도 글자가
    /// 크고 단단하게 읽힌다. 여행 이름처럼 긴 말이 덜 잘리고 금액의 자릿수가
    /// 또렷하다 — 이 앱은 두 가지가 화면마다 나온다.
    ///
    /// 굵기는 셋만 둔다. 새 굵기를 쓰려면 `.otf` 파일과 Info.plist 의
    /// `UIAppFonts`, 그리고 이 파일 세 곳을 함께 고쳐야 한다. 하나라도 빠지면
    /// 글꼴이 조용히 시스템 기본으로 떨어진다 — 빌드는 그대로 통과하므로
    /// 화면을 봐야 알 수 있다.
    struct WantedSans {
        static let regular = "WantedSans-Regular"
        static let medium = "WantedSans-Medium"
        static let semiBold = "WantedSans-SemiBold"
    }
}
