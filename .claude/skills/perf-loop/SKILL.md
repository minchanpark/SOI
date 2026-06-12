---
name: perf-loop
description: SOI 앱의 성능 병목을 자동 프로파일링하고, 원인을 분석하고, 코드 수정까지 완료하는 전체 자동화 루프.
  "성능 분석", "병목 찾아줘", "느린 곳 고쳐줘", "프로파일링", "perf-loop" 등에 트리거된다.
  스크립트 실행 → VM 프로파일 수집 → 서브 에이전트 병렬 분석 → 수정 계획 → 코드 수정 → 검증까지 전부 수행한다.
---

# SOI 성능 자동화 루프

## 역할

성능 데이터를 스스로 수집하고, 서브 에이전트를 병렬로 투입해 병목 원인을 코드 수준까지 추적하고, 우선순위가 높은 것부터 수정하고, 재측정으로 개선을 검증한다. 사람이 중간에 개입하지 않아도 되는 완전 자동화 루프가 목표다.

---

## 사전 확인 (스킬 진입 직후 반드시 실행)

### Step 1 — 디바이스 확인

```bash
flutter devices --machine 2>/dev/null | python3 -c "
import sys, json
devs = json.load(sys.stdin)
real = [d for d in devs if any(p in d.get('targetPlatform','') for p in ['ios','android-arm','android-x64'])]
sims = [d for d in devs if d.get('emulator') or 'simulator' in d.get('name','').lower()]
print(len(real + sims))
"
```

- 0이면: 사용자에게 시뮬레이터 기동 요청 후 중단. **에이전트가 기동할 수 없음.**

### Step 2 — 세션 자동 확보

```bash
ls scripts/.perf_session.json 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

**MISSING이면 → 자동으로 export 시도:**

```bash
bash scripts/export_session.sh
```

- 성공(exit 0): 계속 진행.
- 실패(exit 1): 디버그 앱이 로그인 상태가 아님.
  → 사용자에게 안내:
  ```
  ❌ 자동 세션 확보 실패.
  딱 한 번만 수동으로 하면 됩니다:
    1. 시뮬레이터에서 SOI 디버그 앱 실행
    2. 로그인 (SMS 인증 — 에이전트가 대신할 수 없는 유일한 수동 단계)
    3. 앱 종료 후 /perf-loop 재실행
  ```
  → 이후 중단.

**EXISTS이면 → 세션 유효성 확인:**

```bash
python3 -c "
import json, time
d = json.load(open('scripts/.perf_session.json'))
token = d.get('accessToken', '')
exp = d.get('refreshTokenExpiresInMs', 0)
now = int(time.time() * 1000)
if not token:
    print('EMPTY')
elif exp > 0 and now > exp:
    print('EXPIRED')
else:
    print('OK')
