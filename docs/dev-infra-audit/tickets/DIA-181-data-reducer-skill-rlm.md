# DIA-181 - data-reducer skill + scripts/data-reduce.sh: RLM pattern (reduce large data before reading into context)

<!-- RENUMBERED 2026-08-14 (reconciliation, cod-7): local DIA-157 collided with origin/omo-slim-changes ticket DIA-157-agent-instruction-files-audit.md (different ticket). Renumbered to DIA-181 per developer disposition. -->

<!-- Filed 2026-08-14 from the plan session (developer + build agent) adopting
     the DeepSeek TUI "Recursive Language Model" (RLM) pattern: when inputs
     exceed context-economical size, a worker process (python3/jq/rg/script)
     filters/searches/aggregates/extracts the data and only the compact result
     returns to the main agent. Complementary to native telemetry (DIA-182):
     RLM economizes the INPUT side; telemetry measures the OUTPUT side. -->

---

id: DIA-181
title: "data-reducer skill + scripts/data-reduce.sh: RLM pattern - reduce large data before reading into context"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "" # optional DIA-NNN parent epic ticket
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff149b9cffeJPjWogMtohNA19" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "build" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Agents regularly need to analyze large data blobs (multi-thousand-line logs,
the full `registry.jsonl` / `messages.jsonl`, big generated files). Today the
behavior is ad-hoc: some agents paste the raw data into the context (wasting
tokens), others improvise a `python3 - <<EOF` heredoc with no shared rule, no
output contract, and no measurement of how many tokens were actually saved.

This ticket formalizes the DeepSeek TUI "Recursive Language Model" (RLM)
pattern into a project skill + helper script:

- **Rule:** raw input over a size threshold (~100 KB / ~2000 lines) MUST be
  reduced in a worker process before its result is read into the model
  context. Never paste the whole blob.
- **Worker options:** `python3` heredoc, `jq`, `rg`, or existing project
  scripts (`scripts/jsonl-stats.sh`, `scripts/session-log`) - chosen per data
  shape.
- **Output contract:** compact structured result (< ~5 KB) plus a savings
  line: `input N KB -> result M KB (saved P%, ~Q tokens)`. Token estimate is
  the documented heuristic ~4 chars / token - label it as a heuristic, not a
  billable number.

Architecture fit (why this is RLM, not a new process): the orchestrator has
bash denied (DIA-060/083) and delegates work to lanes - so the reduction runs
in the worker lane (coder/analyzer/code-navigator/researcher) and only the
small result returns. The skill is the instruction layer; the script is the
measurement layer that makes the savings visible.

### Scope

1. `.opencode/skills/data-reducer/SKILL.md` - YAML frontmatter per DIA-037
   (`name: data-reducer` == dirname, non-empty description, body opens with an
   activation phrase "Use when..."), the size-threshold rule, worker options,
   output contract, savings-line format, and which lanes it applies to.
2. `scripts/data-reduce.sh` - helper: accepts an input (file or stream) and a
   reduction command, runs the reduction, measures input vs output bytes, and
   prints the savings line. Zero new runtime dependencies (bash + python3 +
   wc, all present in container and host). Must be safe with empty output.
3. `scripts/__tests__/data-reduce.bats` - bats coverage wired into
   `make test-shell` per the project script-test standard.
4. README index row in `docs/dev-infra-audit/tickets/README.md`.

### Out of scope

- Any plugin change, any config-surface change (skill only), any persistent
  worker/REPL process (a plain one-shot helper first; a stateful worker is a
  follow-up if measurement proves it worth it).
- Per-tool telemetry (handled by DIA-158 as a native wrapper, not a plugin).

### Section-10 routing

New skill file under `.opencode/skills/` is AI-devtools scope (global
AGENTS.md section 10). Fast-tracked by direct developer approval during the
2026-08-14 plan session (new skill, low risk); the plugin-side change
(DIA-158 as originally scoped) was dropped in favor of native telemetry, so
no ai-specialist research is required for this ticket.

## Verification

- [ ] `make test-skills` exit 0 (DIA-037 validator: frontmatter parses,
      `name == dirname`, description non-empty).
- [ ] `make test-shell` exit 0 (data-reduce.bats green).
- [ ] `make test-config` exit 0.
- [ ] Smoke: `bash scripts/data-reduce.sh` against a fixture of ~10k lines
      prints a savings line (`input ... -> result ... (saved ...)`), exit 0.
- [ ] Skill is registered: `.opencode/skills/data-reducer/SKILL.md` appears
      in the skill index after an OpenCode restart.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Merge

> Merged to `omo-slim-changes` 2026-08-15 (serialized squash lane) as commit
> `e0d9f5f` — squash of `omos/dia-181` @ 3f0d93b onto the 49cb3de lineage
> (base 8a737a3). Files: `.opencode/skills/data-reducer/SKILL.md`,
> `scripts/data-reduce.sh`, `scripts/__tests__/data-reduce.bats`,
> `.opencode/skills/README.md` index row. README row -> CLOSED + summary
> counts in the ledger commit.

**R3 merge-gate evidence** (`docker compose ps`, before the first merge of the
lane, 2026-08-15):

- poetry-dev Up 9 hours (healthy)
- poetry-postgres Up 9 hours (healthy)

**Gate results (this lane, post-merge):**

- `make test-skills`: exit 0 — 26 passed, 0 failed, 40 pre-existing warnings;
  `data-reducer/SKILL.md` frontmatter valid per the DIA-037 validator
  (`name == dirname`, non-empty description, activation phrase present).
- `make test-config`: every validator through `validate-decision-variants`
  passes; the run aborts at `validate-grilling-gate` on a SIBLING lane's
  mid-flight edit — `DIA-085-handoff-parallel-orchestrator-sessions.md` has
  an invalid intermediate `gate_state: full-interview` in the working tree
  (parallel-handoff-slots lane, file dirty at 11:31, not touched by this
  merge; 143/144 tickets pass). The same tree state passed test-config exit 0
  in the DIA-180 run immediately prior.
- bats: 362 tests, 360 ok, 2 not-ok — the same two external failures as
  DIA-180: DIA-188 sibling invalid `opencode.json` (opencode-docker gate,
  real-tree probe) + pre-existing DIA-186 overnight TUI assertion. All 9
  `data-reduce` tests green (file/stream modes, `--` separator, empty-output
  safety, failure propagation, usage errors).
- Pre-commit hook passed (no `--no-verify`; container up).
