# Mapping Rules

## 0. Source of Truth

- `api/generated/lib/api/**` and `api/generated/lib/model/**` win over stale wrapper code in `lib/api/**`.
- Treat `api/openapi.yaml` as a regeneration trigger; prefer generated Dart files for actual wrapper edits.
- Never edit `api/generated/**` during wrapper sync unless the user explicitly requests regeneration or generated patching.

## 1. Sync Scope Rules

Apply these before reading/editing wrappers:

- Ignore `api/generated/doc/**` by default. It does not change wrapper contracts.
- Fast path scope: changed generated files only.
- Full baseline audit scope: every generated file under `api/generated/lib/api/*.dart` and `api/generated/lib/model/*.dart`, plus wrapper surfaces under:
  - `lib/api/api.dart`
  - `lib/api/api_client.dart`
  - `lib/api/models/*.dart`
  - `lib/api/services/*.dart`
  - `lib/api/controller/*.dart`
- If only `api/openapi.yaml` changed without generated deltas, regenerate `api/generated` first for precise wrapper sync.
- Prefer exact symbol search (via `Grep` with specific patterns) over broad full-file scanning.
- In full audit, do not trim the scope until every generated file is classified.

## 2. Classification Before Editing

Every generated file must be classified into one of these buckets before editing:

1. Wrapper exists and is aligned
2. Wrapper exists but is stale
3. Wrapper is missing and must be created/extended
4. Transport/helper DTO handled only inside services
5. Intentional app-local skip or manual follow-up

Do not force false 1:1 symmetry. Some generated DTOs should never become `lib/api/models/*.dart` files.

## 3. API-to-Wrapper Mapping Heuristics

Use these as starting points, then verify by reading actual code.

- `api/generated/lib/api/api_api.dart` ->
  - `lib/api/services/media_service.dart`
  - `lib/api/controller/media_controller.dart`
  - `lib/api/api_client.dart`
  - `lib/api/api.dart`
- `api/generated/lib/api/user_api_api.dart` ->
  - `lib/api/services/user_service.dart`
  - `lib/api/controller/user_controller.dart`
  - `lib/api/api_client.dart`
  - `lib/api/api.dart`
- `api/generated/lib/api/category_api_api.dart` ->
  - `lib/api/services/category_service.dart`
  - `lib/api/controller/category_controller.dart`
  - `lib/api/services/category_search_service.dart`
  - `lib/api/controller/category_search_controller.dart`
  - `lib/api/api_client.dart`
  - `lib/api/api.dart`
- `api/generated/lib/api/comment_api_api.dart` ->
  - `lib/api/services/comment_service.dart`
  - `lib/api/controller/comment_controller.dart`
  - `lib/api/api_client.dart`
  - `lib/api/api.dart`
- `api/generated/lib/api/<domain>_api_api.dart` ->
  - `lib/api/services/<domain>_service.dart`
  - `lib/api/controller/<domain>_controller.dart`
  - `lib/api/api_client.dart`
  - `lib/api/api.dart`
- `api/generated/lib/api/<domain>_controller_api.dart` ->
  - first try `lib/api/services/<domain>_service.dart`
  - first try `lib/api/controller/<domain>_controller.dart`
  - if not found, manually inspect whether the wrapper should use the stem before `_controller`

## 4. Generated Model Classification

### Domain DTOs

Usually require review of:

- matching domain model in `lib/api/models/*.dart`
- request/response handling in services already mapped from generated API files
- controller behavior when service return shape changes

Typical examples:

- `category_resp_dto.dart` -> `lib/api/models/category.dart`
- `comment_resp_dto.dart` -> `lib/api/models/comment.dart`
- `friend_resp_dto.dart` -> `lib/api/models/friend.dart`
- `friend_check_resp_dto.dart` -> `lib/api/models/friend_check.dart`
- `notification_resp_dto.dart` and `notification_get_all_resp_dto.dart` -> `lib/api/models/notification.dart`
- `post_resp_dto.dart` -> `lib/api/models/post.dart`
- `user_resp_dto.dart` -> `lib/api/models/user.dart`

### Request DTOs

Usually do not need dedicated wrapper model files, but must still be checked in services:

- request object construction
- parameter naming/casing
- nullability
- enum/string values

### Transport / Helper DTOs

Usually stay inside service-layer unwrapping and should not force new domain model files:

- `api_response_dto_*`
- `pageable_object.dart`
- `sort_object.dart`
- `sort_option_dto.dart`
- slice/page helper DTOs unless the app deliberately wraps them as domain aggregates

### Non-1:1 Wrapper Cases

These require explicit notes instead of assuming simple file-name symmetry:

- aggregate wrapper models
- DTOs that split request and response shapes for the same domain
- generated DTOs whose closest wrapper is in services only

## 5. App-Local Wrappers To Exclude From Drift Alarms

These are usually product-local helpers, not direct generated-contract mirrors:

- `lib/api/controller/audio_controller.dart`
- `lib/api/controller/category_search_controller.dart`
- `lib/api/controller/comment_audio_controller.dart`
- `lib/api/controller/contact_controller.dart`
- `lib/api/models/comment_creation_result.dart`
- `lib/api/models/selected_friend_model.dart`
- `lib/api/models/models.dart`
- `lib/api/services/camera_service.dart`
- `lib/api/services/contact_repository.dart`
- `lib/api/services/contact_service.dart`

Only classify them as drift if a generated-contract change directly forces a change in how generated-backed wrappers interact with them.

## 6. Contract-Sync Checklist

### Request Side

- Required query/body params unchanged?
- Parameter naming/casing unchanged? (`nickName` vs `nickname`)
- HTTP method/path unchanged?
- Request DTO constructor fields and defaults unchanged?

### Response Side

- `success/data/message` envelope shape unchanged?
- `data` nullability changed?
- Nested DTO field nullability/type changed?
- Slice/list/aggregate wrappers still unwrap the latest generated shape?

### Error Side

- Distinguish transport failures from server 4xx/5xx.
- Preserve domain semantics (`404 => null`) only where product logic explicitly requires it.

### Public Wrapper Surface

- `lib/api/api_client.dart` still exposes the required generated API getters?
- `lib/api/api.dart` exports still match the wrapper/generated DTO surface the app expects?

## 7. Controller Semantics

- Only return `null` for business-meaningful absence (e.g., not found/new user).
- Re-throw service exceptions when UI must differentiate failure reasons.
- Keep UI branch conditions aligned with controller contract.
- Do not silently absorb generated-contract changes by converting hard failures into empty state.

## 8. Verification Matrix

For each changed endpoint:

1. Happy path returns mapped domain model
2. Business absence path behaves as expected (`null` or explicit state)
3. Transport error is not misclassified as business absence
4. Non-transport 400/401/403/500 handling remains coherent

For full baseline audit:

1. Every generated API file is mapped to a service/controller/public-surface decision
2. Every generated model file is classified as domain, request-only, transport/helper, or manual follow-up
3. Missing wrappers vs intentional skips are explicitly listed
4. `lib/api/api.dart` and `lib/api/api_client.dart` are checked when generated API inventory changes

## 9. Performance Checklist

1. Run impact script once and use the candidate list as hard scope.
2. In full audit, use the inventory output as the classification checklist before reading code deeply.
3. Do not run repository-wide analyze/test if only a few wrappers changed.
4. Prefer file-scoped commands: `dart analyze <files>`, `flutter test <targets>`.
