# SOI AI Agent Playbook v2 (Execution Checklist)

이 문서는 `SOI` 프로젝트 전용 AI 개발 지침서다.  
원칙은 간단하다: 문서보다 코드가 우선이며, 모든 변경은 최소 범위로 안전하게 수행한다.

## User Context
- 사용자는 `SOI`의 Flutter 앱 개발자다.
- 사용자는 Flutter/Dart, REST API, OpenAPI, Provider 상태관리, 비동기 처리에 익숙하다.
- 사용자는 성능, 안정성, 유지보수성을 우선한다.

## Caution
- 본 문서는 `SOI` 프로젝트 전용이다.
- 최종 의사결정권자는 인간 개발자다.
- 민감정보(`.env`, 키/토큰, 개인정보)는 로그/문서에 노출하지 않는다.
- 문서와 코드가 충돌하면 코드(현재 브랜치)를 기준으로 작업한다.

## 0. Source Of Truth & Scope
### 규칙
- 현재 브랜치 코드가 단일 진실 소스다.
- 작업 전 `git branch --show-current`로 브랜치 컨텍스트를 확인한다.
- 본 문서는 운영 가이드이며, 실제 계약은 `api/openapi.yaml` + `api/generated` + `lib/api`로 검증한다.

### 근거 파일
- `lib/main.dart`
- `api/openapi.yaml`
- `api/generated/`
- `lib/api/`

### 실패 시 리스크
- 문서만 믿고 구현하면 실제 API 계약과 불일치할 수 있다.
- 이전 브랜치 가정으로 작업하면 회귀를 유발한다.

### 검증 방법
- `git branch --show-current`
- `git status --short`
- 계약 변경 시 `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`

## 1. Project Snapshot (정밀화)
### 규칙
- SOI는 Flutter 클라이언트 + REST/OpenAPI 기반 구조다.
- API 생성 클라이언트(`api/generated`)와 앱 래퍼(`lib/api`)를 분리해 유지한다.
- 상태관리는 `ChangeNotifier + Provider`를 기본으로 유지한다.
- 앱 엔트리/부트스트랩은 `lib/main.dart`를 기준으로 해석한다.

### 근거 파일
- 엔트리/초기화: `lib/main.dart`
- 의존성: `pubspec.yaml`
- API 생성 패키지: `api/generated/pubspec.yaml`
- 구조 규모(현재 코드 스냅샷):
- `lib` Dart 파일 총 `156`
- `lib/views` `112`, `lib/api` `34`, `lib/utils` `8`

### 실패 시 리스크
- generated/client와 wrapper 책임이 섞이면 재생성 시 대량 파손이 발생한다.
- 엔트리 초기화 순서 오해 시 로그인/딥링크/캐시 동작이 깨진다.

### 검증 방법
- `find lib -type f -name '*.dart' | wc -l`
- `find lib/views -type f -name '*.dart' | wc -l`
- `find lib/api -type f -name '*.dart' | wc -l`
- `sed -n '1,260p' lib/main.dart`

## 2. API 연동 운영 규칙 (api-lib-sync 내재화)
### 규칙
- API 계약 변경 추적은 반드시 영향 탐지 스크립트부터 시작한다.
- 생성 코드(`api/generated/**`)는 수동 수정하지 않는다.
- OpenAPI 변경 반영은 `regen -> patch -> wrapper sync` 순서로 처리한다.
- wrapper 동기화 책임:
- generated `api/model` 변경 -> `lib/api/models/*`
- generated `api/api` 변경 -> `lib/api/services/*`
- 서비스 의미 변경 -> `lib/api/controller/*`
- 계약 체크리스트:
- 요청: 파라미터명/타입/nullable/필수 여부
- 응답: `success/data/message` envelope 및 `data` nullability
- 오류: transport failure와 business absence를 분리

### 근거 파일
- 영향 탐지 스크립트: `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh`
- regen 오케스트레이션: `regen_api.sh`
- 생성 코드 패치: `api/patch_generated.sh`
- generator 설정: `api/config.yaml`
- wrapper 계층: `lib/api/models/`, `lib/api/services/`, `lib/api/controller/`

