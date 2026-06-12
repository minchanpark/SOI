---
name: soi-optimizer
description: SOI Flutter 프로젝트의 코드 성능 최적화 전문 스킬.
  특정 파일, 위젯, 컨트롤러, 서비스, 또는 로직 전체를 최적화해달라고 요청할 때 반드시 사용한다.
  "최적화해줘", "성능 개선해줘", "느린 것 같아", "빠르게 만들어줘", "리빌드 줄여줘", "캐시 개선",
  "메모리 줄여줘", "렌더링 최적화", "로직 개선" 등의 요청에 반드시 트리거된다.
  결과는 항상 직접 코드 수정 + 테스트 작성 + 검증 실행이다.
---

# SOI 성능 최적화 스킬

## 역할

SOI Flutter 프로젝트의 아키텍처(Provider + ChangeNotifier + 계층화된 서비스)와 캐시 정책을 완전히 이해한 상태에서, 요청된 코드를 분석하고 최적화한 뒤 테스트까지 수행한다.

---

## 작업 순서 (항상 이 순서대로)

### 1단계: 대상 파악 및 분석

- 사용자가 지정한 파일/로직을 `Read` 도구로 읽는다.
- 대상이 여러 레이어에 걸쳐 있다면, 관련된 controller / service / model / view를 모두 확인한다.
- 고위험 파일(`AGENTS.md §8` 목록)인지 확인한다. 해당하면 "이 파일은 고위험 파일입니다. 변경 시 주의 사항을 먼저 명시하겠습니다."라고 선언한다.
- 빠른 텍스트/경로 검색은 `Grep`, 파일 조회는 `Read`, 수동 편집은 `Edit`를 사용한다.

### 2단계: 병목/낭비 진단

아래 체크리스트를 순서대로 적용하여 실제 문제만 골라낸다. 문제가 없는 항목은 넘어간다.

**빌드/리빌드 최적화**
- `Consumer` / `Selector` 범위가 지나치게 넓어 불필요한 리빌드가 발생하는가?
- `const` 생성자 사용 가능한 위젯에 `const`가 빠져 있는가?
- `setState`가 작은 변경에 대해 전체 트리를 리빌드하는가?
- `AnimatedBuilder` / `ListenableBuilder`로 범위를 좁힐 수 있는가?
- `ListView`가 크다면 `ListView.builder` + `itemExtent` / `SliverFixedExtentList`로 교체 가능한가?

**캐시 및 상태 관리**
- Controller의 TTL 정책이 `AGENTS.md §6`과 일치하는가?
  - PostController: key `userId:categoryId:page`, TTL 1h
  - CategoryController: TTL 30s
  - NotificationController: TTL 30s (전체), 친구 알림은 최근 결과 캐시
  - MediaController presigned URL: TTL 55m, in-flight dedupe
  - CameraService: 갤러리 첫 이미지 5s, 권한 상태 10s
- 동일한 데이터를 여러 번 fetch하는가 (in-flight dedupe 누락)?
- 캐시 무효화가 과도하게 넓은가 (e.g., 관계없는 카테고리까지 초기화)?
- `FeedDataManager.reset(notify: false)` + `forceRefresh` 패턴이 올바르게 쓰이는가?

**비동기/메모리**
- async gap 이후 `mounted` 체크가 누락되었는가?
- `dispose`에서 전역 `imageCache.clear()` 호출이 있는가? → **현재 항목 evict만** 허용
- `StreamSubscription` / `Timer` / `AnimationController`가 dispose에서 cancel/dispose되는가?
- `Future.wait`로 병렬화 가능한 순차 `await`가 있는가?

**미디어 성능**
- 이미지 캐시 크기가 `AGENTS.md §5` 기준(debug: 50개/50MB, release: 30개/30MB)을 초과하는가?
- 비디오 자동재생 임계값이 `>= 0.6` 가시성인가?
- VideoThumbnailCache (Memory LRU 120개, 12MB) → MediaController LRU 100개 체인이 올바른가?

**계산 낭비**
- `getter` 내에서 매번 새 컬렉션을 생성하는가? → 캐시 or `UnmodifiableListView`
- `String` interpolation / `+` 연결이 반복 루프 안에 있는가? → `StringBuffer`
- 정렬/필터가 매 `build`마다 실행되는가? → memoize 또는 controller에서 관리

### 3단계: 수정 계획 수립 (선행 공유)

실제 코드를 수정하기 전에, 다음을 사람이 읽을 수 있는 형식으로 제시한다:

