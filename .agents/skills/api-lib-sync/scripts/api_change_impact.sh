#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  api_change_impact.sh <repo-root> [<base-ref> <head-ref>] [--include-untracked] [--wide-openapi] [--full-audit]

Options:
  --include-untracked  Include untracked generated files in local-diff mode.
  --wide-openapi       If only api/openapi.yaml changed, include broad wrapper directories.
  --full-audit         Ignore git diff and inventory every generated api/model for full wrapper audit.
  -h, --help           Show this help.

Notes:
  - By default, this script scans contract-relevant paths only:
      api/openapi.yaml
      api/generated/lib/api/**
      api/generated/lib/model/**
  - api/generated/doc/** is intentionally excluded for speed and signal quality.
  - --full-audit still excludes docs and backup files, and treats api/generated/lib/** as source of truth.
USAGE
}

repo_root="."
base_ref=""
head_ref="HEAD"
include_untracked=0
wide_openapi=0
full_audit=0

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
    --full-audit)
      full_audit=1
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

collect_full_contract_files() {
  {
    if [[ -f "$repo_root/api/openapi.yaml" ]]; then
      echo "api/openapi.yaml"
    fi
    if [[ -d "$repo_root/api/generated/lib/api" ]]; then
      find "$repo_root/api/generated/lib/api" -maxdepth 1 -type f -name '*.dart' \
        | sed "s#^$repo_root/##"
    fi
    if [[ -d "$repo_root/api/generated/lib/model" ]]; then
      find "$repo_root/api/generated/lib/model" -maxdepth 1 -type f -name '*.dart' \
        | sed "s#^$repo_root/##"
    fi
  } | sed '/\.backup$/d' | sort -u
}

collect_wrapper_inventory() {
  {
    if [[ -f "$repo_root/lib/api/api.dart" ]]; then
      echo "lib/api/api.dart"
    fi
    if [[ -f "$repo_root/lib/api/api_client.dart" ]]; then
      echo "lib/api/api_client.dart"
    fi
    if [[ -d "$repo_root/lib/api/models" ]]; then
      find "$repo_root/lib/api/models" -maxdepth 1 -type f -name '*.dart' \
        | sed "s#^$repo_root/##"
    fi
    if [[ -d "$repo_root/lib/api/services" ]]; then
      find "$repo_root/lib/api/services" -maxdepth 1 -type f -name '*.dart' \
        | sed "s#^$repo_root/##"
    fi
    if [[ -d "$repo_root/lib/api/controller" ]]; then
      find "$repo_root/lib/api/controller" -maxdepth 1 -type f -name '*.dart' \
        | sed "s#^$repo_root/##"
    fi
  } | sort -u
}

is_transport_helper_dto() {
  local stem="$1"
  case "$stem" in
    api_response_dto_*|pageable_object|sort_object|sort_option_dto)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_app_local_wrapper() {
  local path="$1"
  case "$path" in
    lib/api/controller/audio_controller.dart|\
    lib/api/controller/category_search_controller.dart|\
    lib/api/controller/comment_audio_controller.dart|\
    lib/api/controller/contact_controller.dart|\
    lib/api/models/comment_creation_result.dart|\
    lib/api/models/models.dart|\
    lib/api/models/selected_friend_model.dart|\
    lib/api/services/camera_service.dart|\
    lib/api/services/contact_repository.dart|\
    lib/api/services/contact_service.dart)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

contract_files="$(
  if [[ "$full_audit" -eq 1 ]]; then
    collect_full_contract_files
  else
    collect_changed_files | sed '/^$/d'
  fi
)"

if [[ -z "$contract_files" ]]; then
  if [[ "$full_audit" -eq 1 ]]; then
    echo "No generated contract files found for full audit."
  else
    echo "No contract-relevant changes detected."
    echo "(Scanned: api/openapi.yaml, api/generated/lib/api/**, api/generated/lib/model/**)"
    if [[ "$include_untracked" -eq 0 ]]; then
      echo "Tip: add --include-untracked if generated files are newly created."
    fi
  fi
  exit 0
fi

if [[ "$full_audit" -eq 1 ]]; then
  echo "== Full generated contract inventory =="
else
  echo "== Changed contract files =="
fi
echo "$contract_files"
echo

candidate_lines=""
transport_lines=""
manual_review_lines=""
openapi_changed=0
has_generated_contract_delta=0

add_candidate() {
  local path="$1"
  candidate_lines+="${path}"$'\n'
}

add_transport() {
  local path="$1"
  transport_lines+="${path}"$'\n'
}

add_manual_review() {
  local path="$1"
  manual_review_lines+="${path}"$'\n'
}

add_api_candidates() {
  local file="$1"
  local stem
  local domain
  local trimmed_domain

  stem="${file##*/}"
  stem="${stem%.dart}"

  add_candidate "lib/api/api_client.dart"
  add_candidate "lib/api/api.dart"

  case "$stem" in
    api_api)
      add_candidate "lib/api/services/media_service.dart"
      add_candidate "lib/api/controller/media_controller.dart"
      ;;
    category_api_api)
      add_candidate "lib/api/services/category_service.dart"
      add_candidate "lib/api/services/category_search_service.dart"
      add_candidate "lib/api/controller/category_controller.dart"
      ;;
    *_api_api)
      domain="${stem%_api_api}"
      add_candidate "lib/api/services/${domain}_service.dart"
      add_candidate "lib/api/controller/${domain}_controller.dart"
      if [[ "$domain" == *"_controller" ]]; then
        trimmed_domain="${domain%_controller}"
        if [[ -n "$trimmed_domain" ]]; then
          add_candidate "lib/api/services/${trimmed_domain}_service.dart"
          add_candidate "lib/api/controller/${trimmed_domain}_controller.dart"
        fi
      fi
      ;;
    *)
      add_manual_review "$file"
      ;;
  esac
}

