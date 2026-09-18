# Promo Preset Infrastructure - ai-specialist Findings

- Date: 2026-08-28
- Ticket: DIA-260828-qtsi
- Source: ai-specialist lane ses_fb84fdf72ffetpTIbYgKo79gS8
- Status: LEARNINGS REGISTRATION + IMPLEMENTED. Variant A applied by @coder (DIA-260828-qtsi, campaign ticket). Config changes (R1-R5) implemented and verified; see Verification Evidence below.

## Current Preset Landscape

- 6 presets declared in `.opencode/oh-my-opencode-slim.jsonc` (preset block).
- Active preset: `cebula-hy3` (wired as default in the project runtime).
- Presets are monolithic blocks: each preset inlines full agent/model/prompt config with no inheritance or shared base.
- No mechanism exists to promote a preset to active, nor to record promotion history.

## Gaps (G1-G5)

- G1: No promo mechanism. Nothing marks which preset is "promoted" or records promotion transitions.
- G2: No json store. Promotion state has no structured, machine-readable home (no registry file).
- G3: No auto-review skill. After a promo, nothing periodically re-verifies the promoted preset still fits.
- G4: `muse-spark` missing from registry. The `muse-spark` preset/agent is referenced but absent from the preset registry, causing a dangling reference.
- G5: Review-diversity gap. Promotion review has no cadence or diversity rule, so a single model/preset can stay promoted without challenge.

## Recommendations (R1-R5)

- R1: Add sidecar store `.opencode/promo-registry.json` holding current promoted preset, history, and timestamps.
- R2: Add patch script `scripts/promo-preset-apply` that atomically flips the active preset pointer and appends a history entry to the registry.
- R3: Place the promo preset as a discrete preset block (not merged into `cebula-hy3`) so promotion is a pointer swap, not an edit of the active block.
- R4: Add skill `promo-review` with a 2-week cadence tuned for weekend coding windows of 6-8h, re-verifying the promoted preset against current needs.
- R5: Define model routing for `muse-spark` / `hy3` / `mimo` so the promoted preset selects the right model per task class.

## Evidence Sources (S1-S9, tiered)

- S1 (Tier-1, committed): `.opencode/oh-my-opencode-slim.jsonc` preset block - ground-truth of 6 presets and active `cebula-hy3`.
- S2 (Tier-1, committed): `.opencode/opencode.jsonc` agent block - confirms no promo/inheritance field.
- S3 (Tier-1, committed): `scripts/` directory listing - confirms no existing `promo-preset-apply`.
- S4 (Tier-1, committed): `.opencode/learnings/external-patterns/` prior entries - precedent for sidecar registry pattern.
- S5 (Tier-2, dated URL): OpenCode docs - preset schema has no native promo/inheritance field (fetched live by ai-specialist).
- S6 (Tier-2, dated URL): oh-my-opencode-slim docs - preset blocks are monolithic, no base inheritance.
- S7 (Tier-2, dated URL): OMO changelog - skill registration mechanism supports a `promo-review` skill.
- S8 (Tier-3, [INFERENCE]): `muse-spark` dangling reference implies a registry sync gap; not sole basis.
- S9 (Tier-1, committed): `AGENTS.md` section 2.5 - mandates this learnings registration before coder config-work.

## Decision Variants (A-D)

- A (RECOMMENDED): Sidecar `.opencode/promo-registry.json` + `scripts/promo-preset-apply` patch + `promo-review` skill. Works within OMO schema constraints (no schema extension needed); promotion is a pointer swap plus a json append.
- B: Extend OMO preset schema with a native `promoted`/`inherits` field. Cleaner model but requires upstream schema change and is out of project control.
- C: Merge promo logic into `cebula-hy3` block directly. Smallest diff but breaks R3 (no discrete promo preset) and complicates rollback.
- D (ABORT / status-quo): Keep monolithic presets, no promo mechanism. Avoids change but leaves G1-G5 unaddressed.

Recommendation: A. Because it operates entirely within the existing OMO schema (no upstream dependency), keeps the active block untouched (pointer swap only), and adds the missing json store (G2) and auto-review skill (G3) without violating schema constraints.

## Next Step

This file is the learnings registration (section 2.5 step 1). Config changes (R1-R5) were authorized and applied by `@coder` under campaign ticket DIA-260828-qtsi. Authorization outcome: APPROVED + IMPLEMENTED (Variant A).

## Verification Evidence (DIA-260828-qtsi, @coder fix of ai-auditor B1/B2/B7/B9)

- `make test-config` -> exit 0 (57/57 tests pass, observer-dedupe gate ok).
- `scripts/promo-preset-apply --dry-run` -> exit 0 (valid JSON, block printed).
- `scripts/promo-preset-apply` run twice -> `grep -c "PROMO PRESET" .opencode/oh-my-opencode-slim.jsonc` == 1 both times (idempotent; B1 fixed: header no longer stacks on 2-week re-review).
- `.opencode/oh-my-opencode-slim.jsonc` valid JSONC (json.loads on comment-stripped text); `"free": {` at 4-space indent (B2 fixed; script no longer strips the next preset's indentation).
- `.opencode/promo-registry.json` valid JSON; `model-registry.yaml` unchanged/valid.
- B7: this file outcome updated from PENDING to APPROVED + IMPLEMENTED.
- B9: shelf entries added for res041-opencode-go-promo-benchmarks (conspects) and ana036-weekend-coding-preset-efficiency (analyses) in `.opencode/memory-shelf.yaml`.

Root cause of B1: `find_preset_block` matched only the `    "promo": {` body, so re-runs kept the old header in `raw[:start]` and prepended a new one. Fix: `find_promo_region` now extends the matched span backward over the auto-generated header comment block (guarded by an auto-generated marker), so re-runs replace the whole region. Root cause of B2: the replace-path whitespace skip consumed the next preset's indentation spaces; fix skips only newlines.
