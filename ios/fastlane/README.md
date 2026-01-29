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

### ios deploy_to_testflight

```sh
[bundle exec] fastlane ios deploy_to_testflight
```

Flutter 앱을 빌드하고 TestFlight에 배포합니다. (pubspec build 자동 증가)

### ios upload_shorebird

```sh
[bundle exec] fastlane ios upload_shorebird
```

Shorebird로 빌드하고 App Store Connect(TestFlight)에 업로드합니다. (pubspec build 자동 증가 + 버전 일치 보장)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
