#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./regen_api.sh [--no-backup]

Runs the full OpenAPI regeneration flow:
  1) Download latest OpenAPI spec to api/openapi.yaml
  2) Backup api/generated (optional; default on)
  3) Regenerate with openapi-generator using api/config.yaml
  4) Run api/patch_generated.sh (required)
  5) flutter pub get in api/generated
  6) flutter pub get in repo root

Options:
  --no-backup    Do not move api/generated out of the way before generation
EOF
}

want_backup="true"
for arg in "${@:-}"; do
  case "$arg" in
    --no-backup) want_backup="false" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
API_DIR="$ROOT_DIR/api"

if [[ ! -d "$API_DIR" ]]; then
  echo "Error: api directory not found at: $API_DIR" >&2
  exit 1
fi

command -v curl >/dev/null 2>&1 || { echo "Error: curl not found in PATH" >&2; exit 1; }
command -v openapi-generator >/dev/null 2>&1 || {
  echo "Error: openapi-generator not found in PATH" >&2
  echo "Hint: install it (e.g. 'brew install openapi-generator')" >&2
  exit 1
}
command -v flutter >/dev/null 2>&1 || { echo "Error: flutter not found in PATH" >&2; exit 1; }

OPENAPI_URL="https://newdawnsoi.site/v3/api-docs"
OPENAPI_OUT="$API_DIR/openapi.yaml"

echo "1/6 Downloading OpenAPI spec -> $OPENAPI_OUT"
curl --fail --location --retry 3 --retry-delay 1 -o "$OPENAPI_OUT" "$OPENAPI_URL"

GENERATED_DIR="$API_DIR/generated"
if [[ "$want_backup" == "true" && -d "$GENERATED_DIR" ]]; then
  backup_dir="$API_DIR/generated.backup"
  if [[ -e "$backup_dir" ]]; then
    ts="$(date +"%Y%m%d_%H%M%S")"
    backup_dir="$API_DIR/generated.backup.$ts"
  fi
  echo "2/6 Backing up generated -> $backup_dir"
  mv "$GENERATED_DIR" "$backup_dir"
else
  echo "2/6 Skipping backup"
fi

if [[ ! -f "$API_DIR/config.yaml" ]]; then
  echo "Error: api/config.yaml not found at: $API_DIR/config.yaml" >&2
  exit 1
fi

echo "3/6 Generating code via openapi-generator"
(
  cd "$API_DIR"
  openapi-generator generate -c config.yaml
)

if [[ ! -x "$API_DIR/patch_generated.sh" ]]; then
  echo "Error: api/patch_generated.sh not found or not executable: $API_DIR/patch_generated.sh" >&2
  echo "Fix: chmod +x api/patch_generated.sh" >&2
  exit 1
fi

echo "4/6 Running patch script (required)"
(
  cd "$API_DIR"
  ./patch_generated.sh
)

if [[ ! -d "$GENERATED_DIR" ]]; then
  echo "Error: expected generated output folder missing: $GENERATED_DIR" >&2
  exit 1
fi

echo "5/6 flutter pub get (api/generated)"
(
  cd "$GENERATED_DIR"
  flutter pub get
)

echo "6/6 flutter pub get (repo root)"
(
  cd "$ROOT_DIR"
  flutter pub get
)

echo "Done."
