# SOI Project — Claude Code Instructions

## MANDATORY: Read Playbook Before Any Task

**At the start of every session and before executing any task, read the full contents of:**

@docs/AI_AGENT_PLAYBOOK.en.md

This file is the primary operating guide for this project. All architectural rules, API boundaries, localization policy, and workflow constraints are defined there.

Do not skip this step. If the file is missing, report it immediately and halt.

## Quick Reference (from Playbook)

- Architecture: `models` → `services` → `controller` → `views`
- API client: Never edit `api/generated/**`. Use `lib/api/services/*` wrappers.
- State: `ChangeNotifier + Provider` only.
- Localization: Always update `ko`, `es`, `en` keys together.
- Async: Guard with `mounted` checks.
- Scope: Minimal changes. No unsolicited refactors.
