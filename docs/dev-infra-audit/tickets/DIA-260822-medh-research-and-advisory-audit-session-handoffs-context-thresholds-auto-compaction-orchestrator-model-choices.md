# DIA-260822-medh - Research and advisory audit: session handoffs, context thresholds, auto-compaction, orchestrator-model choices

---

id: DIA-260822-medh
title: "Research and advisory audit: session handoffs, context thresholds, auto-compaction, orchestrator-model choices"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-22
source: inventory
date: 2026-08-22
created: 2026-08-22
updated: 2026-08-22

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

Disposition the four-topic advisory audit's open recommendations (R2/R4/R5 of
ana-session-handoff-context-audit) so the shipped work and the remaining gaps
are recorded on the ticket.

## Problem

- The audit was delivered and registered:
  `knowledge/ana-session-handoff-context-audit/ana-session-handoff-context-audit-report.md`
  (shelf entry `.opencode/memory-shelf.yaml:918`), and the adaptive
  session-compaction policy shipped
  (`.opencode/plugins/delegation-observer.ts:1676-1716`, `context-warning-60`
  at `:1716`; commits `36244eaa` RED, `62dbd06f` feat). The ticket, however,
  still holds the creation template and status OPEN, so none of this is
  visible from the ledger.
- Open recommendations are still open in current repo state:
  - R2: `github-copilot/gpt-5.3-codex` is still present at
    `.opencode/oh-my-opencode-slim.jsonc:360` (report gap G3, ai-auditor lane).
  - R4/G6: benchmark debt remains - `knowledge/model-registry.yaml:58`
    (`opencode-go/hy3`, `swe_bench_verified: null / no independent
reproduction archived`) and `:98` (qwen3.8-flash, null).
  - R5: no threshold authority note exists;
    `grep -n "handoff discipline\|not alternatives" docs/dev-infra-audit/NEXT-RUN.md`
    returns 0 matches.
  - R1 is already closed: `grep -rn "CONTEXT_PRESSURE_THRESHOLDS\|getContextPressure"
.opencode/plugins/` returns only a historical test comment
    (`__tests__/adaptive-session-compaction.test.mjs:166`).

## Verification

- [ ] Each recommendation R1-R7 has a disposition line in this ticket with
      file:line evidence
- [ ] R2, R4, R5 are fixed or linked to a new governing ticket
- [ ] `make test-config` exit 0

## Fix

Append an R1-R7 disposition table to this ticket. For the still-open items:
R2 - correct the ai-auditor model string through the AGENTS.md section 2.5
gate; R5 - add the one-paragraph handoff-vs-compaction threshold note to
`docs/dev-infra-audit/NEXT-RUN.md`; R4 - open/track the benchmark-fetch work.
Touch: this ticket; `docs/dev-infra-audit/NEXT-RUN.md` and
`.opencode/oh-my-opencode-slim.jsonc` only via the section 2.5 gate.

## Re-verify

```bash
grep -n "R1\|R2\|R4\|R5" docs/dev-infra-audit/tickets/DIA-260822-medh-*.md
grep -n "github-copilot/gpt-5.3-codex" .opencode/oh-my-opencode-slim.jsonc  # 0 after R2
grep -n "handoff discipline" docs/dev-infra-audit/NEXT-RUN.md               # non-empty after R5
grep -n "context-warning-60" .opencode/plugins/delegation-observer.ts       # policy still present
make test-config                                                            # exit 0
```

## References

- `knowledge/ana-session-handoff-context-audit/ana-session-handoff-context-audit-report.md:412-440` (5B gaps G1-G6, 5C recommendations R1-R7)
- `.opencode/memory-shelf.yaml:918-927` (shelf registration)
- `.opencode/learnings/external-patterns/2026-08-22-adaptive-session-compaction-policy.md` (research findings, Status: APPROVED)
