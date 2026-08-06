//
//  Gesture+Extension.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/02.
//

import Foundation
import SwiftUI

extension UIApplication {
    func hideKeyboard() {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        guard let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }) else { return }
        // 델리게이트는 두지 않는다. 인식기의 기본 동작이 이미 '동시 인식 안 함'이라
        // 별도 델리게이트(shouldRecognizeSimultaneouslyWith → false)는 같은 결과였고,
        // UIApplication 을 시스템 프로토콜에 소급 적합시키는 취약한 패턴만 남겼다.
        let tapRecognizer = UITapGestureRecognizer(target: keyWindow, action: #selector(UIView.endEditing))
        tapRecognizer.cancelsTouchesInView = false
        keyWindow.addGestureRecognizer(tapRecognizer)
    }
}
