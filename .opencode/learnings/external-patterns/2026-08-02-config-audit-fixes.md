# Config audit: gate findings (2026-08-02)

Source: orchestrator (audit) + ai-specialist (gate review) + coder (fixes)

Summary
-------
This document records gate findings that are NOT recoverable from the git diffs of the config fixes and therefore must be persisted as external-patterns.

Irrecoverable findings
----------------------
- OMO deepMerge REPLACES arrays: a project-level `disabled_agents: []` will silently override the global array `["oracle","fixer","explorer","librarian"]` (observed in deployed dist behaviour; implementation references: dist:19010-2014; top-level keys use spread dist:18986-18999). Symptom: native agents became dispatchable again even though AGENTS.md §9 said they were disabled. Remedy: prefer pruning/aligning at the same layer or explicitly include the global set when overriding arrays.

- Agent `model` strings in opencode.jsonc override the OMO preset model array and disable the fallback resolution chain. Observed dist snippet: dist:40228-40241 (`{...pluginAgent, ...existing}`) — placing model IDs inside agent objects short-circuits preset arrays. Recommendation: place preferred models in the oh-my-opencode-slim preset, not as literal `model` keys in opencode.jsonc agent objects.

- Runtime model resolution logs are authoritative for what model an agent actually uses; they are emitted to ~/.local/share/opencode/log/oh-my-opencode-slim.*.log with messages like "[plugin] resolved model from array". When auditing model usage, check these logs (not only config files).

- The `opencode models` CLI is the pragmatic authority for model validity. The `models.dev` cache contains many IDs that are not practically available; rely on the CLI to validate usable model IDs in the local environment.

- Residual/out-of-scope flags observed during audit (flagged, not fixed):
  - `opencode/deepseek-v4-flash` (no -go prefix) is absent from `opencode models` (only `-free` variants present).
  - `opencode-go/kimi-k2.6` still referenced in the global opencode-go observer preset.

Context & verification
----------------------
All behaviour above was verified against the deployed plugin artifact (npm oh-my-opencode-slim@2.2.8 at ~/.cache/opencode/packages/oh-my-opencode-slim@2.2.8/dist/index.js). The deployed dist is the ground-truth for runtime behaviour; vendored fork sources in the repo may differ and must not be used as the authoritative reference when auditing runtime semantics.

Why this is recorded
---------------------
The listed items are operational behaviours and audit heuristics that cannot be reconstructed purely from the git diffs of the fixes. They materially affected how the audit was performed and how fixes were applied; storing them here prevents regressions and guides future audits.