"
```

- `EMPTY` / `EXPIRED`: `bash scripts/export_session.sh` 재실행. 실패하면 로그인 안내 후 중단.
- `OK`: Phase 1로 진입.

---

## Phase 1 — 프로파일 수집

```bash
bash scripts/run_profile_session.sh 2>&1
```

- 완료까지 대기 (최대 5분). 중간 로그를 사용자에게 실시간으로 보여준다.
- 완료 후 생성 파일 확인:
  - `build/cpu_profile_report.json` (CPU 핫스팟)
  - `build/*.timeline_summary.json` (프레임 타이밍)
- 두 파일 모두 없으면 에러 원인을 파악하고 재시도 1회.

---

## Phase 2 — 병렬 분석 (서브 에이전트 2개 동시 실행)

**두 에이전트를 단일 메시지에서 동시에 실행한다.**

### 에이전트 A — CPU 핫스팟 코드 추적 (subagent_type: Explore)

프롬프트 골자:
```
build/cpu_profile_report.json 을 읽어라.
hotFunctions 중 inclusiveCpuPct >= 5% 인 항목을 대상으로:
1. uri 필드로 해당 소스 파일을 Read 한다.
2. 함수명으로 Grep해서 정확한 위치를 찾는다.
3. 해당 함수의 build() / compute 로직을 읽고 왜 무거운지 판단한다.
   - const 누락? setState 범위 과다? build()내 연산? 
   - API 호출 중복? 캐시 미스?
4. 각 핫스팟에 대해 다음을 출력한다:
   { "file": "...", "function": "...", "pct": N, "cause": "...", "fix": "..." }
조사 결과를 JSON 배열로 반환하라. 파일은 수정하지 말 것.
```

### 에이전트 B — Timeline Jank 패턴 분석 (subagent_type: Explore)

프롬프트 골자:
```
build/*.timeline_summary.json 을 읽어라.
다음 지표를 추출한다:
- missed_frame_build_budget_count (UI jank)
- missed_frame_rasterizer_budget_count (GPU jank)
- average / 90th / 99th percentile build time
- average / 90th rasterizer time

UI jank > 3 이면:
  → lib/views/ 에서 Consumer/Selector 사용 패턴을 Grep으로 조사
  → 과도하게 넓은 범위의 rebuild 가능성 확인
GPU jank > 3 이면:
  → Opacity, ClipPath, BackdropFilter, saveLayer 사용처를 Grep으로 조사
average build > 8ms 이면:
  → ListView 가 builder 패턴인지, itemExtent 가 있는지 확인

결과를 { "uiJank": N, "gpuJank": N, "suspectedCause": "...", "locations": [...] } 형태로 반환하라.
파일은 수정하지 말 것.
```

---

## Phase 3 — 종합 진단 및 수정 계획 수립

두 에이전트 결과를 합산해 **우선순위 목록** 을 만든다.

우선순위 기준:
1. CPU pct >= 15% → 즉시 수정
2. CPU pct 5–14% + timeline jank 동반 → 수정
3. GPU jank만 있는 경우 → 렌더링 최적화
4. CPU pct < 5% + jank 없음 → 기록만 하고 수정 안 함

목록 형식 (사용자에게 보여준다):
```
수정 계획
─────────────────────────────
[P1] FeedItem.build (23%) — const 위젯 누락, build()내 정렬 연산
     파일: lib/views/about_feed/widgets/feed_item.dart

[P2] ApiPhotoDisplayWidget (11%) — Selector 범위 과다
     파일: lib/views/common_widget/api_photo/api_photo_display_widget.dart

[P3] GPU jank 8프레임 — Opacity 중첩 의심
     파일: lib/views/about_feed/feed_home.dart
─────────────────────────────
수정을 시작할까요? (자동 진행)
```

사용자 확인 없이 자동 진행한다. (단, 고위험 파일 — CLAUDE.md §8 — 이 포함된 경우는 명시 후 진행)

---

## Phase 4 — 코드 수정

P1부터 순서대로 수정한다. 각 항목마다:

1. 해당 파일 전체를 `Read` 한다.
2. 관련 `extension/` 파일이 있으면 함께 읽는다 (CLAUDE.md §14).
3. 최소 변경으로 수정한다. 리팩터링 금지, 요청 범위만.
4. 수정 후 즉시:
   ```bash
   dart analyze <수정된_파일>
   ```
5. 분석 오류 없으면 다음 항목으로.

**Flutter 성능 수정 패턴 (우선 적용):**

```
const 위젯화:
  - StatelessWidget의 생성자에 const 가능하면 추가
  - 내부 변하지 않는 자식에 const 추가

Selector 범위 축소:
  - Consumer<XController> → Selector<XController, T> 로 교체
  - rebuild 트리거 타입 T 를 최소화

build() 내 연산 제거:
  - 정렬/필터/파싱 → initState 또는 Controller로 이동
  - 반복적 DateTime.now() → 캐시

ListView 최적화:
  - ListView → ListView.builder
  - itemExtent 또는 SliverFixedExtentList 적용

Opacity 대체:
  - Opacity(opacity: 1.0) → 제거
  - AnimatedOpacity 대신 Visibility 고려
  - 여러 Opacity 중첩 → 단일 Opacity로 합침
```

---

## Phase 5 — 검증

### 정적 검증

```bash
dart analyze lib/main.dart lib/app lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving lib/views/common_widget
```

```bash
flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart
```

### 동적 검증 (선택)

분석/수정에 1개 이상의 P1 항목이 있었으면 자동으로 재측정:

```bash
bash scripts/run_profile_session.sh 2>&1
```

전후 비교:
```
              이전       이후
UI avg        12.3ms  →  ?ms
jank 프레임     8      →  ?
CPU P1 핫스팟  23.4%   →  ?
```

개선이 없거나 악화됐으면 수정을 되돌리고 원인을 보고한다.

---

## 결과 보고 형식

```
═══════════════════════════════════════
  perf-loop 완료 보고
═══════════════════════════════════════
수정 파일: N개
  - lib/views/.../feed_item.dart
  - lib/views/.../api_photo_display_widget.dart

성능 개선:
  UI avg   12.3ms → 6.1ms  (-50%)
  jank     8프레임 → 1프레임

잔여 리스크:
  - lib/views/.../feed_home.dart 의 GPU jank 원인 미확정
    (build/*.timeline.json → DevTools에서 상세 확인 필요)
═══════════════════════════════════════
```

---

## 주의 사항

- `api/generated/**` 수정 금지 (CLAUDE.md §3).
- 고위험 파일 수정 시 "무엇이 깨질 수 있는지" 먼저 명시.
- 성능 수치 없이 추정으로 코드 변경 금지 — 반드시 프로파일 데이터 기반.
- 재측정 없이 "개선됨"이라고 보고 금지.
