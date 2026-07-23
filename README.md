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
| 로컬 저장소 | Core Data (`Travel`, `Expense`, `User`) |
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
│   │   ├── Record/             음성·수기 지출 기록
│   │   ├── Expense/            지출 조회·통계·CSV 내보내기
│   │   ├── Travel/             여행 생성·조회
│   │   ├── Modal/              선택 모달
│   │   └── Other/              스플래시, 설정
│   ├── Handler/                환율, 날짜, 정렬, 포맷팅
│   ├── Extension/              타입 확장
│   ├── DesignSystem/           Pretendard 폰트, 컬러, 버튼 테마
│   └── Utils/
└── docs/
```

<br>

## 로드맵

원본 코드베이스 분석에서 도출된 개선 과제입니다. 상세 내용은 별도 논의 후 이슈로 등록합니다.

**P0 — 정합성 / 보안**
- [ ] 환율 조회 실패 시 `-1` / `-100` 센티널이 Core Data에 저장되는 문제 제거
- [ ] `getExchangeRateFromKRW`의 0 나눗셈 방어
- [ ] CSV 이스케이프 정상화 (`"` 이중화, 전 필드 인용, 수식 주입 차단)

**P1 — 안정성**
- [ ] `fatalError` 5곳 → 복구 가능한 에러 처리로 전환
- [ ] `print` 197개 → `OSLog` 전환
- [ ] CI(빌드 + SwiftLint) 도입
- [x] SwiftLint 실제 동작 복구 (원본은 미설치 상태로 스킵되고 있었음)

**P2 — 구조**
- [ ] Repository 레이어 도입, View의 Core Data 직접 참조 제거
- [ ] `ManualRecord*` 중복 4개 파일 통합
- [ ] SwiftLint 길이·복잡도 룰 단계적 재활성화 (현재 위반 7건이 베이스라인)
- [ ] 테스트 타깃 신설

**P3 — 확장**
- [ ] 환율 프록시 서버 (클라이언트 키 임베딩 해소)
- [ ] `@MainActor` 적용, `asyncAfter` 타이밍 의존 제거
- [ ] 데이터 백업 / 기기 이전 경로
