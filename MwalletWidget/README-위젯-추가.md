# 빠른 지출 기록 위젯 추가 절차

`MwalletWidget.swift`는 홈/잠금 화면에서 한 번에 앱의 **기록 탭**을 여는 위젯입니다.
탭하면 `mwallet://record` 딥링크로 기록 화면이 바로 열립니다. (앱 쪽 딥링크는 이미 반영됨)

데이터를 직접 쓰지 않는 **딥링크 방식**이라 App Group·공유 저장소가 필요 없습니다.

## Xcode에서 타깃 추가 (약 1분)

1. Xcode에서 `Mwallet.xcodeproj` 열기.
2. 메뉴 **File ▸ New ▸ Target…**
3. **Widget Extension** 선택 → Next.
4. 설정:
   - **Product Name**: `MwalletWidget`
   - **Include Live Activity**: 체크 해제
   - **Include Configuration App Intent**: 체크 해제 (이 위젯은 설정이 없는 StaticConfiguration)
   - **Team**: 앱과 동일
   - **Embed in Application**: `Mwallet`
   - Finish.
5. "Activate "MwalletWidget" scheme?" 물으면 **Cancel** (앱 스킴 유지).

## 생성된 파일을 이 파일로 교체

Widget Extension을 만들면 Xcode가 기본 위젯 파일(`MwalletWidget.swift` 또는
`MwalletWidgetBundle.swift` 등)을 자동 생성합니다. 그 안에도 `@main`이 있어
**두 개의 `@main`이 충돌**합니다. 아래 중 하나로 정리하세요.

- **간단**: 자동 생성된 위젯 소스 파일들의 내용을 지우고, 이 폴더의
  `MwalletWidget.swift` 내용을 붙여넣기. (또는 자동 생성 파일 삭제 후
  이 `MwalletWidget.swift`를 위젯 타깃에 **Add Files…** 로 추가하고
  Target Membership을 `MwalletWidget`으로 지정)

## 확인 사항

- 위젯 타깃 **Deployment Target = iOS 17.0** (앱과 동일). `containerBackground` 사용.
- 위젯 타깃 Bundle ID는 Xcode가 자동 지정 (예: `com.bear3745.Mwallet.app.MwalletWidget`).
- 앱을 한 번 빌드·실행한 뒤, 홈 화면 길게 눌러 **+** ▸ Mwallet ▸ "빠른 지출 기록" 추가.
- 잠금 화면 위젯(원형/가로)도 지원합니다.

## 동작

- 홈/잠금 화면 위젯을 누르면 앱이 열리며 곧장 **기록 탭**으로 이동합니다.
  (위젯 탭은 신뢰된 호출이라 "여시겠습니까?" 확인창 없이 바로 열립니다)

## 더 빠르게: 위젯에서 바로 기록 폼 열기 (선택, 추후)

지금은 기록 탭(음성 버튼)까지 엽니다. 위젯을 눌렀을 때 **수기 기록 폼**을
곧바로 띄우려면 `mwallet://record/manual` 같은 링크를 추가하고, 앱에서
그 호스트를 받아 `ManualRecordView`를 여는 신호를 주면 됩니다. 필요 시 이어서
작업할 수 있습니다.
