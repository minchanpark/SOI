fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android deploy_to_playstore

```sh
[bundle exec] fastlane android deploy_to_playstore
```

Flutter 앱을 빌드하고 Play Store Internal Track에 배포합니다. (pubspec build 자동 증가)

### android upload_shorebird

```sh
[bundle exec] fastlane android upload_shorebird
```

Shorebird로 빌드하고 Play Store에 업로드합니다. (pubspec build 자동 증가 + 버전 일치 보장)

### android patch

```sh
[bundle exec] fastlane android patch
```

Shorebird 패치를 배포합니다 (기존 릴리즈에 코드푸시)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