add_model_candidates() {
  local file="$1"
  local stem
  local dto_stem
  local domain_guess
  local normalized_resp
  local normalized_req

  stem="${file##*/}"
  stem="${stem%.dart}"

  if is_transport_helper_dto "$stem"; then
    add_transport "$file"
    return
  fi

  if [[ "$stem" != *_dto ]]; then
    add_manual_review "$file"
    return
  fi

  dto_stem="${stem%_dto}"
  domain_guess="${dto_stem%%_*}"

  if [[ -n "$domain_guess" ]]; then
    add_candidate "lib/api/models/${domain_guess}.dart"
  fi

  if [[ "$dto_stem" == *_resp ]]; then
    normalized_resp="${dto_stem%_resp}"
    if [[ -n "$normalized_resp" && "$normalized_resp" != "$domain_guess" ]]; then
      add_candidate "lib/api/models/${normalized_resp}.dart"
    fi
  fi

  if [[ "$dto_stem" == *_req ]]; then
    normalized_req="${dto_stem%_req}"
    if [[ -n "$normalized_req" && "$normalized_req" != "$domain_guess" ]]; then
      add_candidate "lib/api/models/${normalized_req}.dart"
    fi
  fi
}

while IFS= read -r f; do
  [[ -z "$f" ]] && continue

  if [[ "$f" == "api/openapi.yaml" ]]; then
    openapi_changed=1
  fi

  if [[ "$f" =~ ^api/generated/lib/api/.+\.dart$ ]]; then
    has_generated_contract_delta=1
    add_api_candidates "$f"
  fi

  if [[ "$f" =~ ^api/generated/lib/model/.+\.dart$ ]]; then
    has_generated_contract_delta=1
    add_model_candidates "$f"
  fi
done <<< "$contract_files"

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
transport_sorted="$(printf "%s" "$transport_lines" | sed '/^$/d' | sort -u)"
manual_sorted="$(printf "%s" "$manual_review_lines" | sed '/^$/d' | sort -u)"

if [[ -z "$candidate_sorted" ]]; then
  echo "No wrapper candidates derived from current contract diff."
  if [[ -n "$transport_sorted" ]]; then
    echo
    echo "== Transport/helper generated models =="
    echo "$transport_sorted"
  fi
  if [[ -n "$manual_sorted" ]]; then
    echo
    echo "== Manual review generated files =="
    echo "$manual_sorted"
  fi
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

if [[ -n "$transport_sorted" ]]; then
  echo
  echo "== Transport/helper generated models =="
  echo "$transport_sorted"
fi

if [[ -n "$manual_sorted" ]]; then
  echo
  echo "== Manual review generated files =="
  echo "$manual_sorted"
fi

if [[ "$full_audit" -eq 1 ]]; then
  wrapper_inventory="$(collect_wrapper_inventory)"

  echo
  echo "== Wrapper inventory (full audit scope) =="
  echo "$wrapper_inventory"

  echo
  echo "== App-local wrappers excluded from drift alarms =="
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if is_app_local_wrapper "$p"; then
      echo "$p"
    fi
  done <<< "$wrapper_inventory"

  echo
  echo "== Wrapper paths without generated counterpart (manual review) =="
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if is_app_local_wrapper "$p"; then
      continue
    fi
    if ! grep -Fxq "$p" <<< "$candidate_sorted"; then
      echo "$p"
    fi
  done <<< "$wrapper_inventory"
fi
