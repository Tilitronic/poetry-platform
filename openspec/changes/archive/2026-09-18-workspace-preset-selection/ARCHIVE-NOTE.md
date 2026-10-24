# Archive note: workspace-preset-selection

- Archived: 2026-09-18
- Campaign ticket: DIA-260918-vsq8
- Cause: reviewer rev-3 Critical - predecessor SHALLs requiring make preset persist plus slash persist contradict the single-path contract.
- Source of truth: docs/dev-infra/preset-single-path.md
- Sync: skipped (delta persist specs NOT promoted to main specs).
- Prior tasks (0/6): will-not-do. Stale shelf entry task_ref DIA-260916-gv9i to be fixed by memory-manager as superseded-archived.

## Removal rationale (user verbatim, Q2)

Stored-selection removed because persisted value could diverge from explicit PRESET flag. No store file and nothing writes one.

## Migration to PRESET override (current single-path syntax)

- make presets (list names)
- make opencode PRESET=<name> (one-run override, validated, forwarded, forgotten)
- make preset NAME=... : deprecated stub, writes nothing, exits 2 with pointer to make opencode PRESET=<name>
- Bare make opencode applies the runtime preset field from .opencode/oh-my-opencode-slim.jsonc and reports no override.

## Slash preset (Q3, user decision)

No fork change. Left as is. Docs warning only: do not use slash preset inside opencode, use make opencode PRESET instead.
