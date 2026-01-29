# Shorebird 배포 가이드

이 문서는 SOI 프로젝트에서 Shorebird로 **앱 업로드**와 **코드푸시(패치)**를 수행하는 방법을 정리합니다.

## 앱 업로드 (Release 배포)
Shorebird에 앱을 업로드할 때 사용합니다.

```bash
bundle exec fastlane ios upload_shorebird     # iOS 앱 업로드
bundle exec fastlane android upload_shorebird # Android 앱 업로드
```

## 앱 패치 (코드푸시)
기존 설치된 앱에 패치를 배포할 때 사용합니다.

```bash
shorebird patch --platforms=ios     # iOS 앱 패치
shorebird patch --platforms=android # Android 앱 패치
```

## 기본 흐름 (빌드 -> 업로드 -> 패치)
1) **릴리즈 업로드**: 스토어에 올릴 빌드(릴리즈)를 Shorebird에 업로드  
2) **스토어 배포**: 앱스토어/플레이스토어에 정상 배포  
3) **코드푸시 패치**: 스토어에 올라간 앱에 Dart 코드 변경을 패치로 배포  

## Fastlane lane 설명
- `ios upload_shorebird`: iOS 릴리즈 빌드를 생성하고 Shorebird에 업로드합니다.
- `android upload_shorebird`: Android 릴리즈 빌드를 생성하고 Shorebird에 업로드합니다.
  - 안드로이드 Fastlane 자동화는 아직 구축하지 않음.

정확한 빌드 옵션/서명/환경 설정은 `fastlane/Fastfile`의 lane 정의를 참고하세요.

## iOS/Android 주의사항
- **네이티브 변경은 패치로 배포 불가**: iOS/Android 네이티브 코드, 플러그인 업데이트 등은 스토어 업데이트가 필요합니다.
- **패치는 스토어에 배포된 앱에만 적용**: 아직 스토어에 없는 빌드에는 패치가 적용되지 않습니다.
- **버전 관리**: 스토어 업로드용 버전/빌드 넘버는 릴리즈마다 증가해야 합니다.
- **테스트 권장**: 패치 전, 로컬 및 스테이징에서 충분히 검증하세요.