### 실패 시 리스크
- 생성 코드 직접 hotfix는 다음 regen에서 유실된다.
- 서비스/컨트롤러가 DTO 변경을 흡수하지 못하면 런타임 파싱 실패가 난다.
- `404`를 무조건 null 처리하면 네트워크 장애를 비즈니스 케이스로 오분류할 수 있다.

### 검증 방법
- 영향 탐지:
```bash
./.codex/skills/api-lib-sync/scripts/api_change_impact.sh /Users/minchanpark/Documents/SOI
```
- 재생성:
```bash
./regen_api.sh
```
- wrapper 점검:
```bash
dart analyze lib/api/models lib/api/services lib/api/controller
```

## 3. Provider/상태관리 규칙 (강화)
### 규칙
- 전역 Provider 소유 객체는 화면에서 dispose하지 않는다.
- `lib/main.dart` 전역 등록 컨트롤러를 단일 소유권으로 취급한다.
- 대표 전역 소유 객체:
- `UserController`
- `CategoryController`, `CategorySearchController`
- `PostController`, `FeedDataManager`
- `FriendController`, `CommentController`, `MediaController`
- `NotificationController`, `ContactController`
- `AudioController`, `CommentAudioController`
- `FeedDataManager`는 전역 캐시 유지 목적이므로 화면(`feed_home`)에서 리스너만 detach한다.
- 프레임 중 충돌 가능 구간은 post-frame 스케줄링 패턴을 사용한다.
- async gap 이후 `BuildContext` 재사용 시 `mounted` 또는 의존성 사전 캡처 패턴을 사용한다.
- 사용자 전환 시 캐시는 반드시 리셋한다(`FeedDataManager._lastUserId` 기준).

### 근거 파일
- 전역 Provider 등록: `lib/main.dart`
- 전역 캐시 소유권 패턴: `lib/views/about_feed/feed_home.dart`
- 사용자 전환 리셋: `lib/views/about_feed/manager/feed_data_manager.dart`
- 프레임 충돌 완화 notify 패턴: `lib/api/controller/media_controller.dart`

### 실패 시 리스크
- 전역 객체 dispose 시 `disposed object` 오류 또는 캐시 유실이 발생한다.
- async gap 후 context 오사용 시 크래시/경고가 발생한다.
- 사용자 전환 시 이전 사용자 캐시 노출 문제가 발생한다.

### 검증 방법
- `rg -n "ChangeNotifierProvider|FeedDataManager|dispose\\(" lib/main.dart lib/views/about_feed`
- `rg -n "mounted|context.read|Provider.of" lib/views/about_feed lib/views/about_camera`
- 수동 검증: 로그인 사용자 변경 후 피드/카테고리 데이터 분리 확인

## 4. 미디어 성능 가드레일 (정량 기준)
### 규칙
- 앱 이미지 캐시 한도:
- debug: `maximumSize=50`, `maximumSizeBytes=50MB`
- release: `maximumSize=30`, `maximumSizeBytes=30MB`
- 이미지 업로드는 1MB 목표로 점진 압축을 적용한다.
- 비디오 업로드 제한은 50MB 기준으로 단계 압축한다.
- 비디오 썸네일은 `Memory -> Disk -> Generate` 3-tier 캐시를 사용한다.
- 비디오 자동 재생은 노출 비율 `>= 0.6`에서만 재생한다.
- 대용량 payload/log 출력은 `kDebugMode` 가드 하에서만 허용한다.
- dispose 시 전역 `imageCache.clear()`를 호출하지 않는다.

### 근거 파일
- 이미지 캐시 설정: `lib/main.dart`
- 이미지/비디오 압축 상수: `lib/views/about_camera/photo_editor_screen.dart`
- 3-tier 썸네일 캐시: `lib/utils/video_thumbnail_cache.dart`
- 비디오 노출 임계값: `lib/views/common_widget/api_photo/api_photo_display_widget.dart`
- 프리즈 방지 주석/패턴: `lib/views/about_camera/camera_screen.dart`, `lib/views/about_camera/photo_editor_screen.dart`

