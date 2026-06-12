#!/usr/bin/env bash
# SOI Performance Profiler — 완전 자동화 버전
#
# 사전 조건 (최초 1회):
#   1. 시뮬레이터에서 디버그 앱으로 로그인
#   2. bash scripts/export_session.sh  실행
#
# 이후 매번:
#   bash scripts/run_perf.sh
#
# 옵션:
#   bash scripts/run_perf.sh [device-id]
set -euo pipefail

SESSION_FILE="scripts/.perf_session.json"

echo ""
echo "🔧  SOI Performance Profiler"
echo "================================"

# ── 세션 파일 확인 ────────────────────────────────────────
if [ ! -f "$SESSION_FILE" ]; then
  echo "❌  세션 파일이 없습니다. 먼저 한 번만 실행하세요:"
  echo "   bash scripts/export_session.sh"
  exit 1
fi

# ── 세션 값 파싱 ──────────────────────────────────────────
_json() { python3 -c "import json,sys; d=json.load(open('$SESSION_FILE')); print(d.get('$1',''))" ; }

ACCESS_TOKEN=$(_json accessToken)
REFRESH_TOKEN=$(_json refreshToken)
USER_ID=$(_json userId)
PHONE=$(_json phoneNumber)
EXPIRES_ACCESS=$(_json accessTokenExpiresInMs)
EXPIRES_REFRESH=$(_json refreshTokenExpiresInMs)
ISSUED_AT=$(_json issuedAtMs)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌  세션 파일에 토큰이 없습니다. export_session.sh 를 다시 실행하세요."
  exit 1
fi

echo "🔑  세션 로드됨 (User: $USER_ID)"

# ── 디바이스 선택 ──────────────────────────────────────────
if [ -n "${1:-}" ]; then
  DEVICE="$1"
else
  DEVICE=$(flutter devices --machine 2>/dev/null \
    | python3 -c "
import sys, json
try:
    devices = json.load(sys.stdin)
    for d in devices:
        plat = d.get('targetPlatform', '')
        if any(p in plat for p in ['ios', 'android-arm', 'android-x64']):
            print(d['id']); break
    else:
        for d in devices:
            if d.get('emulator') or 'simulator' in d.get('name','').lower():
                print(d['id']); break
except Exception:
    pass
" 2>/dev/null || true)
fi

if [ -z "$DEVICE" ]; then
  echo "❌  연결된 디바이스가 없습니다. 시뮬레이터를 켜거나 기기를 연결하세요."
  exit 1
fi
echo "📱  Device: $DEVICE"

# ── 이전 결과 정리 ────────────────────────────────────────
rm -f build/*.timeline.json build/*.timeline_summary.json 2>/dev/null || true

# ── flutter drive 실행 ────────────────────────────────────
echo ""
echo "🚀  Profile 빌드 + 통합 테스트 실행 중..."
echo "   (첫 실행은 빌드로 인해 3~5분 소요, 이후는 빠름)"
echo ""

flutter drive \
  --profile \
  --device-id="$DEVICE" \
  --target=integration_test/perf_test.dart \
  --driver=test_driver/driver.dart \
  --dart-define="PERF_ACCESS_TOKEN=$ACCESS_TOKEN" \
  --dart-define="PERF_REFRESH_TOKEN=$REFRESH_TOKEN" \
  --dart-define="PERF_USER_ID=$USER_ID" \
  --dart-define="PERF_PHONE=$PHONE" \
  --dart-define="PERF_EXPIRES_ACCESS=$EXPIRES_ACCESS" \
  --dart-define="PERF_EXPIRES_REFRESH=$EXPIRES_REFRESH" \
  --dart-define="PERF_ISSUED_AT=$ISSUED_AT" \
  2>&1 | grep -v "^$" | tail -20

# ── 타임라인 분석 ─────────────────────────────────────────
echo ""
echo "📊  타임라인 분석 중..."
dart run scripts/analyze_timeline.dart

STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo ""
  echo "💡  상세 분석:"
  echo "   build/*.timeline.json → DevTools > Performance 탭에서 프레임별 이벤트 확인"
fi
exit $STATUS
