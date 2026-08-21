//
//  AppDestination.swift
//  Mwallet
//
//  밖에서 들어오는 링크가 가리키는 탭.
//
//  위젯과 단축어가 `mwallet://budget` 같은 링크로 앱을 연다. 어느 탭인지
//  푸는 일을 여는 쪽(MwalletApp)에 두면, 들어오는 문이 늘 때마다 같은 표가
//  한 벌씩 늘어난다. 여기 한 곳에서 푼다.
//
//  ─────────────────────────────────────────────────────────────
//  홈 화면 바로가기(앱 아이콘 길게 누르기)는 여기 없다. 붙이려다 뺐다.
//
//  Info.plist 에 `UIApplicationShortcutItems` 를 적으면 메뉴에는 나온다.
//  누를 때 우리 코드까지 오지 않는 것이 문제다. SwiftUI 의 App 생명주기에서는
//  네 갈래를 모두 막아 두었다 (iOS 26 · Xcode 26.5 에서 확인):
//
//    · `configurationForConnecting` 으로 씬 델리게이트를 끼움
//        → SwiftUI 가 자기 것(AppSceneDelegate)을 앉히고 우리 것을 버린다
//    · 앱 델리게이트의 `performActionFor`
//        → `SwiftUI.AppDelegate` 가 감싸고 있어 넘어오지 않는다
//    · Info.plist 의 `UIApplicationSceneManifest` 에 델리게이트를 직접 선언
//        → 매니페스트는 실리는데(생성 설정을 끄면) 여전히 불리지 않는다
//    · XCUITest 로 실제 눌러 확인
//        → 이 환경에서는 Springboard 요소를 하나도 읽지 못한다
//
//  메뉴에 보이는데 눌러도 아무 일이 없는 편이 아예 없는 것보다 나쁘다.
//  그래서 넣지 않았다. 다시 손댈 사람은 위 네 갈래를 다시 파지 말 것.
//  ─────────────────────────────────────────────────────────────
//

import Foundation

enum AppDestination: CaseIterable {
    case travel
    case ledger
    case record
    case receipt

    /// 이 곳에 해당하는 탭 번호.
    var tab: Int {
        switch self {
        case .travel: MainViewModel.Tab.travel
        case .ledger: MainViewModel.Tab.ledger
        case .record: MainViewModel.Tab.record
        case .receipt: MainViewModel.Tab.receipt
        }
    }

    /// `mwallet://record` 같은 링크에서.
    ///
    /// 예결산 탭은 링크에서 `budget` 으로 불려 왔다. 이미 홈 화면에 놓인
    /// 위젯이 그 이름으로 열고 있어 떨어뜨릴 수 없으므로, 안에서 쓰는
    /// `ledger` 와 둘 다 받는다.
    init?(deepLink url: URL) {
        guard url.scheme == "mwallet" else { return nil }
        switch url.host {
        case "travel": self = .travel
        case "budget", "ledger": self = .ledger
        case "record": self = .record
        case "receipt": self = .receipt
        default: return nil
        }
    }
}
