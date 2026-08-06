# Mwallet 위젯 — 현재 상태와 남은 확인

위젯 타깃·App Group·코드 연결이 **대부분 완료**됐습니다. 아래 "남은 확인"만 하면 됩니다.

## 위젯 구성 (각 크기 제한됨)

| 위젯 | 역할 | 지원 크기 |
|---|---|---|
| **예산** | 이번 여행 예산·집행률 | `systemSmall`, `systemMedium` |
| **결산** | 예산 대비 집행·잔액 + 카테고리 | `systemMedium` |
| **지출 기록** | 눌러서 기록(딥링크) · 중형은 프리셋 큐 기록 | `systemSmall`, `systemMedium`, `accessoryCircular` |
| **영수증 등록** | 미등록 영수증 N건 → 등록 | `systemSmall`, `accessoryCircular` |

## 이미 완료된 것 ✅

- 위젯 익스텐션 타깃 **MwalletWidgetExtension** 생성.
- App Group **`group.com.Mwallet.app`** — 앱·위젯 두 엔타이틀먼트에 반영.
- 위젯 코드 4종 작성(`MwalletWidget/MwalletWidget.swift`). 공유 계약을 이 파일에
  **임베드**해 위젯 타깃이 추가 파일 없이 컴파일됨.
- Xcode 생성 예제(`MwalletWidgetBundle.swift`·`MwalletWidgetControl.swift`)는 비움
  (`@main` 중복·iOS 18 Control 제거).
- 위젯 배포 타깃 **iOS 17.0** 으로 통일(기본 27.0 → 17.0).
- 앱 타깃에 `Shared/MwalletShared.swift`·`Shared/MwalletBridge.swift` 추가.
- 앱 연결: 예결산 화면에서 스냅샷 발행(`BudgetView.publishWidgetSnapshot`),
  앱 활성화 시 위젯 큐 반영(`MwalletApp` scenePhase).
- 딥링크: `mwallet://record` · `mwallet://receipt` · `mwallet://budget`.

**앱 스킴 빌드로 앱+위젯 전체가 컴파일됨을 확인했습니다.**

## ⚠️ 하지 말 것

- `Shared/MwalletShared.swift` 를 **위젯 타깃에는 추가하지 마세요.** 위젯은 같은 계약을
  자체 파일에 임베드하고 있어, 추가하면 타입 중복으로 빌드가 깨집니다.
  (앱 타깃에만 있습니다 — 그대로 두세요.)

## 남은 확인 (Xcode에서)

1. **서명 확인** — Xcode에서 프로젝트 열기 → **Mwallet(앱) 타깃 ▸ Signing & Capabilities**
   에 **App Groups ▸ `group.com.Mwallet.app`** 이 보이는지 확인. 서명 오류가 뜨면 Team이
   본인 계정인지 보고, 자동 서명이 프로비저닝을 갱신하도록 둡니다(인터넷 필요).
   위젯 타깃도 같은 그룹이 체크돼 있는지 확인.
2. **빌드 & 실행** — 스킴을 **Mwallet**로 두고 실행.
3. **예결산 탭 한 번 열기** — 첫 스냅샷이 만들어집니다(위젯에 숫자가 뜨는 근거).
4. **위젯 추가** — 홈 화면 길게 눌러 **+** ▸ Mwallet ▸ 예산/결산/지출 기록/영수증.
   잠금 화면 위젯(원형)도 지원.
5. **동작 확인** — 기록 위젯(중형) 프리셋을 누르면 큐에 담기고, **앱을 열면** 임시 기록에
   지출로 반영됩니다.

## 참고

- **프리셋 금액**은 `MwalletWidget.swift`의 `quickPresets`에서 수정(현재 커피 4,500 /
  식사 10,000 / 교통 3,000).
- 위젯 기록은 여행을 고르지 않아 임시 기록(기본함)에 원화로 담깁니다.
- 스냅샷은 예결산 탭을 열 때 갱신됩니다. 지출 저장 직후에도 갱신하려면 ReceiptStore 등
  저장 지점에서 `MwalletBridge.publish(...)`를 호출하면 됩니다.
- 공유 계약을 바꿀 땐 **두 곳(위젯 임베드 + `Shared/MwalletShared.swift`)을 함께** 수정.
  App Group ID·필드명·키가 다르면 데이터가 오가지 않습니다.
