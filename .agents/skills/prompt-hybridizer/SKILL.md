---
name: prompt-hybridizer
description: Structure a natural-language request into a compact English JSON-hybrid execution contract. Use only when the user explicitly asks to rewrite a prompt, prepare a cleaner prompt for another agent, or wants more consistent execution without forcing a full JSON-only prompt.
---

# Prompt Hybridizer

## Overview

Turn a loose natural-language request into a small execution contract that keeps the original intent readable while pinning down the details that models often miss.
Use this skill as an opt-in structuring step, not as a default rule for every task.

## When To Use

Use this skill when the user explicitly wants one of these outcomes:
- Clean up a vague or messy prompt before execution
- Convert a natural-language request into a JSON-hybrid prompt
- Prepare a compact handoff prompt for another agent
- Standardize repeated coding, analysis, or command requests without going full JSON-first

Do not use this skill when:
- The request is already clear and short
- Free-form brainstorming matters more than structure
- The extra contract would add more overhead than clarity

## Workflow

1. Extract only the facts that materially affect execution:
   - goal
   - task type
   - scope
   - constraints
   - validation
   - assumptions or risks
2. Build a compact JSON contract with only the fields that help.
3. Rewrite the visible prompt in English unless the user explicitly asks for another language.
4. Wrap that contract in a short natural-language instruction block so the final prompt stays readable, and present it directly to the user.
5. Execute locally from the hybrid prompt if the user requests immediate action. Use the `Agent` tool for delegation if a subtask is better handled by a specialized subagent.

## Contract Shape

Use this minimal shape and omit empty sections when they add no value:

```json
{
  "goal": "single sentence target",
  "task_type": "code_change|analysis|docs|command|other",
  "scope": {
    "include": [],
    "exclude": []
  },
  "constraints": {
    "must": [],
    "must_not": []
  },
  "validation": [],
  "assumptions": [],
  "risks": []
}
```

Rules:
- Keep the contract short and concrete.
- Keep all human-readable values in English by default.
- Do not restate the entire user prompt inside JSON.
- Do not invent precise file lists, commands, or constraints when they are unknown.
- Prefer omission over filler.
- Show the JSON to the user only when they ask for the rewritten prompt or when seeing the contract is useful.

## Language Policy

- Default output language for the rewritten hybrid prompt is English.
- This includes `Request summary`, `Execution notes`, and any natural-language string values inside the JSON contract.
- Keep JSON keys in the same schema regardless of language.
- If the user explicitly asks for Korean or another language, follow that request instead.
- If the source prompt is multilingual, preserve technical identifiers and file paths exactly as written.

## Hybrid Prompt Template

Use this shape for execution or handoff:

```text
Request summary:
<1-3 short English sentences preserving the user's intent and tone>

Execution contract:
{JSON block here}

Execution notes:
- Respect the contract, but prefer current code and explicit user instructions when they conflict.
- Keep changes minimal unless the prompt says otherwise.
- Report outcomes, validation, and remaining risks.
```

## Execution Rule

If a follow-up action is required, prefer executing the hybrid prompt directly within the current context. If handoff to a subagent is needed, use the `Agent` tool to delegate with the hybrid prompt as the agent's prompt.

## Token Discipline

- Default to internal structuring first; do not always print the contract.
- Avoid long prose plus full JSON plus a duplicated checklist in the same response.
- Keep the visible rewritten prompt short enough that it can actually be reused.
- For simple requests, a 4-5 line hybrid prompt is better than a verbose schema.

## Example

User request:

```text
photo editor category sheet가 왜 느린지 보고, 최소 수정으로 개선해줘. UI 바꾸지 말고 검증도 해줘.
```

Hybrid prompt:

```text
Request summary:
Inspect why `photo_editor_category_sheet` feels slow and improve it with minimal behavior change.
Keep the current UI and run relevant validation if possible.

Execution contract:
{
  "goal": "Reduce slowness in photo_editor_category_sheet with minimal behavioral change",
  "task_type": "code_change",
  "scope": {
    "include": [
      "lib/views/about_camera/widgets/about_photo_editor_screen/photo_editor_category_sheet.dart"
    ]
  },
  "constraints": {
    "must": [
      "preserve current UI behavior",
      "keep changes minimal"
    ]
  },
  "validation": [
    "dart analyze lib/views/about_camera"
  ]
}

Execution notes:
- Investigate before editing.
- Prefer the smallest fix that addresses the hot path.
- Report root cause, change summary, and residual risk.
```
