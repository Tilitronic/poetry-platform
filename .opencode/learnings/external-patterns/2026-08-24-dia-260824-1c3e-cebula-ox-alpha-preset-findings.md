# DIA-260824-1c3e: cebula ox-alpha opencode preset - ai-specialist findings (2026-08-24)

- **Date:** 2026-08-24
- **Source:** ai-specialist read-only research (DIA-260824-1c3e gate step, AGENTS.md section 2.5 step 1). Validated against `.opencode/oh-my-opencode-slim.jsonc` (cebula-openai-hy3 block lines 414-637; council block lines 858-884).
- **Status:** REGISTERED - findings only. The original findings registration made no implementation edits (`.opencode/oh-my-opencode-slim.jsonc`, the DIA ticket, and `.opencode/CHANGELOG.yaml`/`.md` were UNTOUCHED at registration). The 2026-08-24 documentation-correction dispatch amended CHANGELOG.yaml/md + this outcome to the verified `opencode-go/ox-alpha-free`.
- **Outcome note:** COMPLETED - the ox-alpha provider prefix is resolved to the verified ID `opencode-go/ox-alpha-free` (live OpenCode Go catalog + official docs, 2026-08-24); the eight-reference documentation correction (CHANGELOG.yaml/md + this outcome) is registered and validated. The config file edit remains a separate coder-lane task.
- **Correction addendum (2026-08-24):** a follow-up ai-specialist diagnostic (see 'Finding - correction') supersedes the ox-alpha model-ID claim in the prior Outcome. The prior validation/audit history is retained verbatim under 'Prior outcome (SUPERSEDED)'. Config, changelog, ticket, and registry files are NOT edited by this correction.

## Ticket

- **DIA-260824-1c3e** (OPEN) - "add cebula ox alpha opencode preset". This entry is the mandatory ai-specialist findings registration that must precede any @coder config-work dispatch.

## Finding

- **Source preset:** `cebula-openai-hy3` (oh-my-opencode-slim.jsonc line 414) is the clone source for the new ox-alpha preset. Its full block spans lines 414-637.
- **Target location:** the new preset pointer AND the cloned block both belong in `.opencode/oh-my-opencode-slim.jsonc` (sibling to cebula-openai-hy3). No other file is involved.
- **Qwen replacement scope (preset-local):** inside the cebula-openai-hy3 block there are exactly 7 `opencode-go/qwen3.7-plus` references - architector (436), openspec-plan (456), reviewer (493), analyzer (521), analyzer-escalated (555), ai-specialist (580), ai-auditor (590). These 7 are preset-local and can be replaced in the clone.
- **Terra model:** exactly 1 Terra reference exists in the whole file - `openai/gpt-5.6-terra` at line 416, variant "high" (line 417). No `terra-medium` model exists anywhere in config. Any ox-alpha clone wanting a medium Terra variant has no source model to point at.
- **HARD BLOCKER - ox-alpha provider prefix:** no `ox-alpha` / `oxalpha` reference exists anywhere in config. The provider prefix for the ox-alpha model (e.g. `opencode-go/ox-alpha-...` vs `openai/ox-alpha-...`) is UNRESOLVED. The coder MUST NOT write the cloned block until this prefix is confirmed by the developer. This is the gate that stops config work.
- **Separate scope decisions:** Sol references (`openai/gpt-5.6-sol`, 3 occurrences at lines 436/555/590, all inside cebula-openai-hy3) and the global council Qwen block (lines 877-879, `opencode-go/qwen3.7-plus` councillor) are NOT part of the ox-alpha clone. They are separate scope decisions and must not be touched by the ox-alpha change.

## Pattern

- Clone source = `cebula-openai-hy3`; clone target = `.opencode/oh-my-opencode-slim.jsonc` only.
- Replaceable in clone: the 7 preset-local `opencode-go/qwen3.7-plus` refs.
- Terra: single `openai/gpt-5.6-terra` (high variant); no terra-medium exists - do not invent one.
- ox-alpha provider prefix: unknown -> hard blocker, resolve before any write.
- Sol (3 refs) + global council Qwen: out of ox-alpha scope.

## Finding - correction (2026-08-24 ai-specialist diagnostic)

