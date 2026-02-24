---
name: soi-playbook-autoload
description: Automatically load and apply `docs/AI_AGENT_PLAYBOOK.md` for SOI repository work. Use for any SOI request (planning, implementation, review, debugging) so the playbook is read before task execution, cached per session, and reloaded only when the file fingerprint changes.
---

# SOI Playbook Autoload

## Overview

Load `docs/AI_AGENT_PLAYBOOK.md` before handling SOI tasks.
Keep a session-level fingerprint cache and re-read only when content changes.

## Workflow

1. Validate playbook path first.

```bash
test -f docs/AI_AGENT_PLAYBOOK.md
```

- If the file is missing, stop and report:
  - Missing required file: `docs/AI_AGENT_PLAYBOOK.md`
  - Request user confirmation of the correct path or restoration.
- Do not continue task execution without resolving this file.

2. Compute fingerprint for change detection.

```bash
shasum docs/AI_AGENT_PLAYBOOK.md
```

3. Apply session load policy.

- If there is no cached fingerprint for this session:
  - Read the full file once.
  - Cache fingerprint and short checklist summary.
- If cached fingerprint matches current fingerprint:
  - Skip full re-read.
  - Reuse cached checklist.
- If cached fingerprint differs:
  - Re-read the full file.
  - Refresh fingerprint and checklist.

4. Build and keep a short execution checklist from the playbook.

- Branch/source-of-truth checks (`git branch`, `git status`, contract precedence)
- API sync rules (`api/openapi.yaml`, `api/generated`, `lib/api` boundaries)
- Provider ownership/dispose rules for global controllers
- Caching/performance guardrails and error classification rules

5. Execute the user request under the checklist constraints.

- Prefer code-as-truth when documentation and code conflict.
- Surface constraints early when a requested change would violate the playbook.
- Re-check fingerprint before critical steps when the session has been long-running.
