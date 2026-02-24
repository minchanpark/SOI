# Mapping Rules

## 0. Scope Reduction Rules

Apply these before reading/editing wrappers:

- Ignore `api/generated/doc/**` by default. It does not change wrapper contracts.
- Focus on `api/generated/lib/api/*.dart`, `api/generated/lib/model/*_dto.dart`, and `api/openapi.yaml`.
- If only `api/openapi.yaml` changed (without generated deltas), request/regenerate `api/generated` first for precise mapping.
- Prefer exact field/method search (`rg "fieldName|methodName"`) over full-file scanning.

## 1. File Mapping Heuristics

Use these as starting points, then verify by reading actual code.

- `api/generated/lib/api/user_api_api.dart` ->
  - `lib/api/services/user_service.dart`
  - `lib/api/controller/user_controller.dart`
- `api/generated/lib/api/comment_api_api.dart` ->
  - `lib/api/services/comment_service.dart`
  - `lib/api/controller/comment_controller.dart`
- `api/generated/lib/model/comment_resp_dto.dart` ->
  - `lib/api/models/comment.dart`
- `api/generated/lib/model/<domain>_*_dto.dart` ->
  - `lib/api/models/<domain>.dart` (or nearest domain model)
  - `lib/api/services/<domain>_service.dart`
  - `lib/api/controller/<domain>_controller.dart`

## 2. Contract-Sync Checklist

### Request Side

- Required query/body params unchanged?
- Parameter naming/casing unchanged? (`nickName` vs `nickname`)
- HTTP method/path unchanged?

### Response Side

- `success/data/message` envelope shape unchanged?
- `data` nullability changed?
- Nested DTO field nullability/type changed?

### Error Side

- Distinguish transport failures from server 4xx/5xx.
- Preserve domain semantics (`404 => null`) only where product logic explicitly requires it.

## 3. Controller Semantics

- Only return `null` for business-meaningful absence (e.g., not found/new user).
- Re-throw service exceptions when UI must differentiate failure reasons.
- Keep UI branch conditions aligned with controller contract.

## 4. Verification Matrix

For each changed endpoint:

1. Happy path returns mapped domain model
2. Business absence path behaves as expected (`null` or explicit state)
3. Transport error is not misclassified as business absence
4. Non-transport 400/401/403/500 handling remains coherent

## 5. Performance Checklist

1. Run impact script once and use the candidate list as hard scope.
2. Do not run repository-wide analyze/test if only a few wrappers changed.
3. Prefer file-scoped commands: `dart analyze <files>`, `flutter test <targets>`.
