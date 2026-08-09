# 번들에 넣은 글꼴

앱 바이너리에 함께 배포하는 글꼴이므로 출처와 허용 범위를 남겨 둔다.

## Wanted Sans

| | |
|---|---|
| 파일 | `WantedSans-SemiBold.otf`, `WantedSans-Medium.otf`, `WantedSans-Regular.otf` |
| PostScript 이름 | `WantedSans-SemiBold` · `-Medium` · `-Regular` |
| 버전 | 1.003 |
| 만든 곳 | 원티드랩 (Wanted Lab) |
| 배포 | <https://github.com/wanteddev/wanted-sans> |
| 라이선스 | SIL Open Font License 1.1 |

**소프트웨어에 넣어 함께 배포하는 것이 허용된다.** 글꼴 자체를 파는 것만 안 된다.
라이선스 전문이 글꼴 파일 안(`name` 테이블 13번)에 들어 있어, 파일만으로도 조건을 확인할 수 있다.

한글 11,172자(완성형 전체)를 갖췄다. 이 앱은 한국어 전용이라 이 조건이 필수다.

### 이 글꼴을 고른 이유

자간이 좁고 획 끝이 각져, 같은 크기에서도 글자가 크고 단단하게 읽힌다.
이 앱은 화면마다 두 가지가 나온다.

- **긴 여행 이름** — 자간이 좁아 4열 그리드처럼 폭이 좁은 자리에서 덜 잘린다
- **금액** — 숫자의 대비가 강해 자릿수가 또렷하다. 대부분 `monospacedDigit()` 과 함께 쓰인다

### 굵기를 셋만 두는 이유

예전에는 Pretendard 아홉 굵기 약 14MB 를 모두 넣었지만 코드가 부르는 것은 셋뿐이었다.
쓰지 않는 여섯 개가 앱 용량만 9.4MB 차지했다.

굵기를 새로 쓰려면 `.otf` 파일과 `Info.plist` 의 `UIAppFonts`, 그리고
`FontsManager` 세 곳을 함께 고쳐야 한다. 하나라도 빠지면 글꼴이 조용히
시스템 기본으로 떨어진다 — 빌드는 그대로 통과하므로 화면을 봐야 알 수 있다.
