# DIA-186 - overnight AFK permission allow-list gaps: TUI permission prompts defeat autonomous mode

<!-- FILED 2026-08-15 (docs lane, coder agent). Planning/defect ticket - no
     implementation performed yet. An ai-specialist audit lane is dispatched
     separately and will feed findings into the disposition. -->

---

id: DIA-186
title: "overnight AFK permission allow-list gaps: TUI permission prompts defeat autonomous mode"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: developer-report
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffd17d2f9ffeJWz78uPpwPV7w2" # filing lane (docs, coder agent)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_ffd75c86bffeO5sZkgqbTf2y3y" # orchestrator session (filing dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-186-overnight-permission-prompt-gaps.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

**Observed symptom (developer report, 2026-08-15):** during the overnight
AFK campaign (4 parallel coder lanes in worktrees - DIA-177 / DIA-180 /
DIA-181 / DIA-182), "multiple permission requests" appeared in the opencode
TUI, defeating overnight autonomy (nobody is at the keyboard, so each
permission ask stalls the lane until a human answers or the DIA-098 R3
watchdog auto-rejects after the 5-minute timeout).

The four overnight coder sessions (evidence):

- `ses_ffd2b0365ffe5Dh2PJTXgvaoZT` (DIA-177 worktree lane)
- `ses_ffd2ae81effe6krK05vapSYejJ` (DIA-180 worktree lane)
- `ses_ffd2ad276ffeDIt6gEZnFi5Xiw` (DIA-181 worktree lane)
- `ses_ffd2abcc4ffeMmYZX9JahKdmbw` (DIA-182 worktree lane)

**Hypothesis (root-cause direction):** the worktree coder lanes' tool calls
hit permission `ask` boundaries in the coder agent's permission config. The
likely ask-triggering calls, from the overnight worktree pattern:

- `docker compose build` / `docker compose up` (dev-service bring-up)
- `make test-shell` / `make test-config` / `make test-*` (verification gates)
- `git worktree add` / `git worktree remove` / `git commit` / `git push`
- file writes under `.slim/worktrees/*` (the worktree base the batch-D
  dispatch payloads confine lanes to)

Each of these is a WRITE or EXEC-type permission whose pattern is not on the
coder agent's allow-list, so it surfaces as an interactive `ask`.

**Why the gap persists despite DIA-126 CLOSED:** DIA-126 (autonomous
overnight mode: permission allow-list + no-stall guarantees) is CLOSED in
the ledger as of 2026-08-14. Its closure satisfied:

- Direction (a) - expanded READ allow-list for the ORCHESTRATOR profile
  (knowledge/_, .opencode/learnings/_, scripts/_, docs/_, .sdd/_,
  openspec/_, .opencode/skills/\*, etc.).
- Direction (b)+(d) - DIA-098 R3: 5-minute permission-stall watchdog
  (auto-reject via postSessionIdPermissionsPermissionId) + a
  permission_asked_logged audit row per ask.

Neither covers this defect class:

1. DIA-126's profile expansion targeted the orchestrator's READ permissions
   and conspecter/tool-gap closures. The CODER lanes' WRITE/EXEC patterns
   (docker/make/git commands above, writes under .slim/worktrees/\*) were not
   added to the coder agent's allow-list, so they still `ask`.
2. DIA-098 R3 is a STALL guarantee (auto-reject after a 5-minute timeout),
   not a NO-STALL guarantee: the prompt still appears in the TUI and the lane
   still stalls up to 5 minutes per ask before the watchdog fires. The
   developer still sees "multiple permission requests" in the TUI - the exact
   symptom reported.

The allow-list was "hardened" for the overnight pattern, yet prompts still
occurred: this is a REAL observed defect, not a stale-config suspicion.

**Impact:** autonomous overnight windows (no human at the keyboard) are
interrupted by permission asks; lanes stall for minutes per ask even with the
watchdog, and the TUI is polluted with prompt noise. Same class as the
DIA-126 original failure report, but in the worktree-coder WRITE/EXEC
dimension instead of the orchestrator READ dimension.

**Workflow requirement:** the fix routes through the section-10
AI-Devtools Modernization Workflow (gate research -> developer review ->
design -> implement -> validate -> independent review -> register). An
ai-specialist audit lane is dispatched separately; its findings feed the
disposition. DIA-063 section-10 ticket gate satisfied by this ticket.

## Verification

How to reproduce / confirm the defect:

1. **Reproduce (live):** run an overnight-style worktree coder lane - e.g.
   dispatch a coder into a `.slim/worktrees/*` worktree with a payload that
   requires `docker compose build`, `make test-shell`/`make test-config`,
   `git worktree add`, `git commit`, and writes under `.slim/worktrees/*` -
   and observe the TUI for permission `ask` prompts (docker/make/git/bash
   patterns and write paths not on the coder allow-list). With no human at
   the keyboard, each ask stalls the lane until the DIA-098 R3 watchdog
   auto-rejects (default PERMISSION_STALL_TIMEOUT_MINUTES=5).

2. **Confirm from logs (post-hoc):** grep the session registries for
   permission events during the overnight window 00:30-01:00Z on 2026-08-15
   across the four coder sessions listed above:
   - `grep -i "permission" .opencode/session/registry.jsonl` - look for
     `permission_asked_logged` rows (every ask is logged per DIA-098 R3)
     and `permission_auto_rejected` rows (watchdog timeouts proving the ask
     stalled without a human).
   - `grep -i "permission" .opencode/session/messages.jsonl` - semantic
     events referencing permission asks / auto-rejects in the same window.

   A cluster of `permission_asked_logged` rows attributable to the four
   overnight coder sessions during that window confirms the defect.

3. **Config gap check (static):** inspect the coder agent's permission block
   in `.opencode/opencode.jsonc` (and the effective merged config via
   `opencode debug config`) and verify whether `docker compose *`,
   `make test-*`, `git worktree add|remove|commit`, and writes under
   `.slim/worktrees/*` are `allow`-listed or fall through to `ask`/`deny`.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
