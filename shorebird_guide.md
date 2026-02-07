# Shorebird 배포 가이드

이 문서는 SOI 프로젝트에서 Shorebird로 **앱 업로드**와 **코드푸시(패치)**를 수행하는 방법을 정리합니다.

## 사전 준비

### iOS
iOS 배포를 위해서는 `ios/.env` 파일에 App Store Connect API 키 정보가 필요합니다.

### Android
Android 배포를 위해서는 Google Play Console 서비스 계정이 필요합니다:

1. **서비스 계정 생성**
   - [Google Play Console](https://play.google.com/console) > 설정 > API 액세스
   - 새 서비스 계정 생성 또는 기존 계정 연결
   - JSON 키 파일 다운로드

2. **환경 설정**
   ```bash
   cd android
   cp .env.example .env
   # .env 파일을 열어 GOOGLE_PLAY_JSON_KEY_PATH에 JSON 키 파일 경로 입력
   ```

3. **의존성 설치**
   ```bash
   cd android
   bundle install
   ```

## 앱 업로드 (Release 배포)

Shorebird에 앱을 업로드할 때 사용합니다.

```bash
# iOS 앱 업로드 (TestFlight)
cd ios && bundle exec fastlane upload_shorebird

# Android 앱 업로드 (Play Store Internal Track)
cd android && bundle exec fastlane upload_shorebird

# Android 앱 업로드 (다른 트랙 지정)
cd android && bundle exec fastlane upload_shorebird track:alpha
cd android && bundle exec fastlane upload_shorebird track:beta
cd android && bundle exec fastlane upload_shorebird track:production
```

## 앱 패치 (코드푸시)

기존 설치된 앱에 패치를 배포할 때 사용합니다.

```bash
# iOS 앱 패치
shorebird patch --platforms=ios

# Android 앱 패치
shorebird patch --platforms=android

# 또는 Fastlane으로 Android 패치
cd android && bundle exec fastlane patch
```

## 일반 배포 (Shorebird 없이)

Shorebird 없이 스토어에 직접 배포할 때 사용합니다.

```bash
# iOS -> TestFlight
cd ios && bundle exec fastlane deploy_to_testflight

# Android -> Play Store Internal Track
cd android && bundle exec fastlane deploy_to_playstore

# Android -> 다른 트랙 지정
cd android && bundle exec fastlane deploy_to_playstore track:beta
```

## 기본 흐름 (빌드 -> 업로드 -> 패치)

1. **릴리즈 업로드**: 스토어에 올릴 빌드(릴리즈)를 Shorebird에 업로드
2. **스토어 배포**: 앱스토어/플레이스토어에 정상 배포
3. **코드푸시 패치**: 스토어에 올라간 앱에 Dart 코드 변경을 패치로 배포

## Fastlane Lane 설명

### iOS (`ios/fastlane/Fastfile`)
| Lane | 설명 |
|------|------|
| `deploy_to_testflight` | Flutter 빌드 후 TestFlight 업로드 |
| `upload_shorebird` | Shorebird 빌드 후 TestFlight 업로드 |

### Android (`android/fastlane/Fastfile`)
| Lane | 설명 |
|------|------|
| `deploy_to_playstore` | Flutter 빌드 후 Play Store 업로드 |
| `upload_shorebird` | Shorebird 빌드 후 Play Store 업로드 |
| `patch` | Shorebird 패치 배포 |

## 주의사항

- **네이티브 변경은 패치로 배포 불가**: iOS/Android 네이티브 코드, 플러그인 업데이트 등은 스토어 업데이트가 필요합니다.
- **패치는 스토어에 배포된 앱에만 적용**: 아직 스토어에 없는 빌드에는 패치가 적용되지 않습니다.
- **버전 관리**: 스토어 업로드용 버전/빌드 넘버는 자동으로 증가합니다 (pubspec.yaml 기준).
- **테스트 권장**: 패치 전, 로컬 및 스테이징에서 충분히 검증하세요.

## 트러블슈팅

### Google Play API 권한 오류
서비스 계정에 "릴리즈 관리" 권한이 있는지 확인하세요.

### "App is not found" 오류
- 앱이 Play Store에 등록되어 있어야 합니다 (최소 내부 테스트 버전이라도).
- 패키지 이름이 일치하는지 확인하세요.

### Shorebird 중복 릴리즈 오류
Fastfile에서 자동으로 버전을 올려 재시도합니다. 지속적으로 발생하면 `shorebird releases list` 명령어로 현재 릴리즈 목록을 확인하세요.