### 실패 시 리스크
- 캐시 과다/과소 설정 시 메모리 압박 또는 재디코딩 비용 증가가 발생한다.
- 압축/로그 정책 미준수 시 업로드 실패(413) 또는 프레임 드랍이 발생한다.
- 화면 전환 시 과도한 캐시 정리로 체감 프리즈가 발생한다.

### 검증 방법
- `rg -n "maximumSize|maximumSizeBytes" lib/main.dart`
- `rg -n "_kMaxImageSizeBytes|_kMaxVideoSizeBytes|kDebugMode" lib/views/about_camera/photo_editor_screen.dart`
- `rg -n "visibleFraction >= 0.6|VideoThumbnailCache" lib/views/common_widget/api_photo/api_photo_display_widget.dart lib/views/about_archiving`

## 5. 캐싱 전략 매트릭스
### 규칙
- 캐시는 소유자 단위로 키/TTL/무효화/폴백을 명시적으로 관리한다.
- 캐시 만료와 사용자 전환 이벤트를 분리해 처리한다.

### 근거 파일
- `lib/api/controller/post_controller.dart`
- `lib/api/controller/category_controller.dart`
- `lib/api/controller/notification_controller.dart`
- `lib/api/controller/media_controller.dart`
- `lib/utils/video_thumbnail_cache.dart`
- `lib/api/services/camera_service.dart`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

### 실패 시 리스크
- 만료 정책 누락 시 오래된 데이터 노출이 지속된다.
- 무효화 누락 시 사용자/카테고리 간 데이터 오염이 발생한다.
- 폴백 정책 부재 시 네트워크 일시 오류에서 UX가 급격히 나빠진다.

### 검증 방법
- 아래 매트릭스와 실제 코드 상수/로직을 교차검증한다.

| 소유자 | Key | TTL/한도 | 무효화 트리거 | 폴백 동작 |
|---|---|---|---|---|
| `PostController` | `"$userId:$categoryId:$page"` | `1h` | `notifyPostsChanged()`, `clearAllCache()`, `invalidateCategoryCache()` | 에러 시 만료 캐시 반환 |
| `CategoryController` | `CategoryFilter`별 캐시 + `lastUserId` | `30s` | `invalidateCache()`, 사용자/필터 변경 | 캐시 유효하면 API 생략 |
| `NotificationController` | `cachedResult`, `cachedFriendNotifications` | `30s` | `invalidateCache()` | 캐시 유효 시 즉시 반환 |
| 아카이브 카테고리 포스트 | `"userId:categoryId"` | `30m` | 강제 새로고침, 포스트 변경 리스너 | 만료 캐시 표시 후 백그라운드 갱신 |
| `MediaController` presigned | `fileKey` | `55m` | 만료 시 제거, 새 요청 | in-flight 요청 공유(dedupe) |
| `MediaController` 썸네일 키 매핑 | `videoKey -> thumbnailKey` | LRU `100` | 초과 시 oldest 제거, 수동 clear | 캐시 없으면 생성/업로드 경로 사용 |
| `VideoThumbnailCache` | `postFileKey`(or url) | 메모리+디스크(명시 TTL 없음) | 프로세스/임시파일 정리 시 | Memory miss 시 Disk, 둘 다 miss면 Generate |
| `CameraService` 갤러리 | 첫 Asset 캐시 | `5s` | 촬영/녹화 후 invalidate | miss 시 재조회 |
| `CameraService` 권한 상태 | `PermissionState` | `10s` | 만료 후 재요청 | 권한 캐시 miss 시 native permission 호출 |

## 6. 에러/예외 처리 규칙
### 규칙
- 서비스 레이어는 `SoiApiException` 계층(`BadRequest/Auth/Forbidden/NotFound/Server/Network`)으로 변환한다.
- transport 실패와 business 실패를 반드시 구분한다.
- `404 => null`은 명시 허용된 로그인 신규회원 시나리오에서만 사용한다.
- `getUser`, `getPostDetail` 등 조회 핵심 경로는 `NotFoundException` 또는 명시 에러로 처리한다.

