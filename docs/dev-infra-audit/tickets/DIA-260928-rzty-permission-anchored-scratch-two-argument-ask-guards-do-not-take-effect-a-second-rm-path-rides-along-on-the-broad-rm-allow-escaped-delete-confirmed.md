# DIA-260928-rzty - permission: anchored .scratch two-argument ask guards do not take effect; a second rm path rides along on the broad rm \* allow (escaped delete confirmed)

---

id: DIA-260928-rzty
title: "permission: anchored .scratch two-argument ask guards do not take effect; a second rm path rides along on the broad rm \* allow (escaped delete confirmed)"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

Origin: runtime probes run by a coder lane on 2026-09-28 under ticket DIA-260926-5vin, prompted by the C4 behavioural smoke of the .scratch allows added in commit f6c84a5.

Finding: the four anchored .scratch allows plus the three two-argument ask guards in agent.coder.permission.bash (mirrored in agent.coder-escalated.permission.bash) do NOT prevent a multi-argument rm from being ALLOWED. The runtime resolves a broad "rm \*" ALLOW for these commands, so the guards never win.

Probe evidence (all commands run as the sole command of one bash tool invocation, no redirection unless stated):

- A rm -rf .scratch/c4-probe 2>.scratch/.rm_stderr -> ASK (registry row permission_asked_logged; developer saw the prompt)
- B rm -rf .scratch/c4-probe -> allow, zero new registry rows
- C rm -rf .scratch/c4-smoke-a .scratch/c4-smoke-b -> allow, zero new registry rows (reproduced independently in a second lane: zero rows again)
- D rmdir .scratch/c4-guard-a .scratch/c4-guard-b -> ASK (so a guard CAN fire; the asymmetry versus C is the anomaly)
- E rm -rf .scratch/c4-esc-keep /tmp/c4-outside-esc -> the rm itself did NOT ask; BOTH targets were deleted

Decisive runtime evaluation log lines:
evaluated permission=bash pattern="rm -rf .scratch/c4-repro-a .scratch/c4-repro-b" action.pattern="rm _" action.action=allow
bash pattern="rm -rf .scratch/c4-esc-keep /tmp/c4-outside-esc" action.pattern="rm _" action.action=allow (no asking line at delete time)
The only ask in probe E happened earlier, on the `mkdir -p ... /tmp/c4-outside-esc` (external_directory gate for /tmp/\*), and the developer answered Allow once; that grant then covered the rm.

Impact: the comment at .opencode/opencode.jsonc:408-410 ("two-or-more-argument forms fall back to ask", "any other path still asks") is FALSE as implemented. Because external_directory only gates paths OUTSIDE the workspace, a second DESTRUCTIVE path INSIDE the workspace (for example: rm -rf .scratch/junk packages/apps/important-source) raises no prompt at all and is silently deleted.

Not yet established: which rule the merged coder rule set actually orders last (needs `opencode debug agent coder` merged output), and the exact matcher semantics (the repo's own documents contradict each other on last-match-wins versus longest-pattern-wins).

Suggested direction (not a decision): make the guards actually win, and/or drop the broad "rm \*" allow for agents that carry it, and/or add a hard deny for multi-argument rm. Route through the AGENTS.md section 2.5 config chain.

Falsified-ADR citation: the scratch-lifecycle ADR-001 invariant in `.sdd/scratch-lifecycle/architecture.md` is FALSIFIED by the observed behaviour recorded above. That document has NOT been edited; a future change must correct or supersede it.

Durable-evidence note: `.opencode/learnings/external-patterns/2026-09-28-permission-guard-ineffective-multi-argument-rm.md` is the durable evidence record for this finding. It is currently UNTRACKED in git, so it must be committed or the evidence is lost.

## Re-verify

> To be filled at re-verify time.
