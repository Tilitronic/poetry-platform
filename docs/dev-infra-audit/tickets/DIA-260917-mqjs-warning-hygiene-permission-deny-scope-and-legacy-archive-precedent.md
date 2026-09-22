# DIA-260917-mqjs - warning hygiene permission deny scope and legacy archive precedent

---

id: DIA-260917-mqjs
title: "warning hygiene permission deny scope and legacy archive precedent"
area: config
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-22

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

Scope (reconstructed 2026-09-22 backfill; body was template-empty at creation):
warning-hygiene permission-deny scope plus legacy-archive precedent for
grandfathered sequential-ID tickets. Gate evidence lives in
.opencode/learnings/external-patterns/2026-09-17-DIA-260917-mqjs-warn-hygiene.md
(13 lines): Variant A approved = per-agent deny x4 + archive 13 (DIA-167..179);
recon notes audit coverage is value-blind (allow would silence warnings as much
as deny, so use deny only), global block lines ~24-118, per-agent maps for
analyzer/reviewer/observer/conspecter, no global top-level-deny precedent, and
archive scanners exclude archive/ except blocker/show/update. Implemented by
commit 60740412 (2026-09-17): 18 files changed, 316 insertions, 58 deletions.

## Verification

- [x] Commit 60740412 exists in git log with subject "DIA-260917-mqjs: archive
      13 legacy DIA-167..179 tickets, rollup recomputed" and 18-file stat
      (verified 2026-09-22 via git show --stat).
- [x] Archive holds the 13 files DIA-167..DIA-179 under
      docs/dev-infra-audit/tickets/archive/ (count verified 2026-09-22: 13).
- [x] README rollup recomputed by that commit: 13 DIA-167..179 rows removed
      from the main table, mqjs row added as OPEN (verified via git show diff).
- [x] make test-config exit 0 on 2026-09-22 (batch-d suite 57/57 pass; skills
      26 passed; agent-names 27 passed; structural gates PASS).

## Fix

> Commit 60740412 (2026-09-17) performed the archive move (git mv of 13 files
> DIA-167..179 into docs/dev-infra-audit/tickets/archive/), recomputed the
> README rollup, updated the knz2 ticket with the Part A deny disposition, and
> touched .opencode/oh-my-opencode-slim.jsonc (+279/-? lines). Backfilled here
> 2026-09-22 from git-log evidence; no new code change in this lane.

## Re-verify

> Re-verified 2026-09-22: commit present with stated subject/stat; archive
> count is 13; rollup diff confirms row removal + mqjs OPEN row; make
> test-config MAKE_EXIT:0. Status stays OPEN per lane instruction (no status
> change). Unticked items and reasons: (1) per-agent deny x4 detail NOT ticked
>
> - the jsonc hunk in 60740412 contains only 3 "deny" mentions, so x4 cannot be
>   asserted from this lane; (2) test-shell subset NOT run - warning/permission
>   scope is config surface covered by test-config, no shell artifact changed by
>   this ticket; (3) original warning-hygiene acceptance criteria NOT ticked -
>   body was template-empty, so no contemporaneous criteria exist to verify
>   against.
