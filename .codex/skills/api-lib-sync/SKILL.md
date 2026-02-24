---
name: api-lib-sync
description: Synchronize `lib/api` with changes under the project-root `api/` directory (especially `api/openapi.yaml` and `api/generated`). Use when a user asks to reflect backend/OpenAPI changes into wrapper-layer Dart code, such as models, services, controllers, error mapping, and login/comment/category/friend API flows.
---

# API Lib Sync

## Overview

Use this skill to safely propagate API spec/client changes from `api/` into `lib/api`.
Focus on wrapper-layer consistency: request/response mapping, exception handling, and controller behavior.
Prioritize fast execution: narrow scope first, then edit only impacted wrappers.

## Workflow (Fast Path)

1. Detect API-side changes and impacted wrapper files with the bundled script.
2. Read only impacted generated files (`api/generated/lib/api/*`, `api/generated/lib/model/*`, and optionally `api/openapi.yaml`).
3. Update `lib/api/models`, `lib/api/services`, `lib/api/controller` to match changed contracts.
4. Verify by running targeted tests/analyze and summarize behavioral changes.

## Step 1: Detect Impact

Run the bundled script first.

```bash
scripts/api_change_impact.sh <repo-root>
```

If you need branch-to-branch diff:

```bash
scripts/api_change_impact.sh <repo-root> <base-ref> <head-ref>
```

Optional flags:

```bash
scripts/api_change_impact.sh <repo-root> --include-untracked
scripts/api_change_impact.sh <repo-root> --wide-openapi
```

- Default mode excludes `api/generated/doc/**` and focuses on contract files only.
- Default mode does not auto-expand `openapi.yaml` change to whole `lib/api/**`.
- Use `--wide-openapi` only when generated files are not available yet and broad review is explicitly needed.

Use the generated candidate list as the edit scope baseline. If scope is still broad, trim to files touched by changed endpoints/DTOs.

## Step 2: Read Contract Deltas

For each changed generated file, compare old/new behavior before editing wrappers:

- Endpoint changes: method, path, query/body shape, required params, nullable fields
- DTO changes: renamed fields, nullability, enum values, nested shape
- Error semantics: status code behavior and transport-vs-server failure cases

Prefer targeted reads (`rg`, line ranges) over full-file reads.
Do not read full `api/openapi.yaml` when it is minified unless absolutely required.

## Step 3: Apply Wrapper Sync

### Models (`lib/api/models/*.dart`)

- Keep `fromDto` / `toDto` mapping aligned to generated DTO field names.
- Reflect nullability exactly; do not force unwrap if contract became nullable.
- If enum/source strings changed, update parsing and fallback handling.

### Services (`lib/api/services/*_service.dart`)

- Match generated API method signatures and parameter names.
- Keep response unwrapping (`success`, `message`, `data`) consistent with DTO schema.
- Preserve or improve exception mapping (`ApiException` -> domain exceptions).
- Do not edit `api/generated`; adapt wrapper layer unless user explicitly asks regeneration.

### Controllers (`lib/api/controller/*_controller.dart`)

- Align control flow with service semantics (e.g., `null` vs throw behavior).
- Prevent false business branching caused by transport errors.
- Keep state transitions (`_setLoading`, `_setError`, `notifyListeners`) deterministic.

## Step 4: Verify

Run targeted checks for touched files only. Avoid full-project verification unless requested:

```bash
dart format <changed-files>
dart analyze <changed-files>
flutter test <relevant-tests>
```

If no tests exist, add minimal regression tests for:

- response mapping correctness
- error classification boundaries (404 business case vs network failure)
- controller branching behavior

## Output Requirements

When finishing a sync task, report:

- Updated files and why each changed
- Any intentional behavioral contract changes
- Validation commands run and outcomes
- Risks or follow-up items (e.g., backend ambiguity, missing tests)

## Efficiency Guardrails

- Start with `scripts/api_change_impact.sh`; do not begin with wide `rg` over `lib/api/**`.
- Skip non-contract generated changes (`api/generated/doc/**`) unless user asks for docs sync.
- If only `api/openapi.yaml` changed and generated client deltas are absent, report that regeneration is required before precise wrapper sync.
- Keep command count minimal: one impact detection run, then targeted reads/edits.

## References

- Mapping rules and checklist: `references/mapping-rules.md`
- Impact detector script: `scripts/api_change_impact.sh`
