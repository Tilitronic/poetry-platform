# DIA-260929-bgnw - ai-specialist gate token ownership under edit deny

---

id: DIA-260929-bgnw
title: "ai-specialist gate token ownership under edit deny"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

Define who may mint the section-10 ai-specialist gate-review token and how the reader
knows it was minted by an actual ai-specialist review, given that ai-specialist
itself runs under `edit: deny`.

Reconstructed from title + current repo state; original reporter context not
recoverable (commit `16f3831d` and the README rollup only carry the title, and
no learning, CHANGELOG entry or openspec doc cites this ID).

## Problem

- The token is documented as ai-specialist's own artifact:
  `.opencode/plugins/delegation-observer.ts:399-401` - "the gate token file that
  @ai-specialist writes after completing its gate review. Edits to .opencode/
  and AGENTS.md are mechanically blocked until this file exists".
- ai-specialist cannot write anything: its permission block is
  `edit: deny, bash: deny, task: deny` (`.opencode/opencode.jsonc:772-782`).
  So the documented owner is physically incapable of producing the token.
- The actual writer is the plugin, on a `log_decision` call with
  `event_type: "gate-token"`: `delegation-observer.ts:2628-2645` writes
  `session_id: input.sessionID` for `resolution_status: "done"` and unlinks for
  `"cleared"`. That `session_id` is the CALLER's session, not an ai-specialist
  review session, and the branch appends NO registry row - mint and clear are
  unauditable (grep for `gate-token` in `.opencode/session/registry.jsonl`
  returns 0 rows; the only gate events present are 70 `a5_quality_gate`, 19
  `autocrine_gate_warn`, 19 `gate_blocked`).
- Any lane can be that caller: `log_decision` is declared `allow` exactly once,
  in the orchestrator block (`.opencode/opencode.jsonc:258`), and the global
  permission block (`.opencode/opencode.jsonc:29-136`) declares only `edit`,
  `ast_grep_replace`, `ast_grep_search` and `bash` - undeclared keys resolve to
  ALLOW per the baseline comment at `.opencode/opencode.jsonc:26-28`.
- The reader does not check ownership: `gateTokenValid()`
  (`delegation-observer.ts:1060-1074`) only requires `session_id`,
  `timestamp` and `event_uuid` to be present. The live token proves the
  consequence - `.opencode/session/gate-tokens/ai-specialist-reviewed` contains
  `{"session_id":"ses_013b40c09ffeqy1Zej16hiUa51","timestamp":"2026-08-10T15:36:55.853Z",...}`
  and is still granting .opencode/ + AGENTS.md edit access to every lane in
  every session (no expiry, no session binding) months later.

## Verification

- [ ] The token carries, and `gateTokenValid()` checks, an ownership field that
      ties it to an ai-specialist gate review (lane/agent name plus a bounded
      timestamp), not just three presence fields.
- [ ] Mint and clear both append a registry row (event name of the writer's
      choosing, e.g. `gate_token_written` / `gate_token_cleared`) carrying
      `session_id` and the owner lane; `grep -c gate_token .opencode/session/registry.jsonl`
      is no longer 0 after one mint.
- [ ] A structurally-valid token with the wrong/missing owner is rejected and
      the section-10 edit gate blocks as it does for an absent file.
- [ ] AGENTS.md / the `delegation-observer.ts:399` comment state the real
      writer (plugin on `log_decision`), not "@ai-specialist writes".
- [ ] `make test-config` exit 0.

## Fix

Smallest concrete change, all in existing seams:

1. `.opencode/plugins/delegation-observer.ts:2630-2640` - write an extra
   `owner` field (the review lane, `ai-specialist`) into the token JSON and
   append a registry row on both the write and the unlink branch.
2. `.opencode/plugins/delegation-observer.ts:1064-1074` - `gateTokenValid()`
   additionally requires `owner === "ai-specialist"` and a non-expired
   `timestamp`; fail closed (it already fails closed on parse errors).
3. `.opencode/plugins/delegation-observer.ts:399-401` - correct the comment to
   name the plugin as writer and ai-specialist as the attested owner; mirror the
   wording in AGENTS.md section 2.5 if it repeats the claim.

No new file, no new tool, no permission-key change.

## Re-verify

    grep -n "owner" .opencode/plugins/delegation-observer.ts | head     # token payload + validator
    grep -n "log_decision" .opencode/opencode.jsonc                     # line 258 (orchestrator only) - unchanged
    sed -n '772,782p' .opencode/opencode.jsonc                          # ai-specialist still edit: deny - unchanged
    grep -c gate_token .opencode/session/registry.jsonl                 # 0 before one mint, >0 after
    cat .opencode/session/gate-tokens/ai-specialist-reviewed            # carries owner + timestamp after re-mint
    make test-config
