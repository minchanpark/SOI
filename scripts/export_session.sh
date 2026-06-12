#!/usr/bin/env bash
# 디버그 앱(com.newdawn.soi-project)의 SharedPreferences에서 JWT 세션을 추출하여
# scripts/.perf_session.json에 저장합니다.
#
# 사전 조건: iOS 시뮬레이터에서 디버그 앱으로 이미 로그인한 상태
# 사용법:    bash scripts/export_session.sh
set -euo pipefail

DEBUG_BUNDLE_ID="com.newdawn.soi-project"

echo ""
echo "🔑  SOI Session Exporter"
echo "================================"

# ── 앱 데이터 컨테이너 위치 찾기 ─────────────────────────
APP_DATA=$(xcrun simctl get_app_container booted "$DEBUG_BUNDLE_ID" data 2>/dev/null || true)

if [ -z "$APP_DATA" ]; then
  echo "❌  디버그 앱($DEBUG_BUNDLE_ID)을 시뮬레이터에서 찾을 수 없습니다."
  echo "   1. 시뮬레이터를 부팅하세요."
  echo "   2. 디버그 앱을 실행하고 로그인하세요."
  echo "   3. 앱을 종료한 뒤 이 스크립트를 다시 실행하세요."
  exit 1
fi

PLIST="$APP_DATA/Library/Preferences/$DEBUG_BUNDLE_ID.plist"

if [ ! -f "$PLIST" ]; then
  echo "❌  SharedPreferences 파일을 찾을 수 없습니다:"
  echo "   $PLIST"
  echo "   앱을 실행하고 로그인한 뒤 다시 시도하세요."
  exit 1
fi

# ── plist에서 값 읽기 ─────────────────────────────────────
_read() {
  plutil -extract "$1" raw "$PLIST" 2>/dev/null || true
}

ACCESS_TOKEN=$(_read "api_access_token")
REFRESH_TOKEN=$(_read "api_refresh_token")
USER_ID=$(_read "api_user_id")
PHONE=$(_read "api_phone_number")
EXPIRES_ACCESS=$(_read "api_access_token_expires_in_ms")
EXPIRES_REFRESH=$(_read "api_refresh_token_expires_in_ms")
ISSUED_AT=$(_read "api_auth_issued_at_ms")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌  액세스 토큰이 없습니다. 앱에서 로그인을 완료한 뒤 다시 시도하세요."
  exit 1
fi

# ── .perf_session.json 저장 ───────────────────────────────
mkdir -p scripts

cat > scripts/.perf_session.json <<EOF
{
  "accessToken": "$ACCESS_TOKEN",
  "refreshToken": "$REFRESH_TOKEN",
  "userId": ${USER_ID:-0},
  "phoneNumber": "$PHONE",
  "accessTokenExpiresInMs": ${EXPIRES_ACCESS:-0},
  "refreshTokenExpiresInMs": ${EXPIRES_REFRESH:-0},
  "issuedAtMs": ${ISSUED_AT:-0}
}
EOF

echo "✅  세션 추출 완료 → scripts/.perf_session.json"
echo "   User ID : $USER_ID"
echo "   Phone   : $PHONE"
echo ""
echo "이제 bash scripts/run_perf.sh 를 실행하면 완전 자동으로 프로파일링됩니다."
