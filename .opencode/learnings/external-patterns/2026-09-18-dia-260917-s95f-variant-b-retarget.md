# DIA-260917-s95f Variant B retarget triage (ai-specialist gate, AGENTS.md 2.5 step 1)

- Ticket: DIA-260917-s95f 'promo preset union-alpha variants enumeration'
- Date: 2026-09-18
- Gate: ai-specialist read-only triage (docs only, no config or script edits)
- Decision: Variant B retarget tests (developer chose Variant B over Variant A on 2026-09-18)

## Decision context

- Variant A (retarget tests to working tree: promo-union-alpha + muse-balanced) rejected.
- Variant B (retarget tests to ledger ground truth: promo + openai-first-cost-balanced) selected.
- Rationale: tests must enforce the committed ledger contract, not the uncommitted working tree.

## Ground truth (ledger)

- Presets: promo-union-alpha + muse-balanced (active) + free + openai-first-cost-balanced.
- No `promo` key in working tree at triage time.
- Root preset: muse-balanced.
- Fingerprint: 8-space indent line at line 262 (oh-my-opencode-slim.jsonc).
- Ledger (ADR 2142/2164, lessons L20260917-7jek-001) records promo as main preset; promo-registry promoted_preset=promo.

## Root cause

- Unrecorded working-tree rename: promo -> muse-balanced, plus re-added free preset.
- Working tree diverged from ledger; no ticket recorded the rename.
- Related commits: knz2 923dcab / a427f46.
- Ledger still says promoted_preset=promo (promo-registry); working tree has no promo key.

## Variant B scope

1. scripts/test-interview-enforcement.sh: stale tuple at line 74 + messages at lines 81/83.
2. scripts/check-orchestrator-prompt-drift.sh: PRESETS default at line 58 + header comment.
3. __tests__/workspace-preset-selection.bats: hardcoded preset fixtures.
4. __tests__/check-orchestrator-prompt-drift.bats: hardcoded preset fixtures.
5. scripts/promo-preset-apply: preset name references.
6. .opencode/promo-registry.json: promoted_preset + preset entries.
7. .opencode/memory/adr.md + .opencode/memory/lessons.md: rename record.
8. .opencode/CHANGELOG.yaml (+ rendered CHANGELOG.md): changelog entry.

## Latent break note

- Drift gate is hidden behind test-interview abort at Makefile:219.
- Interview gate aborts first, so drift-gate breakage stays latent until interview gate is fixed.

## Outcome

- Status: working-tree green, commit blocked.
- Coder Variant B done: 5 files (test-interview tuple, drift PRESETS, 2 bats fixtures, jsonc indent).
- Gates green: test-interview 5 PASS; drift 2 presets 9 markers byte-identical; drift bats 16 ok; workspace bats 9 ok; make test-config exit 0; make test-shell 717 pass; ASCII clean; docker DOWN no commit per DIA-094.
- ai-auditor: APPROVE-WITH-FOLLOWUPS. F1 target mismatch note. F2 ledger promo vs tree muse-balanced. F3 scope incomplete. F6 header fixed in same coder session. F7 generator stale do-not-run. F8 no restart/smoke + outcome pending.
- Developer disposition: Accept + followups.
- F6 fix done same session cod-1.
- Followups filed: DIA-260918-rbqk registry, DIA-260918-ubxv ADR, DIA-260918-mm2u generator, all OPEN.
- Blockers before commit: docker Up + re-review before commit + CHANGELOG pending.
- Polish 2026-09-18: CHANGELOG appended (yaml entry, scope scripts, rendered MD)
  for Variant B + F6; dev Up evidence hostname poetry-dev pwd /workspace
  (docker compose socket not mounted from inside, expected - execution inside
  dev proves Up); F6 closed (headers state true 4-preset inventory,
  promo-union-alpha + free explicitly unaudited); re-review 1/2
  APPROVE-WITH-FOLLOWUPS; commit pending polish (this turn).
