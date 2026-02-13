# SOI AI Agent Playbook (Universal)

This document is a universal instruction set for the `SOI` project across any AI agent service.  
Agents must treat this file as the primary operating guide before starting work.

## User Context
- The user is a Flutter app developer for the `SOI` project.
- The user is experienced with Flutter/Dart, REST APIs, OpenAPI, state management, and asynchronous programming.
- The user has baseline familiarity with the SOI codebase, architecture, and major components.
- The user prioritizes performance, stability, and maintainability in code changes.

## Caution
- This guide is specific to the `SOI` project and may not apply directly to other projects.
- This document is a working guide for AI agents; final decisions must be reviewed by a human developer.
- The document can change over time, so always verify the latest version before working.
- Implement all features in a modular, testable way with minimal coupling.
- Follow OOP and SOLID principles to keep the codebase extensible and maintainable.

## 1. Project Snapshot
- Product: SOI, a social app for sharing images/text/videos
- Frontend: Flutter (Dart 3, `provider`, `easy_localization`, `flutter_screenutil`)
- Backend integration: REST API (`https://newdawnsoi.site`) + OpenAPI generated client
- OpenAPI generated client: `api/generated` (`soi_api_client`)
- Main app entry: `lib/main.dart`

## 2. Source Of Truth
- The current codebase is the final source of truth for structure and behavior.
- If documentation (`README`, older guides) conflicts with code, follow the code.
- Check the active branch first (`git branch --show-current`) and make branch-aware changes.

## 3. Architecture Rules
- Keep state management centered on `ChangeNotifier + Provider`.
- Follow this responsibility split:
- `models`: internal domain models and mapping
- `services`: API calls, DTO handling, exception mapping
- `controller`: UI state/flow control and service-call orchestration
- `views`: screen and widget rendering
- Prefer wrapper services in `lib/api/services/*` over direct use of generated DTO/API classes (`soi_api_client`).

## 4. Critical Do/Don't Guidelines
- Do: achieve goals with minimal, scoped changes.
- Do: preserve existing naming, patterns, and comment style.
- Do: keep async flows lifecycle-safe with `mounted` and lifecycle guards.
- Don't: manually edit `api/generated/**`.
- Don't: expose `.env`, keys/tokens, or personal data in logs/docs.
- Don't: perform broad refactors unless explicitly requested.

## 5. API Client Regeneration Policy
- Regenerate the client only when OpenAPI changes require it.
- Command: `./regen_api.sh`
- Ensure required patches from `api/patch_generated.sh` are applied during regeneration.
- After regeneration, verify `flutter pub get` is reflected in both root and generated package.
- Never hotfix generated code directly; resolve issues via patch scripts or wrapper/service layers.

## 6. Localization Policy
- When adding/changing user-facing text, update at least `ko`, `es`, and `en` translation keys together.
- Follow existing key namespaces (`common.*`, `camera.editor.*`, etc.).
- Prefer localization keys over hardcoded strings.

## 7. Media/Performance Guardrails
- SOI is media-heavy (image/video/audio), so prioritize protection against performance regressions.
- Restrict heavy logging to debug mode (`kDebugMode`).
- Explicitly handle media lifecycle cleanup (`paused`, `inactive`, `dispose`).
- Validate edge cases first for URL/file-key handling (null/empty/extension/timezone).

## 8. Change Workflow For Agents
Use the following sequence for every task.

1. Restate the goal and change scope in up to 3 lines.
2. Inspect only relevant files and identify impact scope.
3. Build a code-change plan.
4. Apply changes incrementally.
5. Run unit tests and manual verification when needed.
6. Report outcomes, including what/why/where changed and remaining risks.

## 9. Output Contract (Agent Response Format)
Final task responses must include:

- Change summary: one paragraph
- Modified file list: file paths
- Code diff summary: focused on major changes
- Validation results (optional): commands run and pass/fail
- Risks/unverified items: explicitly state none if none
- Next action suggestions (optional): only when needed

## 10. Task Prompt Template (Reusable)
If the user provides a free-form text request, convert it into the following JSON structure.

```json
{
  "task_goal": "Summarize the user's target outcome in 1-2 sentences",
  "current_behavior": "Observed current behavior or issue in the code",
  "desired_behavior": "Expected behavior or result",
  "constraints": [
    "Constraint 1",
    "Constraint 2"
  ],
  "references": [
    "Related docs or code links"
  ]
}
```

## 11. SOI-Specific High-Risk Areas
- `lib/main.dart`: provider registration, routing, deep links, app initialization order
- `lib/views/about_camera/photo_editor_screen.dart`: upload/compression/media-processing pipeline
- `lib/views/common_widget/api_photo/api_photo_display_widget.dart`: image/video rendering and comment overlays
- `lib/api/controller/post_controller.dart` + `lib/api/services/post_service.dart`: core post create/read/state-change flows
- `lib/api/models/post.dart`: media detection, date/timezone conversion, serialization rules
