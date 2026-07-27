# Mwallet 위젯 추가 절차

위젯 4종 + 예결산 데이터 공유(App Group)를 붙이는 절차입니다.
코드는 모두 준비돼 있고, **타깃 생성·capability·파일 소속만 Xcode에서** 하면 됩니다.
(새 타깃/그룹을 CLI로 만들면 프로젝트가 깨질 수 있어 이 부분만 수동입니다.)

## 위젯 구성 (각 크기 제한됨)

| 위젯 | 역할 | 지원 크기 |
|---|---|---|
| **예산** | 이번 여행 예산·집행률 | `systemSmall`, `systemMedium` |
| **결산** | 예산 대비 집행·잔액 + 카테고리 | `systemMedium` |
| **지출 기록** | 눌러서 기록(딥링크) · 중형은 프리셋 큐 기록 | `systemSmall`, `systemMedium`, `accessoryCircular` |
| **영수증 등록** | 미등록 영수증 N건 → 등록 | `systemSmall`, `accessoryCircular` |

## 데이터 흐름 (App Group, 저장소 이전 없음)

- **읽기(예산·결산·영수증 위젯)**: 앱이 예결산 요약을 스냅샷으로 App Group에 기록 → 위젯이 읽음.
- **쓰기(기록 위젯 프리셋)**: 위젯이 App Group 큐에 담음 → 앱이 다음에 열릴 때 Core Data로 반영(그때 CloudKit 동기화). 저장소 위치·CloudKit 설정은 건드리지 않음.

---

## 1. 위젯 익스텐션 타깃 만들기

1. Xcode에서 `Mwallet.xcodeproj` 열기.
2. **File ▸ New ▸ Target… ▸ Widget Extension** → Next.
3. **Product Name**: `MwalletWidget`, **Include Live Activity**·**Include Configuration App Intent** 체크 해제, **Embed in Application**: `Mwallet` → Finish.
4. "Activate scheme?" → **Cancel**.
5. 자동 생성된 위젯 소스(예: `MwalletWidget.swift`, `MwalletWidgetBundle.swift`)는 **삭제**하거나 내용을 비웁니다. (`@main`이 겹치면 충돌)

## 2. App Group capability 추가 (두 타깃 모두)

App Group ID는 **`group.com.Mwallet.app`** — 코드(`MwalletShared.appGroupID`)와 반드시 동일해야 합니다.

1. **Mwallet(앱) 타깃** ▸ Signing & Capabilities ▸ **+ Capability ▸ App Groups** ▸ **+** ▸ `group.com.Mwallet.app` 추가·체크.
2. **MwalletWidget(위젯) 타깃** ▸ 동일하게 App Groups ▸ 같은 `group.com.Mwallet.app` 체크.
   - (개발자 계정에 그룹이 자동 등록됩니다. 이미 앱 엔타이틀먼트에 빈 App Groups 배열이 있어 항목만 채우면 됩니다.)

## 3. 파일을 타깃에 추가 (Target Membership)

프로젝트 네비게이터에서 각 파일 선택 → 우측 File Inspector의 **Target Membership** 체크:

| 파일 | Mwallet(앱) | MwalletWidget(위젯) |
|---|:---:|:---:|
| `Shared/MwalletShared.swift` | ✅ | ✅ |
| `Shared/MwalletBridge.swift` | ✅ | ⬜️ |
| `MwalletWidget/MwalletWidget.swift` | ⬜️ | ✅ |

- 파일이 네비게이터에 없으면 **File ▸ Add Files to "Mwallet"…** 로 `Shared/` 폴더와 `MwalletWidget/MwalletWidget.swift` 를 추가한 뒤 위 소속을 지정하세요.
- 위젯 타깃 **Deployment Target = iOS 17.0** 확인(앱과 동일). `containerBackground`·인터랙티브 버튼이 iOS 17 필요.

## 4. 앱에 두 줄 붙이기 (스냅샷 발행 · 큐 반영)

`Shared/MwalletBridge.swift`가 앱 타깃에 들어가면 아래를 추가합니다.

### (a) 예결산 화면에서 스냅샷 발행 — `Mwallet/Budget/View/BudgetView.swift`

`reload()` 끝에 한 줄:

```swift
private func reload() {
    travels = store.availableTravels()
    if selectedTravel == nil || !travels.contains(where: { $0.objectID == selectedTravel?.objectID }) {
        selectedTravel = travels.first { $0.objectID == mainVM.selectedTravelInExpense?.objectID }
            ?? travels.first
    }
    refreshToken = UUID()
    publishWidgetSnapshot()          // ← 추가
}

// 추가
private func publishWidgetSnapshot() {
    let pending = store.expenses(for: selectedTravel).filter { $0.needsPhoto }.count
    MwalletBridge.publish(
        summary: store.summary(for: selectedTravel),
        travelName: selectedTravel?.name ?? "여행",
        pendingReceiptCount: pending
    )
}
```

`refreshAfterEditing()` 에도 `publishWidgetSnapshot()` 한 줄을 더하면 예산 편집 직후에도 갱신됩니다.

> `store.expenses(for:)`, `Expense.needsPhoto` 는 이미 앱에 있습니다(여행 지도·영수증에서 사용). 이름이 다르면 맞춰 주세요.

### (b) 앱이 활성화될 때 위젯 큐 반영 — `Mwallet/MwalletApp.swift`

```swift
@main
struct MwalletApp: App {
    @Environment(\.scenePhase) private var scenePhase   // ← 추가
    private let seeder = FirstLaunchSeeder.shared

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .onOpenURL(perform: handleDeepLink)
        }
        .onChange(of: scenePhase) { _, phase in           // ← 추가
            if phase == .active {
                MwalletBridge.flushPendingExpenses(
                    into: PersistenceController.shared.container.viewContext
                )
            }
        }
    }
    // handleDeepLink(_:) 는 이미 있음
}
```

## 5. 확인

1. 앱을 한 번 빌드·실행 → **예결산 탭**을 열어 스냅샷을 만든다.
2. 홈 화면 길게 눌러 **+** ▸ Mwallet ▸ 예산/결산/지출 기록/영수증 위젯 추가.
3. 기록 위젯(중형)의 프리셋을 누르면 큐에 담기고, **앱을 열면** 임시 기록에 지출로 반영된다.
4. 잠금 화면 위젯(원형)도 지원: 지출 기록·영수증.

## 딥링크 (이미 앱에 반영됨)

- `mwallet://record` → 기록 탭
- `mwallet://receipt` → 영수증 탭
- `mwallet://budget` → 예결산 탭

## 참고 / 한계

- **프리셋 금액**은 `MwalletWidget.swift`의 `quickPresets`에서 자유롭게 바꿉니다(현재 커피 4,500 / 식사 10,000 / 교통 3,000).
- 위젯 기록은 **여행을 고르지 않아** 임시 기록(기본함)에 담기고 원화로 저장됩니다.
- 다른 기기 반영은 앱을 한 번 연 뒤 CloudKit 동기화 시점에 이뤄집니다(큐 방식).
- 스냅샷은 예결산 탭을 열 때 갱신됩니다. 더 자주 갱신하려면 지출 저장 지점(ReceiptStore 등)에서도 `MwalletBridge.publish(...)`를 호출하세요.