### 근거 파일
- 예외 계층 정의: `lib/api/api_exception.dart`
- 사용자 서비스 transport 분류: `lib/api/services/user_service.dart`
- 서비스별 예외 매핑: `lib/api/services/*.dart`

### 실패 시 리스크
- transport 오류를 `null`로 오분류하면 UI가 잘못된 분기(신규 사용자 등)를 실행한다.
- 예외 계층이 흐트러지면 화면별 오류 메시지 정책이 일관성을 잃는다.

### 검증 방법
- `rg -n "_handleApiException|NetworkException|NotFoundException" lib/api/services`
- 최소 테스트:
```bash
flutter test test/api/services/user_service_test.dart test/api/controller/user_controller_test.dart
```

## 7. 로컬라이제이션 정책 (코드 기준 정정)
### 규칙
- 현재 앱 활성 locale은 `ko`, `es`다.
- `en/ja/zh` 번역 파일은 존재하나 활성 locale 목록에는 포함되지 않는다.
- 신규 사용자 노출 문자열은 최소 `ko/es` 동시 반영을 필수로 한다.
- `en` 반영은 선택이 아니라 릴리즈 전 점검 항목으로 권장한다.
- 키 네임스페이스는 기존 패턴(`common.*`, `camera.editor.*`)을 유지한다.

### 근거 파일
- 활성 locale: `lib/main.dart`
- 번역 파일: `assets/translations/ko.json`, `assets/translations/es.json`, `assets/translations/en.json`, `assets/translations/ja.json`, `assets/translations/zh.json`

### 실패 시 리스크
- 코드와 문서 정책이 다르면 번역 누락/미노출 버그가 릴리즈 직전에 발견된다.
- 하드코딩 문자열 증가로 다국어 회귀 비용이 커진다.

### 검증 방법
- `ls -la assets/translations`
- `rg -n "supportedLocales|fallbackLocale|startLocale" lib/main.dart`

## 8. 고위험 파일 및 점검 시나리오
### 규칙
- 아래 파일은 수정 시 반드시 영향 분석 + 최소 검증 명령을 함께 수행한다.
- 고위험 파일 수정은 “무엇이 깨질 수 있는지”를 먼저 문서화하고 시작한다.

### 근거 파일
- `lib/main.dart`
- `lib/views/about_camera/photo_editor_screen.dart`
- `lib/views/common_widget/api_photo/api_photo_display_widget.dart`
- `lib/views/about_feed/manager/feed_data_manager.dart`
- `lib/api/services/*`
- `lib/api/models/*`

### 실패 시 리스크
- 초기화 순서/딥링크/자동로그인 충돌
- 업로드 파이프라인 병렬 처리 오류
- 비디오 lifecycle 누락으로 배터리/성능 문제
- DTO 매핑 누락으로 런타임 파싱 오류

### 검증 방법
- 파일별 체크포인트:
- `lib/main.dart`: Provider 등록 누락, `SoiApiClient.initialize()`, 캐시 설정
- `lib/views/about_camera/photo_editor_screen.dart`: 압축 상수, 백그라운드 업로드, `kDebugMode` 로그
- `lib/views/common_widget/api_photo/api_photo_display_widget.dart`: 비디오 가시성 임계값, `cacheKey`, lifecycle pause
- `lib/views/about_feed/manager/feed_data_manager.dart`: 사용자 전환 시 reset, 캐시 재사용/forceRefresh 경계
- `lib/api/services/*` + `lib/api/models/*`: DTO 필드/enum/nullability 매핑 일치

## 9. 테스트/검증 섹션 (현실 반영)
### 규칙
- 문서/코드 변경 시 최소 검증 명령을 항상 실행한다.
- wrapper/API 계약 변경은 회귀 시나리오를 명시해 점검한다.

### 근거 파일
- 테스트 파일:
- `test/api/services/user_service_test.dart`
- `test/api/controller/user_controller_test.dart`
- API/모델/컨트롤러 변경 파일:
- `lib/api/models/comment.dart`, `lib/api/models/post.dart`, `lib/api/models/notification.dart`
- `lib/api/services/comment_service.dart`, `lib/api/services/post_service.dart`, `lib/api/services/notification_service.dart`

