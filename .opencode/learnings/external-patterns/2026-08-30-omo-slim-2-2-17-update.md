---
# oh-my-opencode-slim 2.2.17 bump (DIA-260830-i9d)

## Finding (from @ai-specialist gate ai--2, researcher res-1)
- Current pin: "oh-my-opencode-slim@2.2.15" at .opencode/opencode.jsonc:712 (plugin[]).
  Also comment at :135. Single source of truth.
- Literal "2.217" does not exist; intended target is 2.2.17 (latest 2026-08-25).
- 2.2.17 = 73 commits ahead of 2.2.15, patch-level bug-fix/feature only, NO breaking
  schema changes.
- Relevant fixes for this repo's delegation-heavy orchestrator: task_message child
  preservation (#1055/#1085), task-result status (#1049), orchestrator wake suppression
  (#1082), wait_for_user guard (#1077), tool-loop-guard (#1074), BOM strip (#1035),
  preserve model variant (#1022).
- Preset/agent impact: none. 4 custom presets + promo unaffected.

## Gate recommendation: PROCEED (low risk)
- Validation after bump: make test-config, make test-shell, restart OpenCode, smoke test delegation.
- Also update comment at :135 to 2.2.17.
- Global config (~/.config/opencode) also pins 2.2.15 — divergence flagged, out of scope.
---
