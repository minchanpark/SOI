#!/usr/bin/env bash
# SOI 완전 자동 프로파일링 세션
#
# 에이전트가 실행하는 진입점:
#   bash scripts/run_profile_session.sh
#
# 흐름:
#   1. 세션 주입 → flutter drive --profile (앱 실행 + 피드 조작)
#   2. VM service URL 캡처 → vm_profiler.dart 병렬 실행
#   3. 테스트 완료 → 프로파일러 종료 → CPU 리포트 저장
#   4. 분석 스크립트 실행 → 병목 요약 출력
set -euo pipefail

SESSION_FILE="scripts/.perf_session.json"
DRIVE_LOG="/tmp/soi_flutter_drive.log"
CPU_REPORT="build/cpu_profile_report.json"
TIMELINE_SUMMARY_GLOB="build/*.timeline_summary.json"

echo ""
echo "═══════════════════════════════════════════"
echo "  🤖  SOI Auto Profiler"
echo "═══════════════════════════════════════════"

# ── 세션 확인 ─────────────────────────────────────────────
if [ ! -f "$SESSION_FILE" ]; then
  echo "❌  세션 없음. 먼저 실행:"
  echo "   bash scripts/export_session.sh"
  exit 1
fi

_json() { python3 -c "import json; d=json.load(open('$SESSION_FILE')); print(d.get('$1',''))" ; }
ACCESS_TOKEN=$(_json accessToken)
REFRESH_TOKEN=$(_json refreshToken)
USER_ID=$(_json userId)
PHONE=$(_json phoneNumber)
EXPIRES_ACCESS=$(_json accessTokenExpiresInMs)
EXPIRES_REFRESH=$(_json refreshTokenExpiresInMs)
ISSUED_AT=$(_json issuedAtMs)

echo "🔑  세션 로드 (User: $USER_ID)"

# ── 디바이스 선택 ─────────────────────────────────────────
DEVICE=$(flutter devices --machine 2>/dev/null \
  | python3 -c "
import sys,json
try:
  devs=json.load(sys.stdin)
  for d in devs:
    p=d.get('targetPlatform','')
    if any(x in p for x in ['ios','android-arm','android-x64']): print(d['id']); break
  else:
    for d in devs:
      if d.get('emulator') or 'simulator' in d.get('name','').lower(): print(d['id']); break
except: pass
" 2>/dev/null || true)

[ -z "$DEVICE" ] && { echo "❌  디바이스 없음"; exit 1; }
echo "📱  Device: $DEVICE"

# ── 이전 결과 정리 ────────────────────────────────────────
rm -f build/*.timeline.json build/*.timeline_summary.json "$CPU_REPORT" "$DRIVE_LOG" 2>/dev/null || true
mkdir -p build

# ── flutter drive 백그라운드 실행 ─────────────────────────
echo ""
echo "🚀  flutter drive --profile 시작..."

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
  2>&1 | tee "$DRIVE_LOG" &
DRIVE_PID=$!

# ── VM service URL 대기 (최대 120s) ──────────────────────
echo "⏳  VM service URL 대기 중..."
VM_URL=""
for i in $(seq 1 120); do
  VM_URL=$(grep -oE 'http://127\.0\.0\.1:[0-9]+/[^/ ]+/' "$DRIVE_LOG" 2>/dev/null | head -1 || true)
  [ -n "$VM_URL" ] && break
  sleep 1
  # flutter drive 가 일찍 종료되면 중단
  kill -0 $DRIVE_PID 2>/dev/null || { echo "⚠️  flutter drive 가 예상보다 일찍 종료됨"; break; }
done

PROFILER_PID=""
if [ -n "$VM_URL" ]; then
  echo "🔗  VM service: $VM_URL"

  # ── vm_profiler 병렬 실행 ────────────────────────────
  (cd scripts/profiler && dart run bin/vm_profiler.dart "$VM_URL" "../../$CPU_REPORT") &
  PROFILER_PID=$!
  echo "🔬  vm_profiler 시작 (PID: $PROFILER_PID)"
else
  echo "⚠️  VM service URL을 찾지 못함 — CPU 프로파일 없이 진행"
fi

# ── flutter drive 완료 대기 ───────────────────────────────
echo "⏱️   테스트 실행 중 (피드 스크롤, 탭 전환)..."
wait $DRIVE_PID || true
echo "✅  flutter drive 완료"

# ── 프로파일러 종료 신호 ──────────────────────────────────
if [ -n "$PROFILER_PID" ]; then
  sleep 1
  kill -INT $PROFILER_PID 2>/dev/null || true
  wait $PROFILER_PID 2>/dev/null || true
  echo "✅  vm_profiler 완료"
fi

# ── 결과 분석 ────────────────────────────────────────────
echo ""
echo "📊  분석 중..."
dart run scripts/analyze_results.dart

echo ""
echo "───────────────────────────────────────────"
echo "📁  원본 데이터:"
ls build/*.timeline_summary.json "$CPU_REPORT" 2>/dev/null | sed 's/^/   /'
echo "───────────────────────────────────────────"