### 실패 시 리스크
- enum/필드 확장 누락을 배포 후 발견할 수 있다.
- presigned URL 교체 시 이미지 깜빡임 회귀가 재발할 수 있다.
- 캐시 만료/오프라인 fallback 회귀가 사용자 체감 성능을 악화시킨다.

### 검증 방법
- 최소 명령:
```bash
flutter test test/api/services/user_service_test.dart test/api/controller/user_controller_test.dart
dart analyze <changed-files>
```
- 회귀 시나리오 체크:
- `CommentType` `PHOTO`, `REPLY` 매핑
- `PostType`, `savedAspectRatio`, `isFromGallery` 매핑
- presigned URL 변경 시 `cacheKey + useOldImageOnUrlChange` 동작
- 캐시 만료 시 stale fallback 및 강제 갱신 동작

## 10. 공용 API/인터페이스/타입 변경 대응 규칙
### 규칙
- 생성 DTO 변경이 확인되면 앱 도메인 타입과 서비스 파라미터를 동시에 갱신한다.
- 아래 타입/필드는 현재 계약 변화 대응 핵심 항목으로 취급한다.
- `CommentType`: `photo`, `reply`
- `AppNotificationType`: `commentReplyAdded`
- `PostType`: `textOnly`, `multiMedia`
- DTO 필드 확장: `parentId`, `replyUserId`, `fileKey`, `savedAspectRatio`, `isFromGallery`, `postType`

### 근거 파일
- generated 모델:
- `api/generated/lib/model/comment_req_dto.dart`
- `api/generated/lib/model/comment_resp_dto.dart`
- `api/generated/lib/model/notification_resp_dto.dart`
- `api/generated/lib/model/post_create_req_dto.dart`
- `api/generated/lib/model/post_resp_dto.dart`
- `api/generated/lib/model/post_update_req_dto.dart`
- wrapper 반영:
- `lib/api/models/comment.dart`
- `lib/api/models/notification.dart`
- `lib/api/models/post.dart`
- `lib/api/services/comment_service.dart`
- `lib/api/controller/comment_controller.dart`

### 실패 시 리스크
- 서버는 새 필드를 주는데 앱이 무시하면 기능 일부가 silent-fail 된다.
- enum 신규값 미반영 시 파싱/표시 로직이 기본값으로 잘못 분기할 수 있다.

### 검증 방법
- `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh /Users/minchanpark/Documents/SOI`
- `rg -n "PHOTO|REPLY|commentReplyAdded|savedAspectRatio|isFromGallery|postType" lib/api`

## 11. 작업 절차(Agent Workflow)
### 규칙
- 모든 작업은 아래 순서를 따른다.
- 목표/범위 재확인 -> 영향 파일 탐색 -> 최소 변경 구현 -> 검증 실행 -> 결과/리스크 보고
- 대규모 리팩터링은 사용자 명시 요청이 없으면 금지한다.

### 근거 파일
- 본 문서 전체

### 실패 시 리스크
- 범위가 커지면 회귀 지점이 폭증하고 리뷰 비용이 급증한다.

### 검증 방법
- 작업 보고 시 아래 항목을 포함한다.
- 변경 요약
- 수정 파일 목록
- 주요 변경점
- 실행한 검증 명령과 결과
- 남은 리스크

## 12. 가정 및 기본값
### 규칙
- 본 v2 문서는 `docs/AI_AGENT_PLAYBOOK.md` 단일 파일 기준으로 유지한다.
- 문체는 실행 체크리스트 중심으로 유지한다.
- 성능/캐싱 정책은 정량 수치를 우선 반영한다.

### 근거 파일
- `docs/AI_AGENT_PLAYBOOK.md`

### 실패 시 리스크
- 문서가 다시 서술형으로 퍼지면 자동화/검증 일관성이 떨어진다.

### 검증 방법
- 변경 시 본 문서 내 모든 정량값이 코드 상수와 일치하는지 교차검증한다.
