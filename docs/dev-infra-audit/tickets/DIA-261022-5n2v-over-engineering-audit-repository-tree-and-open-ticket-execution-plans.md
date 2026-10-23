# DIA-261022-5n2v - Over-engineering audit: repository tree and open-ticket execution plans

---

id: DIA-261022-5n2v
title: "Over-engineering audit: repository tree and open-ticket execution plans"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Audit result

Artifact pointers:

- Repository-tree audit (complete, this campaign): knowledge/ana-261022-v0z7-repo-overengineering-audit/ana-261022-v0z7-repo-overengineering-audit-report.md
- Open-ticket plan audit (12 simplify proposals, S1-S12): knowledge/ana-261022-k7ki-open-ticket-plan-overengineering/ (planned report path)

Accepted dispositions applied by this audit (2026-10-22):

- CLOSED DIA-260929-wjir - superseded by DIA-261022-6vcz (would reintroduce dead model id opencode-go/deepseek-v4-flash).
- CLOSED DIA-261022-mho5 - no-op (delegation-observer.ts:841 predicate already fail-safe; zero lines would change).
- CLOSED DIA-260927-k8nh - umbrella duplicating its children (0zii, shgj, hwl9 closed, h5xs remain the trackers).
- CLOSED DIA-260929-6339 - not proportionate (new validator + lookup table for two static keys; reopen path: 5-line assertion in scripts/validate-opencode-config.sh).
- CLOSED DIA-260827-15xv, DIA-260825-wprb - duplicate whole-repo audits, superseded by this ticket.
- MERGED DIA-261022-m6l8 -> DIA-261022-zjci (same delegation-observer.ts handoff seam).
- MERGED DIA-260928-tcdd, DIA-260926-5vin -> DIA-260928-rzty (same opencode.jsonc permission-rule pass/hunk).

Simplify set NOT yet applied - pending safety verification.

## Re-verification (developer six points)

- V1 cs3v duplication RETRACTED and confirmed: 7 boot-loaded copies (jsonc:31,:257,:344, orchestrator_append.md:372-428, AGENTS.md:50,60,220) all introduced by 0bdd2baf; deletion would revert audited work; none touched by this batch. .opencode/agents/reviewer.md does not exist - the reviewer contract lives in the jsonc card at :344.
- V2 CORRECTED: gpcc is a defer whose premise expired - 0a4caf7a fixed the three registry errors; test-typecheck is exit 0; wiring into test-config today is green. gpcc is now unblocked, not deferred.
- V3 CONFIRMED: deletions are only the inert resource-pressure block; REVIEWER ENVELOPE gates untouched; check-orchestrator-prompt-drift.sh unmodified and exit 0 (2 presets, 9 markers, 0 gaps). The extra addition hunk in delegation-observer.ts is S3 (f3c4 res_id extraction) from this same batch, not a foreign edit.
- V4 CONFIRMED divergence but signposted: 4 entries -> 1; validate-changelog exit 0; the cs3v entry at CHANGELOG.yaml:5166 (from d2d2a963) is untouched; facts now only in the ticket: Round 1-4 chronology, CHANGE 1-13 numbering, BRANCH A probe evidence, ai-auditor fallback chain. The surviving entry discloses the collapse and points here - accepted as a deliberate roll-up, no data lost.
- V5 CONFIRMED: the "three commits" claim lives in the prior handoff slot ses_e9eaaa58dffehK4a2koVfrer6v.json:12 and contradicts that same file's line 13, which lists four. True count: 4 in 0bdd2baf..3a6822b1 (ec347f2f, 5ddefc9e, a1adc59a, 3a6822b1), 5 today including 0a4caf7a. Handoff files are plugin-written; correction recorded here only, handoff not edited.
- V6 CONFIRMED and FIXED: the memory-manager edit allow-list did not cover .opencode/learnings/index.md (silent stale index, no deny row because the write never happens); one line added in this pass.
- Attribution: the 12 modified ticket bodies plus tickets/README.md belong to this campaign's disposition lane (closes/merges), not to the other session.
- Audit A independently verified by 3 lenses - see the artifact's corrections section; P6 and P7 executed, P10 and P1 next.