- **Source:** ai-specialist read-only diagnostic re-run against the live OpenCode Go model catalog and the official OpenCode documentation, both dated 2026-08-24.
- **Verified fact:** the ONLY Ox Alpha model ID that exists is `opencode-go/ox-alpha-free`.
- **Non-existent IDs:** `opencode-go/ox-alpha` and `opencode-go/ox-alpha-max` DO NOT exist in the live catalog or official docs.
- **Impact:** the eight ox-alpha preset references that were written with the non-existent IDs (`opencode-go/ox-alpha` and `opencode-go/ox-alpha-max`) are invalid and cause mechanical fallback under OpenCode model routing (the lanes fall back instead of resolving the intended model).
- **Supersedes:** the prior Hard blocker resolution (developer-confirmed `opencode-go/ox-alpha` / `opencode-go/ox-alpha-max`) is now contradicted by catalog/docs evidence. The verified free ID `opencode-go/ox-alpha-free` is the correct target.

## Developer decision (2026-08-24)

- Replace ALL EIGHT invalid preset references with the verified free ID `opencode-go/ox-alpha-free`.
- Rationale: only `opencode-go/ox-alpha-free` is real; the other two IDs are phantom and trigger fallback. Pointing every reference at the one verified ID removes the fallback and keeps the preset selectable.

## Outcome

### Prior outcome (SUPERSEDED - retained for history)

- COMPLETED 2026-08-24 - cebula-ox-alpha preset cloned and registered.
- Developer provider confirmation: the ox-alpha provider prefix (opencode-go/ox-alpha[-max]) previously flagged as an unresolved hard blocker by the ai-specialist gate (this findings file) was confirmed by the developer as the explicit model strings opencode-go/ox-alpha and opencode-go/ox-alpha-max, unblocking the coder config work.
- Equivalent validation: literal `make test-config` was BLOCKED (make absent in environment, exit 127); the documented Makefile test-config recipe was run manually and passed every step with exit 0 (JSONC, agent-names, all validate-* gates, docker compose config --quiet, node batch-d-infra suite). Selectability smoke via `opencode debug config` loaded preset cebula-ox-alpha (exit 0, ox-alpha models resolved).
- Audit result: independent ai-auditor review returned PASS WITH RESIDUAL RISK (advisory, permits registration).
- Remaining catalog-availability limitation: live model-catalog availability of opencode-go/ox-alpha and opencode-go/ox-alpha-max is an assumption from the developer's provider confirmation, not independently verified against the provider registry; if either model is unavailable at runtime the affected lanes fall back per OpenCode model routing.

### Corrected outcome (2026-08-24)

- SUPERSEDED: the prior 'COMPLETED' claim rested on developer-confirmed IDs (`opencode-go/ox-alpha`, `opencode-go/ox-alpha-max`) that the 2026-08-24 catalog/docs diagnostic proves DO NOT EXIST. The preset as registered points at phantom IDs and therefore triggers mechanical fallback on all eight references.
- VALIDATION/AUDIT HISTORY RETAINED: the manual test-config run (exit 0) and the ai-auditor PASS WITH RESIDUAL RISK result remain valid as records of what was executed at registration time; they did not catch the phantom-ID defect because the smoke load resolved 'ox-alpha models' against the then-assumed strings.
- CORRECTION ACTION (documentation completed and validated 2026-08-24): all eight invalid preset references are documented as `opencode-go/ox-alpha-free` in CHANGELOG.yaml/md and this outcome, per the Developer decision. The config file edit is out of scope for this learning-file correction and must be performed by the coder lane.

## Reusable lesson

- Before cloning an OMO preset, verify the source block, count the preset-local model refs that are in-scope to replace, and confirm every referenced model actually exists in config (Terra = high only, no medium). Flag any unresolved provider prefix as a hard blocker that gates all coder config work. Keep Sol and global council references as explicitly separate scope so the clone does not silently widen.

## Tags

DIA-260824-1c3e, cebula-openai-hy3, ox-alpha, oh-my-opencode-slim, preset-clone, qwen-replacement, terra-high, provider-prefix-blocker, sol-scope, council-qwen-scope, ai-specialist-gate, ox-alpha-free, phantom-id, mechanical-fallback, correction-2026-08-24
