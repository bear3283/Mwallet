# 번들에 넣은 글꼴

앱 바이너리에 함께 배포하는 글꼴이므로 출처와 허용 범위를 남겨 둔다.

## 마루 부리 (MaruBuri) — 제목

| | |
|---|---|
| 파일 | `MaruBuri-SemiBold.otf` |
| PostScript 이름 | `MaruBuriot-SemiBold` |
| 버전 | 2.000 |
| 저작권 | © NAVER Corp. © NAVER Cultural Foundation Corp. |
| 만든 곳 | AG 타이포그라피연구소 (노은유, 이노을, 구모아) |
| 배포 | <https://hangeul.naver.com/font> |
| 라이선스 | SIL Open Font License 1.1 |

개인·기업 모두 무료로 쓸 수 있고, **소프트웨어에 넣어 함께 배포하는 것이 허용된다.**
글꼴 자체를 파는 것만 안 된다. 고쳐 쓰는 것도 허용되지만 이 앱은 원본 그대로 쓴다.

한글 11,172자(완성형 전체)를 갖췄다. 이 앱은 한국어 전용이라 이 조건이 필수다.

## Pretendard — 본문·숫자

| | |
|---|---|
| 파일 | `Pretendard-SemiBold.otf`, `Pretendard-Medium.otf`, `Pretendard-Regular.otf` |
| 라이선스 | SIL Open Font License 1.1 |
| 배포 | <https://github.com/orioncactus/pretendard> |

### 굵기를 셋만 두는 이유

예전에는 아홉 굵기 약 14MB를 모두 넣었지만 코드에서 부르는 것은 셋뿐이었다.
쓰지 않는 여섯 개가 앱 용량만 9.4MB 차지했다.

굵기를 새로 쓰려면 `.otf` 파일과 `Info.plist` 의 `UIAppFonts`, 그리고
`FontsManager` 세 곳을 함께 고쳐야 한다. 하나라도 빠지면 글꼴이 조용히
시스템 기본으로 떨어진다 — 빌드는 그대로 통과하므로 화면을 봐야 알 수 있다.
