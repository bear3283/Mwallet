//
//  AppShortcuts.swift
//  Mwallet
//
//  앱 아이콘을 길게 눌러 곧장 기록으로 들어가는 길.
//
//  ─────────────────────────────────────────────────────────────
//  왜 다시 시도하는가
//
//  AppDestination.swift 머리에 이 길을 넣으려다 뺀 기록이 있다. 거기 적힌
//  네 갈래는 모두 UIKit 의 홈 화면 바로가기(UIApplicationShortcutItems)
//  계열이고, 넷 다 SwiftUI 의 App 생명주기가 델리게이트를 감싸고 넘겨주지
//  않아 막혔다.
//
//  이것은 다섯째 갈래다. AppShortcutsProvider 는 UIKit 델리게이트를 거치지
//  않는다 — 시스템이 AppIntents 로 곧장 부르고, 그 호출은 SwiftUI 가
//  가로챌 자리가 없다. 위젯이 이미 AppIntents 로 지출을 담고 있으니
//  (LogExpenseIntent) 배관도 새로 까는 것이 아니다.
//
//  이 길이 확실히 주는 것: Spotlight 검색과 Siri 에 지름길이 선다.
//  확인해야 하는 것: 홈 화면 아이콘을 길게 눌렀을 때의 메뉴에도 서는지.
//  그것까지 되면 원래 하려던 일이 끝난다.
//  ─────────────────────────────────────────────────────────────
//
//  지금은 기록 하나만 둔다. 되는지 먼저 보고 나머지 셋을 잇는다 — 메뉴에
//  뜨지 않는 길이라면 넷을 만들어 두어도 넷 다 뜨지 않는다.
//

import AppIntents

/// 기록 탭을 연다.
///
/// openAppWhenRun 이 true 라 시스템이 앱을 띄우고 그 안에서 perform 을 부른다.
/// 그래서 여기서 화면 상태를 바로 만질 수 있다 — 링크(mwallet://record)처럼
/// 문자열을 거쳐 되풀이해 풀 필요가 없다.
struct OpenRecordIntent: AppIntent {

    static let title: LocalizedStringResource = "지출 기록하기"
    static let description = IntentDescription("기록 탭을 열어 말하거나 직접 적을 수 있게 합니다.")

    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        MainViewModel.shared.selection = AppDestination.record.tab
        return .result()
    }
}

struct MwalletShortcuts: AppShortcutsProvider {

    /// 지름길 묶음.
    ///
    /// phrases 에는 반드시 `\(.applicationName)` 이 들어가야 한다. 없으면
    /// 빌드는 되는데 시스템이 그 지름길을 등록하지 않는다.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecordIntent(),
            phrases: [
                "\(.applicationName)에 지출 기록",
                "\(.applicationName)으로 기록하기",
                "Record spending in \(.applicationName)"
            ],
            shortTitle: "지출 기록",
            systemImageName: "mic.fill"
        )
    }
}
