//
//  NavigationUtils.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/18.
//

import SwiftUI

// UIKit 창 계층을 만지므로 메인에서만 부를 수 있다.
@MainActor
struct NavigationUtil {
  static func popToRootView() {
      let keyWindow = UIApplication.shared.connectedScenes
              .filter({$0.activationState == .foregroundActive})
              .compactMap({$0 as? UIWindowScene})
              .first?.windows
              .filter({$0.isKeyWindow}).first
    findNavigationController(viewController: keyWindow?.rootViewController)?
      .popToRootViewController(animated: false)
  }
 
  static func findNavigationController(viewController: UIViewController?) -> UINavigationController? {
    guard let viewController = viewController else {
      return nil
    }
 
    if let navigationController = viewController as? UINavigationController {
      return navigationController
    }
 
    for childViewController in viewController.children {
      return findNavigationController(viewController: childViewController)
    }
 
    return nil
  }
}