```
[변경 요약]
- 파일: lib/...
- 문제: <구체적인 문제>
- 수정: <무엇을 어떻게>
- 예상 효과: <측정 가능한 개선>
- 깨질 수 있는 것: <없으면 "없음">
```

복잡한 변경이 여러 파일에 걸친다면, `TodoWrite`로 작업 목록을 관리하며 순차적으로 처리한다. 독립적인 파일 수정은 병렬 도구 호출로 처리 속도를 높인다.

### 4단계: 코드 수정

- 아키텍처 경계(`AGENTS.md §3`)를 지킨다: 생성 코드(`api/generated/**`)는 절대 수동 수정 금지.
- 최소 변경 원칙: 요청 범위 밖의 코드는 건드리지 않는다.
- 고위험 파일 수정 시: 깨질 수 있는 것을 먼저 명시하고 수정한다.
- Provider lifecycle: 화면에서 전역 컨트롤러 dispose 금지.
- 로컬라이제이션: 사용자 노출 문자열 하드코딩 금지, `tr()` 사용.
- 파일 수정은 `Edit` 도구, 새 파일 생성은 `Write` 도구를 사용한다.

### 5단계: 테스트 작성

변경한 로직마다 테스트를 작성한다. 기존 테스트 파일이 있으면 거기에 추가, 없으면 대응하는 위치에 새 파일 생성.

- 컨트롤러 변경 → `test/api/controller/<name>_test.dart`
- 서비스 변경 → `test/api/services/<name>_test.dart`
- 모델 변경 → `test/api/models/<name>_test.dart`
- 뷰/매니저 변경 → `test/views/<path>/<name>_test.dart`

테스트는 다음을 커버한다:
- 정상 경로 (happy path)
- 캐시 히트/미스 동작 (캐시 관련 변경 시)
- TTL 만료 후 재fetch (TTL 변경 시)
- dispose 후 호출 안전성 (lifecycle 관련 변경 시)

### 6단계: 검증 실행

수정과 테스트 작성이 끝나면 **반드시** 아래 명령을 `Bash` 도구로 순서대로 실행한다:

```bash
# 1. 정적 분석
dart analyze lib/main.dart lib/app lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving lib/views/common_widget

# 2. 핵심 테스트 스위트
flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/services/notification_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart

# 3. 새로 작성한 테스트
flutter test <새로 작성한 테스트 파일 경로>
```

오류가 있으면 즉시 수정 후 재실행한다. 모든 테스트가 통과해야 완료다.

### 7단계: 결과 보고

```
[최적화 결과 요약]
수정 파일:
- lib/... (변경 내용 한 줄 요약)

적용된 최적화:
- <최적화 항목 1>: <이유>
- <최적화 항목 2>: <이유>

검증 결과:
- dart analyze: 통과 / 경고 N개 (목록)
- flutter test: N/N 통과

미검증 리스크:
- <없으면 "없음">
```

---

## 병렬 도구 호출 기준

변경 범위가 넓을 때 병렬 도구 호출로 시간을 절약한다:

- **분석 단계**: 여러 파일을 동시에 읽어야 할 때 → 여러 `Read` 호출을 한 번의 턴에서 동시에 실행.
- **수정 단계**: 서로 독립적인 파일 수정 → 여러 `Edit` 또는 `Write` 호출을 동시에 실행.
- **테스트 단계**: 여러 테스트 파일 작성 → 여러 파일 동시 수정.

---

## 금지 사항 (절대 하지 않는 것)

- `api/generated/**` 수동 수정
- `dispose`에서 전역 `imageCache.clear()` 호출
- 화면(View)에서 전역 컨트롤러 dispose
- async gap 후 `mounted` 체크 없이 context 사용
- 요청 범위 밖의 코드 "개선"
- 테스트 없이 완료 선언

---

## 참고: SOI 아키텍처 빠른 참조

```
lib/
├── app/          → 부트스트랩, 전역 Provider, 라우트/로케일 상수
├── api/
│   ├── models/   → 도메인 모델/매핑
│   ├── services/ → API 호출/DTO/예외 변환
│   └── controller/ → UI 상태/흐름 오케스트레이션 (ChangeNotifier)
├── utils/        → 공용 유틸, 캐시 인프라 (VideoThumbnailCache 등)
└── views/        → 화면/UI (extension/ 패턴으로 분리)
```

전역 싱글턴: `SoiApiClient.instance`, `AppPushCoordinator.instance`
전역 캐시 owner: `FeedDataManager` (화면에서는 `detachFromPostController()`만 호출)
