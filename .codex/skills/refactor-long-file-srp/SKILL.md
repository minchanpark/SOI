---
name: refactor-long-file-srp
description: Refactor oversized source files into single-responsibility classes/modules with shallow dependency chains while preserving behavior. Use when a user asks to split long files, remove god objects, reduce coupling, enforce OOP boundaries, or improve maintainability without changing product behavior.
---

# Refactor Long File SRP

## Overview

Refactor long files into cohesive units with explicit responsibilities.  
Preserve runtime behavior and keep dependency depth intentionally shallow.

## Refactoring Workflow

1. Establish baseline behavior before editing.
   - Read the target file and immediate collaborators.
   - Run available tests/analyze/lint for the touched area.
   - Record public API surfaces that must remain compatible.

2. Map responsibilities in the long file.
   - Group code by concern (state, orchestration, data access, presentation, formatting, validation, side effects).
   - Mark mixed-responsibility symbols as extraction candidates.
   - Identify hidden dependencies (globals, context objects, singletons, cross-layer imports).

3. Define extraction boundaries.
   - Assign one reason to change per new class/module.
   - Keep extracted units cohesive and small.
   - Prefer explicit constructor dependencies over implicit lookups.
   - Keep dependency depth shallow:
     - Target: 0-2 hops from entrypoint to leaf logic.
     - Avoid daisy chains where A -> B -> C -> D for common flows.

4. Apply incremental refactor steps.
   - Extract pure functions first.
   - Extract helper classes/services next.
   - Move interfaces/contracts before implementations when boundaries are unclear.
   - Keep each step behavior-preserving and compile-safe.
   - Avoid large rename/move waves without immediate verification.

5. Control coupling and ownership.
   - Use composition over inheritance unless polymorphism is required.
   - Depend on abstractions when crossing domain boundaries.
   - Prevent circular imports/dependencies.
   - Keep orchestration at higher layers; keep side effects at boundaries.

6. Verify and finalize.
   - Run static analysis and relevant tests.
   - Confirm public API compatibility (or document intentional changes).
   - Summarize extracted units, their responsibilities, and dependency changes.

## Design Rules

- Preserve behavior by default; treat structural refactor as non-functional change.
- Limit each new type to one core responsibility.
- Keep method responsibilities narrow; split methods that do setup + orchestration + IO + formatting together.
- Avoid passing full context objects when a narrow interface/value is enough.
- Keep naming aligned to role (`*Service`, `*Repository`, `*Mapper`, `*Formatter`, `*Controller`, `*Widget`).

## Practical Thresholds

Use these as triggers, not hard constraints:

- File length > 350-500 LOC
- Class length > 200-300 LOC
- Method length > 40-60 LOC
- Method branching depth > 3
- Constructor dependencies > 5
- Same file mixes 3+ concerns

## Acceptance Checklist

- New modules/classes each have a clear single responsibility.
- Dependency chain depth is reduced and remains easy to trace.
- No circular dependency introduced.
- Existing behavior is preserved in tests/manual scenarios.
- Static analysis passes on changed files.
- Final report includes:
  - Why the file was split
  - What was extracted
  - Before/after dependency shape
  - Residual risks and follow-up refactors
