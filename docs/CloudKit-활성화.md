# CloudKit 동기화 활성화

코드는 이미 `NSPersistentCloudKitContainer` 로 작성되어 있고 필요한 옵션도 켜져 있습니다.
남은 것은 **Apple 계정 쪽 설정**뿐이며, 이건 코드로 대신할 수 없습니다.

현재 상태는 `Persistence.isCloudKitSyncEnabled = false` 로 **로컬 전용**입니다.

<br>

## ⚠️ 먼저 알아둘 것

**단일 스토어이므로 동기화를 켜면 모든 데이터(`Expense`·`Travel`·`Budget`·`User`)가
함께 iCloud 로 올라갑니다.** 이 앱은 여행·팀 단위 공동 재정을 다루므로 전부 동기화되는
것이 자연스럽지만, 특정 엔티티만 올리려면 모델을 두 Configuration 으로 나눠야 하고
그때는 저장된 데이터의 이전이 필요합니다.

### 돌아오기 전 마지막 점검 3가지 — 하나라도 어긋나면 앱이 죽습니다

1. **컨테이너 식별자 완전 일치** — 포털·Xcode·코드 세 곳이 모두
   `iCloud.com.Mwallet.app` 이어야 합니다. 대소문자·점 하나라도 다르면 실행 즉시 크래시.
2. **Background Modes 의 Remote notifications 까지 체크** — iCloud Capability 만
   추가하고 이걸 빠뜨리는 경우가 많습니다.
3. **스위치는 마지막에** — Xcode Capability 를 다 추가하기 전에
   `isCloudKitSyncEnabled = true` 로 바꾸면 앱이 켜지자마자 죽습니다. 이 크래시는
   코드로 못 막습니다(아래 참고). 돌아오시면 **제가 스위치를 켜겠습니다.**

<br>

## 1. Apple Developer 포털

1. 유료 Apple Developer Program 계정이 필요합니다 (무료 계정으로는 CloudKit 을 쓸 수 없습니다)
2. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources) → **Identifiers**
3. App ID `com.Mwallet.app` 를 만들거나 선택 → **iCloud** 체크
4. **iCloud Containers** 에서 컨테이너 생성
   ```
   iCloud.com.Mwallet.app
   ```
   `Persistence.cloudKitContainerIdentifier` 와 **정확히 같아야** 합니다

<br>

## 2. Xcode

프로젝트 → **TARGETS: Mwallet** → **Signing & Capabilities**

1. **Team** 을 본인 계정으로 지정 (자동 서명 상태입니다)
2. `+ Capability` → **iCloud** 추가
   - Services: **CloudKit** 체크
   - Containers: `iCloud.com.Mwallet.app` 체크
3. `+ Capability` → **Background Modes** 추가
   - **Remote notifications** 체크

> Xcode 가 `Mwallet/Mwallet.entitlements` 를 자동으로 만들어 연결합니다.
> 저장소에 같은 이름의 파일을 미리 넣어 두었으니, Xcode 가 이 파일을 쓰거나
> 새로 만들면 그쪽을 따르면 됩니다.
>
> `Info.plist` 의 `UIBackgroundModes: remote-notification` 은 이미 넣어 두었습니다.

<br>

## 3. 스위치 켜기

`Mwallet/Model/Persistence.swift`

```swift
static let isCloudKitSyncEnabled = true   // false → true
```

<br>

## 4. 확인

- 실기기 **2대**에 같은 iCloud 계정으로 로그인한 뒤 설치
- 한쪽에서 영수증을 추가하고 몇 초 뒤 다른 쪽에서 목록을 새로고침
- 시뮬레이터에서도 iCloud 로그인이 되어 있으면 동작하지만, 동기화 지연이 커서
  검증에는 실기기가 확실합니다

<br>

## ⛔ 순서를 지키세요 — 켜기 전에 켜면 앱이 죽습니다

**2번(Xcode Capabilities)을 마치기 전에 3번(스위치)을 켜면 앱이 실행 즉시 크래시합니다.**

실제로 확인한 동작입니다. entitlement 없이 스위치를 켜고 실행하면:

```
CKContainer.m:762: In order to use CloudKit, your process must have a
com.apple.developer.icloud-services entitlement.

Thread: com.apple.coredata.cloudkit.queue
  -[PFCloudKitContainerProvider containerWithIdentifier:options:]
  -[PFCloudKitSetupAssistant _initializeCloudKitForObservedStore:]
  → os_crash
```

`loadPersistentStores` 는 **성공으로 끝난 뒤** CloudKit 미러링이 별도 큐에서 죽기 때문에
코드로 잡아 되돌릴 수 없습니다. iOS 에는 앱이 자기 자신의 entitlement 를 읽는 API
(`SecTaskCopyValueForEntitlement`)가 없어 사전 감지도 불가능합니다.

`Persistence` 에 넣어 둔 폴백은 **스토어를 여는 단계에서 실패할 때만** 동작합니다
(컨테이너 식별자를 잘못 적은 경우 등). entitlement 누락은 막지 못합니다.

> 되돌리려면 `isCloudKitSyncEnabled = false` 로 바꾸고 다시 빌드하면 됩니다.
> 저장된 데이터는 그대로 남습니다.

<br>

## 남은 검증 과제

CloudKit 을 실제로 켜 본 적이 없으므로 아래 두 가지는 확인이 필요합니다.

1. **`participantArray` 의 Transformable 선언**
   `Travel`·`Expense` 의 `participantArray` 는 `customClassName="[String]"` 으로 선언되어 있는데,
   `[String]` 은 유효한 Objective-C 타입명이 아니라 실행 중 아래 경고가 남습니다.
   ```
   CoreData: Declared Objective-C type "[String]" for attribute
             named participantArray is not valid
   ```
   Transformable 자체는 CloudKit 미러링이 지원하고 현재도 값은 정상 저장·조회되지만,
   `initializeCloudKitSchema()` 단계에서 문제가 될 소지가 있습니다.
   `NSArray` 로 바꾸면 경고는 사라지지만 생성되는 프로퍼티 타입이 `NSArray?` 가 되어
   **사용처 20곳을 모두 고쳐야 하므로** 지금은 손대지 않았습니다.
   CloudKit 을 켠 뒤 실제로 문제가 생기면 그때 함께 정리하는 편이 안전합니다.

2. **바이너리 데이터 용량**
   `imageData` 와 `voiceRecordFile` 은 External Storage 로 설정되어 CKAsset 으로 올라갑니다.
   영수증 사진은 저장 전 장변 1600px / JPEG 0.7 로 줄이지만, 음성 파일은 압축하지 않으므로
   기록이 쌓이면 iCloud 용량을 확인해 보세요.
