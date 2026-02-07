# Firebase App Distribution 배포 가이드

이 문서는 SOI 프로젝트에서 Shorebird와 Firebase App Distribution을 사용하여 **테스터에게 앱을 배분**하는 방법을 정리합니다.

## 개요

| 배포 채널 | 용도 | 빌드 형식 |
|-----------|------|-----------|
| Play Store | 공개 배포 | AAB |
| Firebase App Distribution | 내부 테스트 배분 | APK |

Firebase App Distribution는 Play Store 심사 없이 테스터들에게 APK를 직접 배분하는 서비스입니다.

## 사전 준비

다음 항목이 이미 구성되어 있습니다:

- Firebase CLI 설치됨
- Firebase 프로젝트: `soi-sns`
- Android App ID: `1:1074708164096:android:19028b18cbc5512a4d32e5`
- 패키지 이름: `com.newdawn.soi`

## 배포 흐름

### 1단계. APK 빌드

Shorebird로 빌드하면 코드푸시(패치) 기능도 포함됩니다.

```bash
shorebird release android --artifact apk
# 출력 경로: build/app/outputs/flutter-apk/app-release.apk
```

> **참고**: 동일 버전이 이미 Shorebird에 등록되어 있으면 오류가 발생합니다.
> 이 경우 `pubspec.yaml`의 build number를 올려서 재시도하세요.
> ```yaml
> version: 1.0.3+47  # +1 증가
> ```

### 2단계. Firebase App Distribution 업로드

```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:1074708164096:android:19028b18cbc5512a4d32e5 \
  --release-notes "v1.0.3 - 내부 테스트 빌드"
```

테스터를 명령에 직접 포함할 수도 있습니다:

```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:1074708164096:android:19028b18cbc5512a4d32e5 \
  --testers "테스터1@gmail.com,테스터2@gmail.com" \
  --release-notes "v1.0.3 - 내부 테스트 빌드"
```

그룹 단위로 초대할 경우:

```bash
  --tester-groups "내부테스트"
```

### 3단계. 테스터 초대 (Firebase Console)

명령에 테스터를 지정하지 않은 경우, Console에서 직접 초대할 수 있습니다.

1. [Firebase Console → App Distribution](https://console.firebase.google.com/project/soi-sns/appdistribution/app/android:com.newdawn.soi/releases) 접근
2. 릴리즈 목록에서 해당 버전 클릭
3. **테스터 및 그룹** 탭 → 테스터 이메일 추가
4. 초대 메일이 테스터에게 자동 전송됨

## 테스터 측 다운로드 흐름

1. 초대 이메일 수신
2. 이메일에서 "앱 설치" 클릭
3. Android 설정에서 **"알 수 없는 앱 설치"(Unknown sources)** 허용
4. APK 설치 완료 → 앱 실행

## Play Store 배포와의 차이

| | Firebase App Distribution | Play Store |
|---|---|---|
| 빌드 형식 | APK | AAB |
| 심사 여부 | 없음 | 있음 |
| 빌드 명령 | `shorebird release android --artifact apk` | `shorebird release android` |
| 업로드 명령 | `firebase appdistribution:distribute` | `fastlane upload_shorebird` |

## 트러블슈팅

### 패키지 이름 불일치 오류
Firebase Console에 등록된 앱의 패키지 이름과 APK의 `applicationId`가 일치해야 합니다.
- APK의 `applicationId`: `android/app/build.gradle.kts` 확인
- Firebase 등록 패키지 이름: [Firebase Console → 앱 설정](https://console.firebase.google.com/project/soi-sns/settings/general) 확인

### Shorebird 중복 릴리즈 오류
`pubspec.yaml`의 build number를 올려서 재시도합니다.
현재 릴리즈 목록 확인:
```bash
shorebird releases list
```

### Firebase CLI 로그인 오류
```bash
firebase login
```
