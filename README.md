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

규칙은 [`Mwallet/.swiftlint.yml`](Mwallet/.swiftlint.yml)에서 관리합니다. 현재 원본 프로젝트에서 비활성화해 둔 길이·복잡도 규칙 10개가 그대로 꺼져 있으며, 단계적으로 되살리는 것이 로드맵 P2 항목입니다.

CLI 빌드 시에는 플러그인 검증 우회 플래그가 필요합니다.

```bash
xcodebuild -project Mwallet.xcodeproj -scheme Mwallet \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation build
```

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
| 기간 필터 · 인원별 정산 · 사진 여러 장 | 미구현 |

**여행 지도 탭** (`Mwallet/Receipt/TravelMapView`)

| 기능 | 상태 |
|---|---|
| 지출 위치를 지도 핀으로 표시 · 카메라 자동 맞춤 | ✅ |
| 여행 생성 · 삭제 · 여행 상세 연결 | ✅ |
| 설정 화면 진입(툴바 기어) | ✅ |
| 여행 **편집**(이름·기간·인원 수정) | 미구현 |

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
- [ ] **`DateGapHandler` 시간대 시프트 제거** — `DateGapHandler` 참조 10개 파일. 저장 형식 문제라 데이터가 쌓이기 전에. CloudKit을 켠 지금 최우선
- [ ] 화면과 CSV의 환율 기준 통일 (화면은 오늘 환율, CSV는 기록 시점 환율)

**P1 — 안정성**
- [x] SwiftLint 실제 동작 복구 (원본은 미설치 상태로 스킵되고 있었음)
- [x] SwiftLint 위반 0건 달성
- [ ] 테스트 타깃 신설 — 미착수
- [ ] CI(빌드 + 린트 + 테스트) 도입 — 미착수
- [ ] `print` → `OSLog` 전환 (현재 약 60개, 데드 코드 제거로 181 → 60 감소)
- [ ] `fatalError` 5곳 → 복구 가능한 에러 처리로 전환
- [ ] 기존 `CSVArchive` 를 `ReceiptCSVEncoder` 로 교체 (이스케이프 결함 잔존)

**P2 — 구조**
- [x] 데드 코드 제거, `TempSave` → `FirstLaunchSeeder` 정리
- [x] 2차 데드 코드 정리 — 도달 불가 구 여행목록/Interim 기록 화면 계열 16파일 + `Constants` 제거, 구 NomadWallet 잔재(설정 화면 링크·이메일) 정리
- [x] `ManualRecord*` 통합 진척 — 중복 심하던 `ManualRecordWithExpenseView` 쌍 제거, 현재 `ManualRecordView` + VM 2파일만 잔존
- [ ] Repository 레이어 도입, View의 Core Data 직접 참조 제거 (13곳 → 현재 3곳)
- [ ] `Travel.isDefault` 도입 → `tempTravelName` 매직 문자열 제거
- [ ] SwiftLint 길이·복잡도 룰 10개 단계적 재활성화

**P3 — 확장**
- [ ] 환율 프록시 서버 (클라이언트 키 임베딩 해소)
- [ ] `@MainActor` 적용, `asyncAfter` 5곳 타이밍 의존 제거
- [ ] `participantArray` 의 `customClassName` 정리 (CloudKit 활성화 시 필요할 수 있음)

**기능 공백 (코드 리뷰에서 발견 — 로드맵 미등록분)**
- [ ] **여행 편집 화면** — 여행은 생성·삭제만 되고 기존 이름·기간·인원 수정 흐름이 없음
- [ ] **지출 → 편집 연결** — 여행 상세에서 지출 탭 시 예결산 탭 전환만 하고 해당 지출 편집으로 열지 않음 (편집은 영수증 탭에서만)
- [ ] **`Budget` 엔티티 정합** — `SettingView.deleteAllData`의 삭제 대상 목록에 `Budget` 누락(현재 주석 WIP), 살릴 때 orphan 위험
