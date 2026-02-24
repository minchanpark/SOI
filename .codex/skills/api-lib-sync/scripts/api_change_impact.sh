#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  api_change_impact.sh <repo-root> [<base-ref> <head-ref>] [--include-untracked] [--wide-openapi]

Options:
  --include-untracked  Include untracked generated files in local-diff mode.
  --wide-openapi       If only api/openapi.yaml changed, include broad wrapper directories.
  -h, --help           Show this help.

Notes:
  - By default, this script scans contract-relevant paths only:
      api/openapi.yaml
      api/generated/lib/api/**
      api/generated/lib/model/**
  - api/generated/doc/** is intentionally excluded for speed and signal quality.
USAGE
}

repo_root="."
base_ref=""
head_ref="HEAD"
include_untracked=0
wide_openapi=0

positionals=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-untracked)
      include_untracked=1
      shift
      ;;
    --wide-openapi)
      wide_openapi=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        positionals+=("$1")
        shift
      done
      ;;
    -*)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [[ "${#positionals[@]}" -gt 3 ]]; then
  echo "[ERROR] Too many positional arguments." >&2
  usage >&2
  exit 1
fi

if [[ "${#positionals[@]}" -ge 1 ]]; then
  repo_root="${positionals[0]}"
fi
if [[ "${#positionals[@]}" -ge 2 ]]; then
  base_ref="${positionals[1]}"
fi
if [[ "${#positionals[@]}" -ge 3 ]]; then
  head_ref="${positionals[2]}"
fi

if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] Not a git repository: $repo_root" >&2
  exit 1
fi

relevant_paths=(
  "api/openapi.yaml"
  "api/generated/lib/api"
  "api/generated/lib/model"
)

collect_changed_files() {
  if [[ -n "$base_ref" ]]; then
    git -C "$repo_root" diff --name-only "$base_ref" "$head_ref" -- "${relevant_paths[@]}"
  else
    {
      git -C "$repo_root" diff --name-only -- "${relevant_paths[@]}"
      git -C "$repo_root" diff --name-only --cached -- "${relevant_paths[@]}"
      if [[ "$include_untracked" -eq 1 ]]; then
        git -C "$repo_root" ls-files --others --exclude-standard -- "${relevant_paths[@]}"
      fi
    } | sort -u
  fi
}

changed_files="$(collect_changed_files | sed '/^$/d' || true)"

if [[ -z "$changed_files" ]]; then
  echo "No contract-relevant changes detected."
  echo "(Scanned: api/openapi.yaml, api/generated/lib/api/**, api/generated/lib/model/**)"
  if [[ "$include_untracked" -eq 0 ]]; then
    echo "Tip: add --include-untracked if generated files are newly created."
  fi
  exit 0
fi

echo "== Changed contract files =="
echo "$changed_files"
echo

candidate_lines=""
openapi_changed=0
has_generated_contract_delta=0

add_candidate() {
  local path="$1"
  candidate_lines+="${path}"$'\n'
}

while IFS= read -r f; do
  [[ -z "$f" ]] && continue

  if [[ "$f" == "api/openapi.yaml" ]]; then
    openapi_changed=1
  fi

  if [[ "$f" =~ ^api/generated/lib/api/(.+)_api\.dart$ ]]; then
    has_generated_contract_delta=1
    api_stem="${BASH_REMATCH[1]}"
    domain="${api_stem%_api}"
    add_candidate "lib/api/services/${domain}_service.dart"
    add_candidate "lib/api/controller/${domain}_controller.dart"
  fi

  if [[ "$f" =~ ^api/generated/lib/model/(.+)_dto\.dart$ ]]; then
    has_generated_contract_delta=1
    dto_stem="${BASH_REMATCH[1]}"
    add_candidate "lib/api/models/${dto_stem}.dart"

    # DTO stem prefix usually maps to wrapper domain (e.g. post_resp -> post).
    domain_guess="${dto_stem%%_*}"
    if [[ -n "$domain_guess" ]]; then
      add_candidate "lib/api/services/${domain_guess}_service.dart"
      add_candidate "lib/api/controller/${domain_guess}_controller.dart"
    fi

    base="${dto_stem%_resp}"
    base="${base%_req}"
    add_candidate "lib/api/models/${base}.dart"
  fi
done <<< "$changed_files"

if [[ "$openapi_changed" -eq 1 && "$has_generated_contract_delta" -eq 0 ]]; then
  echo "== Notice =="
  echo "api/openapi.yaml changed, but no generated api/model contract files changed."
  echo "Regenerate api/generated before wrapper sync for precise impact."
  echo
  if [[ "$wide_openapi" -eq 1 ]]; then
    add_candidate "lib/api/services"
    add_candidate "lib/api/controller"
    add_candidate "lib/api/models"
  fi
fi

candidate_sorted="$(printf "%s" "$candidate_lines" | sed '/^$/d' | sort -u)"

if [[ -z "$candidate_sorted" ]]; then
  echo "No wrapper candidates derived from current contract diff."
  exit 0
fi

echo "== Candidate wrapper paths (review + trim) =="
echo "$candidate_sorted"
echo

echo "== Existing candidate paths =="
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  if [[ -e "$repo_root/$p" ]]; then
    echo "$p"
  fi
done <<< "$candidate_sorted"
echo

echo "== Missing candidate paths (optional/derived) =="
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  if [[ ! -e "$repo_root/$p" ]]; then
    echo "$p"
  fi
done <<< "$candidate_sorted"
