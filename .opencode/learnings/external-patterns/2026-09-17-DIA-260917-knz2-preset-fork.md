# DIA-260917-knz2 union-alpha sibling preset fork recon

Ticket: DIA-260917-knz2
Date: 2026-09-17
HEAD: 4531cb3
Gate: ai-specialist (AGENTS.md 2.5 step 1, docs only, no config edits)

## Gate deviation

- ai-specialist fork gate attempted twice
  (ses_f5077d534ffeR6RzehUi6O0ss1, ses_f507658c0ffe0OwNrJc3ntD409),
  both errored empty; partials preserved in
  .opencode/session/partial-results/.
- Root cause: ai-specialist lane routes opencode/union-alpha first, which
  is Endpoint unavailable - the lane's own change broke its own gate lane.
- Replaced gate mechanics with code-navigator recon
  ses_f50759146ffe1sa3PVptGGToGl.

## Recon results

- Sibling promo-union-alpha outside the promo region survives the
  generator: exact-key marker + replace splices touch only the promo span;
  insert path is inert while the promo exists.
- Per-lane fallbacks after fork: model[1] becomes primary.
  - orchestrator: muse-spark-1.3-free + go-mirror
  - architector: deepseek single-element array kept
  - 6 lanes: muse-free + go-contributor
  - ai-specialist / ai-auditor: muse-free + deepseek
  - researcher: muse-free + go-contributor
- Files to update:
  - drift checker PRESETS + interview-enforcement tuple must learn the
    sibling.
  - promo-preset-apply must NOT change.
  - validate-agent-names: no change.
  - registry stays on promo.
  - active pointer stays promo.
- Insertion point: after promo-close line 270, before the openai comment,
  with guard + blank lines (find_promo_region overcapture bug).

## Plan

- Copy current promo block to promo-union-alpha (union-alpha first
  preserved).
- Strip union-alpha from promo (model[1] becomes model[0]).
- Update drift + enforcement refs.
- test-config + smoke both presets.
- ai-auditor review, changelog, commit.

## Outcome

- Implemented in commit `923dcab81936c5e0f032a5a351b80e8f1a4a5783`, including
  the leading-space sibling-key fix. Active preset remains `promo`.
- Finalization recheck: promo zero Union Alpha references; sibling nine;
  `make test-config` exits 0 with 57 passed, 0 failed behavioral tests.
- Independent review skipped with explicit developer approval after two empty
  ai-auditor attempts (partials preserved); advisory only, not a passed review.
- Changelog registered via `scripts/changelog-add`; schema validation passes.
- Docker socket unavailable during finalization; no config edits or new commit.
