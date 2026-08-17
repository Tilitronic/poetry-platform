# DIA-208 - cebula preset model swap: deepseek-v4-flash -> mimo-v2.5

<!-- Copy this template to a new file `DIA-<NNN>-<human-slug>.md` (bare
     `DIA-<NNN>.md` names are deprecated per DIA-110) and replace placeholders.
     Keep the YAML frontmatter block intact. Statuses VALIDATE and E2E (added
     2026-08-04, ticket-vocabulary drift fix) are audit-phase statuses - used
     while the gate-matrix validation / Docker+browser end-to-end runs are
     pending or in progress; they transition to fix-lane states via Fix ->
     Re-verify. -->
<!-- GRANDFATHERED: DIA-001 through DIA-049 use v1 schema (no session fields).
     Session-attribution fields are OPTIONAL for all tickets. New tickets SHOULD
     populate them; existing tickets are not retroactively updated. -->

---

id: DIA-208
title: "cebula preset model swap: deepseek-v4-flash -> mimo-v2.5"
area: opencode-config
severity: Major # critical priority per developer 2026-08-17
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped

# config change; research gate satisfied by res030; ai-specialist gate lane down

# per DIA-206 - research routed to @researcher per documented workaround

gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component

# config-only, no new module/API/schema

gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: fix-lane
source: developer-directive
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "ses_ff0d569b5ffeDd79IQRdV73WlB" # OpenCode session ID that owned this ticket
lane_id: "orchestrator" # e.g. cod-1, ai--3
agent: "orchestrator" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

- Developer directive 2026-08-17 (critical priority): deepseek-v4-flash is now
  expensive on OpenCode Go; update the cebula preset (active preset in
  `.opencode/oh-my-opencode-slim.jsonc`) to use mimo v2.5 as the primary model.
- Research res030 (2026-08-17, triple-source: official docs + models.dev API +
  community tracker snapshot 10:08 UTC) confirms: deepseek-v4-flash price rose
  $0.14/$0.28 -> $0.22/$0.66 off-peak / $0.44/$1.32 peak (+57-371%); monthly
  request budget collapsed 158,150 -> 18,900 (-88%); usage bucket $60 -> $15;
  2x promo removed. mimo-v2.5 (non-pro) is the new volume king: $0.14/$0.28,
  150,400 req/mo, $60 bucket - same price point as archived Flash with 8x the
  budget.
- Developer approved EBDV Variant A (full swap): replace all 7
  deepseek-v4-flash entries in the cebula preset (orchestrator, coder,
  conspecter, resource-manager, memory-manager, code-navigator, researcher)
  with opencode-go/mimo-v2.5.
- Also in scope: update knowledge/model-registry.yaml (stale at Flash
  $0.14/$0.28 / 158,150 req/mo; add mimo-v2.5 entry; fix deepseek-v4-pro price
  anomaly noted in res030 conspect section 7 - res013's V4 Pro $0.435/$0.87 was
  a transcription collision with mimo-v2.5-pro's price; fresh value $0.66/$1.98
  off-peak / $1.32/$3.96 peak per tracker).
- Routes through AGENTS.md section 2.5: coder implement -> make test-config ->
  ai-auditor independent review -> CHANGELOG registration -> restart-verify.

## Verification

1. `.opencode/oh-my-opencode-slim.jsonc` cebula preset: no remaining
   deepseek-v4-flash references; 7 lanes point to opencode-go/mimo-v2.5
   (verify model ID resolves on Go per go-models.json in res030 sources).
2. knowledge/model-registry.yaml: deepseek-v4-flash entry updated
   ($0.22/$0.66, 18,900 req/mo, $15 bucket, promo removed); mimo-v2.5 entry
   added ($0.14/$0.28, 150,400 req/mo, $60 bucket); deepseek-v4-pro price
   corrected.
3. `make test-config` exit 0 (config validation + agent-name lockstep +
   changelog schema).
4. ai-auditor independent review (AGENTS.md 2.5 Phase 6) - APPROVE expected.
5. CHANGELOG.yaml entry appended + CHANGELOG.md regenerated +
   validate-changelog.sh exit 0.
6. Restart-verify: after OpenCode restart, cebula preset lanes use mimo-v2.5
   (developer confirms).

## Fix

- Commit 1baee98f133e9ea84934ae23443f6fc9505e52d5 (DIA-208): cebula preset
  swap deepseek-v4-flash -> opencode-go/mimo-v2.5 across all 7 lanes
  (orchestrator, coder, conspecter, resource-manager, memory-manager,
  code-navigator, researcher) in `.opencode/oh-my-opencode-slim.jsonc`, plus
  knowledge/model-registry.yaml update: deepseek-v4-flash corrected to
  0.22/0.66 and 18,900 req/mo with $15 bucket (promo removed); NEW
  mimo-v2.5 entry added (0.14/0.28, 150,400 req/mo, $60 bucket);
  deepseek-v4-pro price corrected 0.66/1.98 (transcription collision with
  mimo-v2.5-pro per res030 conspect section 7); routing Rung0/Rung1 ->
  mimo-v2.5.
- Commit bedfaddb8688e83e65911f6de5ac53a17e567fd5 (ai-auditor nits): the 7
  lanes now use valid fallback ["opencode-go/mimo-v2.5",
  "opencode/mimo-v2.5-free"]; deepseek-v4-flash registry role updated to
  "coder-volume-fallback".
- Commit a7b9c21 (CHANGELOG registration, 99 entries).
- Verification: `make test-config` exit 0 (56/56) after both commits;
  ai-auditor APPROVE-WITH-NITS (4 PASS, 2 nits, both fixed); pre-commit
  hooks passed via container delegate.
- Evidence: research res030 (triple-source 2026-08-17: Flash $0.22/$0.66
  off-peak / $0.44/$1.32 peak, 18,900 req/mo (-88%), $15 bucket, 2x promo
  removed; mimo-v2.5 $0.14/$0.28, 150,400 req/mo, $60 bucket).
- EBDV: developer chose Variant A (full swap) over B (mimo-v2.5-pro),
  C (hybrid), D (abort).

## Re-verify

- PENDING: restart-verify - developer restarts OpenCode; cebula preset lanes
  should use mimo-v2.5. Ticket stays OPEN until developer confirms.
