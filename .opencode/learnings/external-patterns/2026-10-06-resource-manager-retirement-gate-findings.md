---
date: 2026-10-06
topic: Resource-manager retirement gate findings - Option A merge into researcher (DIA-260929-3ydp)
source: ai-specialist section-2.5 Phase 1 gate, campaign ticket DIA-260929-3ydp
ticket: DIA-260929-3ydp
status: registration-only
---

# Section-2.5 gate findings: resource-manager retirement, Option A (DIA-260929-3ydp)

Scope: registration of @ai-specialist gate findings for Option A (merge
`resource-manager` into `@researcher` and remove the lane), AGENTS.md
section 2.5 step 1. No config changes, no retirement implementation, no
staging, no commit in this file.

## 1. Verdict + evidence (Option A, spot-verified by the gate)

Analyzer report `knowledge/ana-260929-17rl-...report.md` claims were
independently spot-verified by the gate:

1. **Usage:** zero recorded dispatches (retained registry). Phrase the
   premise as **no persisted curation outcome** - the registry coverage gap
   2026-08-03..06 is unobservable - NOT "zero dispatches ever".
2. **Write scope:** unique write scope is `.opencode/oh-my-opencode-slim/knowledge/`
   only (2 files).
3. **Duplication:** star-count + Tier-2 methodology duplicated in the
   ai-specialist prompt.
4. **Broken differentiators:** both differentiators documented broken
   (lessons.md:209-214, :220, :589-599).

## 2. Stale analyzer line numbers

The analyzer's `oh-my-opencode-slim.jsonc` line numbers are stale
(832/826/834/181/425/658/796). Current (verified this session):
14/177/319/349/350/355-357; exactly 2 presets.

## 3. New surfaces the candidate list missed

These must be in the atomic edit set; the analyzer candidate list did not
include them:

- `.opencode/oh-my-opencode-slim/orchestrator_append.md:178` and `:399`
  (LIVE runtime orchestrator prompt)
- `docs/onboarding.md:131`
- `docs/dev-infra-audit/opencode-infrastructure.md:288` (mermaid node +
  incident edges)
- `knowledge/model-registry.yaml:35,47,59` (three `lane:` arrays)
- `.opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md:3`

## 4. Atomic edit set (summary)

Config and prompt surfaces:

- `opencode.jsonc:230` (allow-list key)
- `opencode.jsonc:620-642` (comment + agent block)
- `opencode.jsonc:527-531` (researcher edit map +=
  `.opencode/oh-my-opencode-slim/knowledge/*`)
- `opencode.jsonc:518-523` (researcher comment)
- `slim.jsonc:14` (composition comment)
- `slim.jsonc:177-187` + `:319` (BOTH preset keys - forgetting either breaks
  invariant 2)
- `slim.jsonc:349` + `:350` (ai-specialist referral redirect)
- `slim.jsonc:355-358` (agents block)
- `AGENTS.md:272`
- `practice-protected.md:59` + `:73-78`
- `ai-specialist.md:31`
- `ai-auditor.md:23`
- `ai-assist-sources.yaml:238`
- `researcher.md:45-47` + `:72`

Doc-accuracy surfaces:

- `NEXT-RUN.md:157`
- `onboarding.md:131`
- `opencode-infrastructure.md:288`
- `model-registry.yaml:35/47/59`
- `opencode-best-practices.md:3`

Bookkeeping:

- DIA-260827-ic3r resolved-by-deletion (no separate config edit)
- close DIA-260929-3ydp

## 5. Name-lockstep contract (no script edit)

`scripts/validate-agent-names.sh` has NO hardcoded agent names (extracts
S1-S4 at runtime, containment contract). No script edit, no S4_EXEMPT
change. Removal keeps it green; expected summary drops 21 -> 20 `passed`.
The bats suite asserts 1/3/6/0, not 21.

## 6. Methodology home (do not create a third copy)

Keep star-count/Tier-2 policy in `@ai-specialist` (already there,
ai-specialist.md:17-19) plus the curated file's own
`community_source_evaluation.evaluation_rules` (ai-assist-sources.yaml:249-260).
Do NOT copy it into researcher - a third copy re-creates the duplication
defect. Researcher gets the glob + a pointer only.

## 7. No runtime code references

Grep found zero executable string comparisons in `scripts/` and `plugins/`
(validators extract names dynamically). The literal only appears in
prose/config/scratch.

## 8. Open questions (do NOT block removal)

1. Registry gap (2026-08-03..06 unobservable).
2. lessons.md:220 run with no registry row.
3. Missing DIA-007 ticket file.

None blocks; capability is preserved by the merge.

## 9. Risk to flag

An IN-FLIGHT OpenSpec change
`openspec/changes/dia-260827-ft3z-fetch-artifact-write-containment/`
references resource-manager across proposal/design/tasks/specs and must be
reconciled before it lands. Also two stale gitignored copies reference it
(`.worktrees/*/scripts/promo-preset-apply:41`, `.scratch/*`) - inert, do
not edit.

## 10. Validation plan (for the implementation phase, not here)

- `bash scripts/validate-agent-names.sh` (exit 0,
  `20 passed, 0 failed, 0 warnings`, no `ok: resource-manager`)
- `make test-config` (exit 0)
- restart + smoke (no `resource-manager` in `opencode agent list`;
  @researcher can write the OMO knowledge dir)

Outcome: implemented (Option A); validators green (`make test-config` exit
0; `scripts/validate-agent-names.sh` 26 passed, 0 failed); ai-auditor
Phase-6 verdict accept-with-conditions, then targeted re-review cycle 1/2
all prior findings closed (F1-F4 verified-closed; F5 deferred by developer;
openspec ft3z reconciliation flagged as follow-up); restart + commit still
pending.

## Tags

DIA-260929-3ydp, resource-manager-retirement, option-a, merge-into-researcher,
ai-specialist-gate, agent-name-lockstep, oh-my-opencode-slim, ai-assist-sources,
openspec-reconciliation, registration-only, S10
