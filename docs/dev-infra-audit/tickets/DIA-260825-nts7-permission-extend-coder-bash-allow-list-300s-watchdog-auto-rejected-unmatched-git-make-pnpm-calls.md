# DIA-260825-nts7 - permission: extend coder bash allow-list - 300s watchdog auto-rejected unmatched git/make/pnpm calls

---

id: DIA-260825-nts7
title: "permission: extend coder bash allow-list - 300s watchdog auto-rejected unmatched git/make/pnpm calls"
area: agent-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-25

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- .opencode/opencode.jsonc # coder + coder-escalated bash maps: allows (3fe6937) + audit-fix denies
- .opencode/learnings/external-patterns/2026-08-25-coder-bash-allowlist-watchdog.md # ticket ref corrected e9ou -> nts7
- .opencode/learnings/external-patterns/2026-08-25-git-deny-pattern-precedence.md # gate findings registration
  artifacts: []
  evidence:
- "commit 3fe6937: allow-list extension (coder/coder-escalated bash maps)"
- "audit-fix commit referencing DIA-260825-nts7: deny entries for destructive git forms (--no-verify quartet, checkout-destructive quartet, branch -D pair, re-stated global destructive denies), learnings registration + ticket-ref correction"

---

## Description

Root cause: the coder agent bash permission is a deny-by-default allow-list MAP
at opencode.jsonc:312-324. It does NOT inherit the global "\*": "allow" baseline.
Commands outside the list default to "ask", and the needs-input-observer
plugin (hardcoded 300s watchdog, env PERMISSION_STALL_TIMEOUT_MINUTES) auto-
rejects unanswered prompts with "no_human_response_within_threshold". Three
fix-lane sessions died this way before any work started: cod-2, cod-3, cod-4.

Gate verdict: APPROVE-WITH-NOTES by ai-specialist session
ses_fc6f516efffeO0DdLJ4kEH4r2J (generation 17, cross-ref DIA-260825-e9ou).

coder-escalated has the same gap: its bash allow-list (opencode.jsonc:342-349)
contains zero allows, so it also defaults to "ask" and hits the 300s watchdog.

## Verification

Verification plan (audit-fix, developer accepted ALL ai-auditor FAIL findings):

- [ ] `make test-config` exit 0 on host (JSONC parses cleanly, agent-name and
      config invariants hold).
- [ ] Deny entries present in BOTH coder and coder-escalated bash maps:
      git commit --no-verify quartet (flag-first / mid / end / bare),
      git checkout destructive quartet ("-- _", "--", ".", "._"),
      git branch -D pair (starred + bare), re-stated global destructive
      denies (reset --hard, clean -f family). No existing allows removed.
- [ ] ai-auditor re-audit passes (CRITICAL destructive-forms finding,
      HIGH --no-verify bypass finding, MEDIUM learnings/ticket-metadata
      findings all verified-closed).

Status stays OPEN until the ai-auditor re-audit passes.

## Fix

Audit-fix (2026-08-25), implements the binding ai-specialist gate findings:

1. .opencode/opencode.jsonc - coder AND coder-escalated bash permission maps:
   appended deny entries after the allows (deny beats allow by
   longest-pattern-wins regardless of position):
   - "git commit --no-verify _", "git commit _ --no-verify _",
     "git commit _ --no-verify", "git commit --no-verify" (closes the HIGH
     pre-commit/docker-gate bypass, DIA-094/DIA-096)
   - "git checkout -- _", "git checkout --", "git checkout .",
     "git checkout ._" (closes discard-working-tree via broad allow)
   - "git branch -D \*", "git branch -D" (bare form needed: starred pattern
     does not match argument-less command - trailing-space gotcha)
   - re-stated global destructive denies for local clarity: "git reset --hard _",
     "git reset --hard", "git clean -f_", "git clean -fdx", "git clean -fd",
     "git clean -f" (agent-level map does not inherit global baseline)
2. .opencode/learnings/external-patterns/2026-08-25-git-deny-pattern-precedence.md -
   NEW gate-findings registration: longest+last match semantics, trailing-space
   gotcha, flag-position variants, proven allow-broad/deny-specific precedent
   ("git push _" allow + "git push --force _" deny). Cross-references
   DIA-260825-nts7.
3. .opencode/learnings/external-patterns/2026-08-25-coder-bash-allowlist-watchdog.md -
   ticket cross-reference corrected from DIA-260825-e9ou to DIA-260825-nts7.

## Re-verify

> To be filled at re-verify time (ai-auditor targeted re-review, cycle 1/2).

## UPDATE - 2026-08-25: re-audit cycle 1/2 PASS WITH RESIDUAL RISK; residual deny batch applied; CLOSED

ai-auditor targeted re-review (cycle 1/2): **PASS WITH RESIDUAL RISK** -
4/4 prior findings verified-closed.

Developer disposition:

- O1 (long-form branch delete) fix ACCEPTED.
- O3 (short-form no-verify alias) fix ACCEPTED.
- O2 accepted AS BY-DESIGN RESIDUAL (no code change).

This commit applies the accepted O1+O3 fixes: appended to the
DIA-260825-nts7 deny block in BOTH coder and coder-escalated bash maps of
.opencode/opencode.jsonc (same style, WHY comments):

- O1: "git branch --delete --force \*", "git branch --delete --force"
  (long-form equivalent of denied -D).
- O3: "git commit -n _", "git commit _ -n _", "git commit _ -n"
  (short-form no-verify alias; skips husky pre-commit like --no-verify).

Verification: `make test-config` exit 0 in poetry-dev container; JSONC
parses cleanly; all 5 new entries confirmed present with value "deny" in
both maps.

Status flipped OPEN -> CLOSED. Restart-verify stays recorded as PENDING
until next OpenCode restart confirms the config loads without warnings.
