# Mwallet

해외여행 가계부 iOS 앱. [NomadWallet](https://apps.apple.com/ca/app/id6470182505)(2023, MacC Team11-UMM)의 코드베이스를 기반으로 새롭게 개발하는 프로젝트입니다.

원본 프로젝트의 README(팀 정보, 기존 기능 명세, Git/코드 컨벤션)는 [`docs/NomadWallet-원본-README.md`](docs/NomadWallet-원본-README.md)에 보관되어 있습니다.

<br>

## 개발 환경

| 항목 | 값 |
|---|---|
| 최소 지원 | iOS 17.0 |
| 언어 / UI | Swift 5, SwiftUI |
| 아키텍처 | MVVM (개선 진행 중) |
| 로컬 저장소 | Core Data (`Travel`, `Expense`, `Budget`, `User`) + CloudKit 동기화 |
| 음성 인식 | Speech |
| 카테고리 분류 | CreateML (온디바이스 `InfoClassifier.mlmodel`) |
| 위치 | Core Location |
| 환율 | exchangerate-api.com (무료 플랜, 1일 1회 갱신) |
| 의존성 | SPM 단일 — lottie-ios 4.3.3, SwiftLintPlugins 0.65.0 |

<br>

## 시작하기

### 1. 시크릿 설정 (필수)

이 프로젝트는 환율 API 키를 xcconfig로 주입합니다. **키 파일은 저장소에 포함되지 않습니다.**

```bash
cp Mwallet/View/Config.xcconfig.example Mwallet/View/Config.xcconfig
```

생성된 `Config.xcconfig`를 열어 [exchangerate-api.com](https://www.exchangerate-api.com)에서 발급받은 본인의 키를 입력하세요.

```
API_KEY = 여기에_본인_키
```

> ⚠️ `Config.xcconfig`와 `.env`는 `.gitignore`에 등록되어 있습니다. 절대 커밋하지 마세요.
> 원본 프로젝트는 이 파일들을 커밋해 키가 유출된 이력이 있습니다.

### 2. 실행

```bash
open Mwallet.xcodeproj
```

의존성은 SPM으로 관리되어 Xcode가 열릴 때 자동으로 해석됩니다. 별도 설치 명령이 없습니다.

빌드 전 `Signing & Capabilities` 탭의 **Team**을 본인 계정으로 지정하세요 (자동 서명으로 설정되어 있습니다).

첫 빌드 시 SwiftLint 빌드 플러그인 신뢰 여부를 묻는 대화상자가 뜨면 **Trust & Enable**을 선택하세요.

### 3. 린트

SwiftLint는 **빌드 플러그인으로 자동 실행**됩니다. 별도 설치(`brew install swiftlint`)가 필요 없고 버전이 0.65.0으로 고정됩니다.

규칙은 [`Mwallet/.swiftlint.yml`](Mwallet/.swiftlint.yml)에서 관리합니다. 원본에서 꺼져 있던 길이·복잡도 규칙 중 `function_body_length`·`cyclomatic_complexity`·`type_body_length`를 되살렸습니다. 남은 예외 두 곳은 그 자리에 `swiftlint:disable:next`와 이유를 적어 뒀습니다.

CLI 빌드 시에는 플러그인 검증 우회 플래그가 필요합니다.

```bash
xcodebuild -project Mwallet.xcodeproj -scheme Mwallet \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation build
```

### 4. fastlane

되풀이하는 일을 레인으로 묶어 뒀습니다. 세 레인 모두 **시뮬레이터에서만 돌고 계정 정보가 필요 없습니다.**

```bash
bundle install                      # 처음 한 번

bundle exec fastlane test           # 단위 테스트
bundle exec fastlane screenshots    # 화면을 찍어 fastlane/screenshots 로 꺼낸다
bundle exec fastlane lint           # SwiftLint 위반만 모아 본다
```

배포 쪽은 App Store Connect 열쇠가 있어야 합니다. [`fastlane/.env.example`](fastlane/.env.example)을 `fastlane/.env` 로 복사해 채우세요.

```bash
bundle exec fastlane check_key      # 열쇠가 통하는지 (읽기만 한다)
bundle exec fastlane beta           # TestFlight 에 올린다
```

`.p8` 개인키는 **저장소 밖**에 두고 경로만 넘깁니다. 한 번만 내려받을 수 있는 파일이고, 들어오면 계정 전체를 만질 수 있습니다. `*.p8` 은 `.gitignore` 로도 막아 뒀습니다.

`screenshots`는 화면 테스트를 돌린 뒤 결과 묶음에서 그림을 꺼내 `01-기록.png`처럼 이름을 붙여 놓습니다. 손으로 하려면 `xcresulttool export attachments`로 꺼내고 매니페스트를 읽어 UUID 파일명을 사람이 붙인 이름으로 바꿔야 하는 일입니다. 찍힌 그림은 커밋하지 않습니다(`.gitignore`).

**Ruby 4에서는 fastlane 2.228 이상이 필요합니다.** 그 아래 버전은 시작하자마자 `uninitialized constant FastlaneCore::UpdateChecker`로 죽습니다. `Gemfile`에 하한을 걸어 뒀습니다.

App Store Connect에 올리는 레인은 아직 없습니다. [`fastlane/Appfile`](fastlane/Appfile)의 계정 항목은 사람마다 다른 값이라 비워 두었고, 환경 변수로 넘기는 편을 권합니다.

<br>

## 프로젝트 구조

```
Mwallet/
├── Mwallet/
│   ├── MwalletApp.swift        진입점
│   ├── Model/                  Core Data, CSV 기반 국가·통화 데이터
│   │   ├── Mwallet.xcdatamodeld
│   │   └── Enumeration/        Currency, Country, PaymentMethod 등
│   ├── ViewModel/              화면별 ObservableObject
│   ├── View/
│   │   ├── Record/             음성·수기 지출 기록 (지출 기록 탭)
│   │   ├── Travel/             여행 생성·조회 (여행 지도 탭 진입 흐름)
│   │   ├── Modal/              선택 모달
│   │   └── Other/              스플래시, 설정
│   ├── Receipt/                영수증 탭 — 목록·추가·상세·차트·CSV·지도
│   │   ├── View/  Model/  Store/
│   ├── Budget/                 예결산 탭 — 예산 편집·예산 대비 실지출 요약
│   │   ├── View/  Model/  Store/
│   ├── Handler/                환율, 날짜, 정렬, 포맷팅
│   ├── Extension/              타입 확장
│   ├── DesignSystem/           Pretendard 폰트, 컬러, 버튼 테마, M 브랜드마크
│   └── Utils/
└── docs/
```

> 탭 구성(왼쪽부터): **여행 지도 · 예결산 · 지출 기록 · 영수증**. 지출은 단일 `Expense` 엔티티로 통합되어 네 탭이 같은 데이터를 공유한다.

<br>

## 기능 현황

**영수증 탭** (`Mwallet/Receipt/`)

| 기능 | 상태 |
|---|---|
| 목록 · 검색 · 사역별 필터 · 일자별 합계 | ✅ |
| 추가 / 수정 폼 (사진 첨부 포함) | ✅ |
| 상세 보기 · 삭제 · 환율 사후 적용 | ✅ |
| 카테고리별 비율 차트 | ✅ |
| CSV 내보내기 (RFC 4180) | ✅ |
| 인원별 정산 | 여행 상세에서 사람별로 나눠 본다 |
| 기간 필터 | 영수증 탭에서 전체·오늘·최근 7일·이번 달 |
| 사진 여러 장 | 한 건에 최대 5장. 목록에 장수, 상세에서 넘겨 보기 |

**여행 지도 탭** (`Mwallet/Receipt/TravelMapView`)

| 기능 | 상태 |
|---|---|
| 지출 위치를 지도 핀으로 표시 · 카메라 자동 맞춤 | ✅ |
| 여행 생성 · 삭제 · 여행 상세 연결 | ✅ |
| 설정 화면 진입(툴바 기어) | ✅ |
| 여행 **편집**(이름·기간·인원 수정) | ✅ |

**지출 기록 탭** (`Mwallet/View/Record/`)

| 기능 | 상태 |
|---|---|
| 음성 인식(STT) → 한국어 금액·결제수단 파싱 | ✅ |
| CreateML 온디바이스 카테고리 분류 | ✅ |
| 기록 시 위치 확인("이곳이 맞나요?") | ✅ |
| 수기 기록 · 첫 실행 예시 데이터 시딩 | ✅ |

**예결산 탭** (`Mwallet/Budget/`)

| 기능 | 상태 |
|---|---|
| 카테고리별 예산 편집 | ✅ |
| 예산 대비 실지출 요약 | ✅ |

**동기화**

| 기능 | 상태 |
|---|---|
| CloudKit 동기화 (`iCloud.com.Mwallet.app`) | ✅ 활성화 — 실기기 검증됨. 절차 [`docs/CloudKit-활성화.md`](docs/CloudKit-활성화.md) |

<br>

## 로드맵

**P0 — 정합성**
- [x] 환율 조회 실패 시 `-1` / `-100` 센티널이 Core Data에 저장되는 문제 제거
- [x] `getExchangeRateFromKRW`의 0 나눗셈 방어
- [x] 환율 캐시 만료 판정을 UTC 절대시각 기준으로 수정
- [x] **`DateGapHandler` 시간대 시프트 제거** — `convertBeforeSaving` / `convertBeforeShowing` 과 호출부 10개 파일 정리. `payDate` 는 이제 언제나 실제 절대시각이고, 현지 시각 복원은 `timeZoneIdentifier` 가 맡는다
- [x] 화면과 CSV의 환율 기준 통일 — 화면·통계·예결산·CSV가 모두 `Expense.amountInKRW`(기록 시점 환율) 하나를 쓴다
- [x] 위치를 못 잡으면 통화가 달러로 고정되던 문제 — 기본값을 원화로 바꾸고 후보 목록에 원화·달러를 항상 남긴다
- [x] `CountryList.csv` 복수 통화 국가(홍콩·마카오) 파싱 시 통화 유실 + 열 밀림 제거

**P1 — 안정성**
- [x] SwiftLint 실제 동작 복구 (원본은 미설치 상태로 스킵되고 있었음)
- [x] SwiftLint 위반 0건 달성
- [x] 테스트 타깃 신설 (`MwalletTests`) — 120건. CSV 파서 · 국가/통화 표 · 환율 · 금액 환산 · CSV 인코딩 · 예산 집계 · 영수증 집계/필터 · 저장 규칙 · 지도 순서 · 위젯 큐
- [x] CI(빌드 + 린트 + 테스트) — [`.github/workflows/ci.yml`](.github/workflows/ci.yml). **손으로 돌릴 때만 돈다** (Actions 탭 → CI → Run workflow). 비공개 저장소의 macos 러너는 분당 10배로 계산되어 무료 한도가 40회 남짓인데, 여기서 하는 일은 손안의 기계에서 몇 분이면 끝나고 머지 전에 늘 그렇게 확인한다. 파일을 남겨 둔 것은 '깨끗한 기계에서 빌드하는 법' 의 기록이기 때문이다
- [x] `fatalError` 5곳 → 3곳을 복구 가능한 처리로 전환 (남은 2곳은 `Persistence` 의 저장소 개방 실패로, 앱이 할 수 있는 복구가 없음)
- [x] 기존 `CSVArchive` 를 `ReceiptCSVEncoder` 로 교체 완료
- [x] `print` → `OSLog` 전환 — 디버그 노이즈 16개는 삭제, 44개를 5개 카테고리로 이동
- [x] **음성 파싱 로직 테스트** — 37건. '만원' 이 0원으로 잡히던 결함과 '점심' 이 소수점으로 읽히던 결함을 찾아 고쳤다
- [x] **'점' 이 낱말 안에서도 소수점으로 읽히던 문제** — 앞 글자가 숫자일 때만 소수점으로 본다

**P2 — 구조**
- [x] 데드 코드 제거, `TempSave` → `FirstLaunchSeeder` 정리
- [x] 2차 데드 코드 정리 — 도달 불가 구 여행목록/Interim 기록 화면 계열 16파일 + `Constants` 제거, 구 NomadWallet 잔재(설정 화면 링크·이메일) 정리
- [x] `ManualRecord*` 통합 진척 — 중복 심하던 `ManualRecordWithExpenseView` 쌍 제거, 현재 `ManualRecordView` + VM 2파일만 잔존
- [x] App Group 공유 계약 중복 제거 — 위젯이 `Shared/MwalletShared.swift` 를 함께 컴파일한다 (약 100줄 사본 삭제)
- [x] `Travel.isDefault` 도입 → `tempTravelName` 매직 문자열 제거 (21곳)
- [x] View 의 Core Data 직접 참조 제거 — 남아 있던 네 곳을 스토어로 보냈다. 여행 조회·기본함·삭제는 `TravelStore` 가 맡고, 세 곳에 흩어져 있던 `availableTravels()` 도 한 곳으로 모았다
- [x] SwiftLint 길이·복잡도 룰 재활성화 — `function_body_length` · `cyclomatic_complexity` · `type_body_length`. 화면 여덟을 쪼개고 복사본 넷을 걷어냈다. 남은 예외는 두 뷰모델의 오디오 뿐이고 그 자리에 이유를 적어 뒀다

**P3 — 확장**
- [x] `@MainActor` 적용 — ViewModel 8개 + 핸들러 3개. `SWIFT_STRICT_CONCURRENCY=complete` 로 경고 0건
- [ ] 환율 프록시 서버 (클라이언트 키 임베딩 해소) — 코드가 아니라 인프라 결정이 먼저다
- [ ] `asyncAfter` 남은 2곳(`RecordView`)의 타이밍 의존 제거 — 손을 뗀 뒤 0.4초를 기다려 인식 결과가 도착하기를 바라고 있다. 시간이 아니라 `result.isFinal` 을 기다려야 하고, 그러려면 `stopSTT` 가 작업을 취소하는 대신 `endAudio` 로 마지막 결과를 받아야 한다. 실기기 마이크가 있어야 확인할 수 있다 (스플래시 1.6초는 연출이라 그대로, 햅틱 지연은 제거됨)
- [x] `SWIFT_VERSION` 5.0 → 6.0 — `SWIFT_STRICT_CONCURRENCY = complete` 를 먼저 통과시켜 둔 덕에 고칠 코드가 없었다
- [x] `participantArray` 의 `customClassName` 정리 — `"[String]"` 은 유효한 Objective-C 타입명이 아니라 앱을 열 때마다 오류가 4건씩 남았다. `NSArray` 로 바꾸고 쓰는 쪽은 `participants`(`[String]`)로 받는다. 저장 형식은 그대로라 마이그레이션이 없다

- [x] **여행 선택을 세 탭이 함께 쓰는 시트로 통합** — 기록은 가로로 흐르는 사진 카드, 예결산·영수증은 글자 목록이라 같은 일을 서로 다르게 묻고 있었다. 석 줄 격자에 연도로 나누고, 오른쪽 위 달력에서 한 해만 볼 수 있다. 높이는 두 단이라 처음에는 한 줄만 보이고 끌어올리면 나머지가 나온다
- [x] **국기 에셋 이름 정합** — 29개 나라 중 9개(한국·중국·일본·미국·독일·프랑스·영국·대만·베트남)가 `koreaFlag` 처럼 첫 글자만 소문자라 CSV(`KoreaFlag`)와 어긋나 조용히 빈자리로 그려지고 있었다
- [x] **영수증 사진 여러 장** — `Expense.imageData`(한 장) → `ReceiptPhoto` 엔티티(여러 장). 첫 실행 때 한 번 옮긴다

- [x] **접근성 — 소리로 읽을 이름** — 아이콘 버튼이 'Gear Shape' 로, 장식 그림이 자산 이름으로 읽히고 있었다. 녹음 버튼은 VoiceOver 에 아예 없는 자리였다. Apple 의 `performAccessibilityAudit` 으로 확인하고 회귀 테스트를 걸었다
- [x] **접근성 — 글자 크기 설정** — 글꼴이 모두 `fixedSize` 라 기기에서 글자를 키워도 이 앱만 그대로였다. 토큰 22개를 `relativeTo` 로 바꾸고 `_fixed` 이름 169곳을 걷어냈다. 접근성 크기로 네 탭을 찍어 깨진 한 곳을 고쳤다
- [x] **접근성 — 보조 문구 대비** — `gray300`(2.4:1)·`gray400`(4.1:1)이 기준(4.5:1) 미달이었다. 층이 뒤집히지 않게 사다리를 함께 내려 대비 실패 47건 → 16건. 남은 것은 '고르지 않음' 을 흐리게 두는 색과, 떠 있는 탭바에 가린 줄이다

**앞으로 할 것 (정해진 순서)**
- [ ] **분류를 직접 만들고 지우기** — 지금 분류는 열거형(`ExpenseInfoCategory: Int`)이고 저장은 숫자다. 파일 20개·참조 49곳이 이 숫자를 쓴다. 열거형을 catalog 로 옮기되 **저장되는 숫자(code)는 그대로 두어** 이미 쌓인 기록이 어긋나지 않게 한다. 사용자 분류는 code 100번대를 받는다
- [ ] **분류 색을 직접 고르기 (경고 포함)** — 지금 색은 배열 위치로 정해지고, 그 순서는 도넛 링의 인접쌍 기준으로 색각 이상 분리도를 검증해 둔 것이다. 자유롭게 고르게 하되 **인접한 분류와 너무 비슷하면 알린다**. 판단은 사용자 몫이되 모르고 지나치지는 않게 한다
- [ ] **예산 편집에서 항목 넣고 빼기** — 지금은 열 분류를 전부 늘어놓아 안 쓰는 것까지 지나쳐야 한다
- [ ] **기록 탭의 여행 선택 UI 통일** — 시트는 이미 세 탭이 함께 쓴다. 누르는 자리만 기록 탭이 캡슐 버튼이라 예결산·영수증의 두 줄짜리와 다르다
- [ ] **예산 항목을 눌러 내역 보기** — 분류별 합계에서 멈춰 있어, 그 금액이 언제 몇 건으로 쌓였는지는 영수증 탭으로 건너가 걸러 봐야 한다

**기능 공백 (코드 리뷰에서 발견 — 로드맵 미등록분)**
- [x] **여행 편집 화면** — 여행 상세 우상단 연필. 쓰기 규칙은 `TravelStore` 로 분리
- [x] **`Budget` 엔티티 정합** — 삭제 목록에 `Budget` 추가, CloudKit 안전한 삭제 방식으로 전환
- [x] **지출 → 편집 연결** — 여행 상세의 지출 줄을 누르면 그 지출 상세로 간다. 번호를 누르면 지도가 그 지점으로 옮겨 간다
