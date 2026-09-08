fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

단위 테스트를 돌린다 (화면 테스트는 뺀다)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

화면을 찍어 fastlane/screenshots 로 꺼낸다

### ios store_screenshots

```sh
[bundle exec] fastlane ios store_screenshots
```

스토어용 화면을 열한 언어로 찍는다

### ios check_key

```sh
[bundle exec] fastlane ios check_key
```

App Store Connect 열쇠가 통하는지 본다 (읽기만 한다)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight 에 올린다

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

App Store 정보만 올린다 (빌드는 건드리지 않는다)

### ios lint

```sh
[bundle exec] fastlane ios lint
```

SwiftLint 위반만 모아 본다

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
