---
name: soi-playbook-autoload
description: Load docs/AI_AGENT_PLAYBOOK.en.md and activate SOI project constraints for this session. Use at the start of any SOI task.
disable-model-invocation: true
allowed-tools: Read, Bash
---

# SOI Playbook Autoload

## Playbook

!`cat docs/AI_AGENT_PLAYBOOK.en.md`

---

위 플레이북의 모든 규칙을 이 세션에서 적용한다.

적용 후 아래 내용을 사용자에게 보고한다:
- 현재 브랜치: `!`git branch --show-current``
- 플레이북 로드 완료 및 활성화된 주요 제약 목록 (Architecture, API, State, Localization, Async, Scope)

이후 다음 작업을 진행한다: $ARGUMENTS
