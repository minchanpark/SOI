# CocoaPods 반복 배포 실패 해결 가이드

## 📋 문제 상황

**증상**: Fastlane으로 첫 번째 배포는 성공하지만, 두 번째 이후 배포에서 다음 에러 발생
```
Warning: CocoaPods is installed but broken. Skipping pod install.
You appear to have CocoaPods installed but it is not working.
This can happen if the version of Ruby that CocoaPods was installed with is different from the one being used to invoke it.
```

**근본 원인**: 
1. CocoaPods 상태 손상 (Ruby 버전 불일치)
2. Podfile.lock과 Pods 폴더 간 불일치
3. Flutter 빌드 캐시 간섭

## ✅ 적용된 해결책

### 1. Fastfile 자동화 개선
`ios/fastlane/Fastfile`을 다음과 같이 수정했습니다:

```ruby
lane :deploy_to_testflight do
  # 0. 환경 정리 및 준비
  sh "cd .. && flutter clean"                    # Flutter 캐시 정리
  sh "cd .. && flutter pub get"                  # Dart 패키지 재설치
  sh "cd ../ios && pod install --repo-update"   # CocoaPods 완전 재설치
  
  # 1. Flutter 빌드
  sh "cd .. && flutter build ipa --release"
  
  # 나머지 로직...
end
```

**핵심 개선사항**:
- `flutter clean`: 모든 Flutter 빌드 캐시 제거
- `flutter pub get`: Dart 의존성 재설치
- `pod install --repo-update`: **중요** - CocoaPods 리포지토리 업데이트하며 재설치

### 2. 수동 리셋 스크립트
`ios/cocoapods_reset.sh` 생성 - 문제 발생 시 수동 실행 가능

```bash
cd ios
./cocoapods_reset.sh
```

## 🚀 사용 방법

### 정상 배포
```bash
cd ios
bundle exec fastlane ios deploy_to_testflight
```

이제 자동으로 매번 깨끗한 상태에서 빌드합니다.

### 여전히 문제 발생 시
```bash
cd ios
./cocoapods_reset.sh
cd ..
flutter clean
flutter pub get
bundle exec fastlane ios deploy_to_testflight
```

## ⚡ 성능 참고사항

- **빌드 시간 증가**: `pod install --repo-update` 때문에 초기 빌드는 더 오래 걸림 (약 1-2분 추가)
- **이후 빌드**: 캐시 덕분에 이후 배포는 더 빠를 수 있음
- **안정성**: 반복 배포 실패 0% (예상)

## 🔍 추가 팁

### Podfile.lock 관리
```bash
# Podfile.lock을 git에서 제외하려면:
echo "Podfile.lock" >> .gitignore
```

### Ruby 버전 확인
```bash
ruby --version
gem which cocoapods
```

### CocoaPods 재설치 필요 시
```bash
sudo gem install cocoapods
pod setup
```

## 📝 주의사항

1. ✅ `.gitignore`에 다음 항목이 포함되어 있으면 좋음:
   - `ios/Pods/`
   - `ios/Podfile.lock` (선택사항)

2. ✅ 매번 `pod install --repo-update` 실행되므로 인터넷 필수

3. ✅ 만약 repo 업데이트가 느리면, `pod install` (repo-update 제외)만 사용 가능

## 🎯 예상 결과

이제 다음과 같이 작동합니다:
```
✅ 첫 번째 배포: 성공
✅ 두 번째 배포: 성공 (이전에는 실패)
✅ 세 번째+ 배포: 계속 성공
```
