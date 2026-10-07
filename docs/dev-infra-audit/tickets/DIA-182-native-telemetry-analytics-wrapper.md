# DIA-182 - native telemetry analytics wrapper: scripts/session-analytics.sh over opencode stats/db

<!-- RENUMBERED 2026-08-14 (reconciliation, cod-7): local DIA-158 collided with origin/omo-slim-changes ticket DIA-158-hook-test-coverage-audit.md (different ticket). Renumbered to DIA-182 per developer disposition. -->

<!-- Filed 2026-08-14 from the plan session. The originally planned plugin
     telemetry (per-tool tool.execute hooks writing toolcalls.jsonl) was
     DROPPED as redundant: native OpenCode telemetry already answers the
     "which agent/tool brings value" question (verified live on 2026-08-14).
     Prior decision record: res006-telemetry-plugin-alternatives conspect +
     DIA-069/DIA-070 removed opencode-telemetry + opencode-token-monitor in
     favor of native telemetry. This ticket wraps the proven native surface in
     a small script - zero plugin code, zero section-10 change. -->

---

id: DIA-182
title: "native telemetry analytics wrapper - scripts/session-analytics.sh over opencode stats/db (per-agent cost/tokens, tool/model usage)"
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
evidence: ["knowledge/res006-telemetry-plugin-alternatives/res006-telemetry-plugin-alternatives-conspect.md"] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

The operational question "which agent/tool actually brings value" was going to
be answered with a custom plugin (per-tool `tool.execute.before/after` hooks
in delegation-observer writing a `toolcalls.jsonl`). Investigation on
2026-08-14 proved that is redundant:

- **Native `opencode stats`** (verified live): cost/tokens overview with
  `--days`, `--tools N` (tool usage counts + percentages), `--models` (per
  model breakdown), `--project` filters.
- **Native `opencode db`** (verified live): arbitrary SQL over OpenCode's own
  sqlite. The `session` table carries `cost`, `tokens_input/output/reasoning/
cache_read/cache_write`, `agent`, `model`, `parent_id` (delegation
  hierarchy). A single query returns the per-agent value table:

```
SELECT agent, COUNT(*), ROUND(SUM(cost),2), SUM(tokens_input)
FROM session WHERE parent_id IS NOT NULL GROUP BY agent ORDER BY cost DESC
```

Proven output on 2026-08-14: ai-specialist 155 sess/$11.40, coder
636/$6.77, architector 17/$6.44, openspec-plan 87/$5.67, reviewer
56/$3.35, ... (12 lanes).

- **Prior decision record:** res006 conspect concluded "Core OpenCode tooling
  (stats + DB) covers a majority of standard needs"; opencode-telemetry@0.19 +
  opencode-token-monitor were removed from config (commits 4216406/0af6b6e/
  58cddc6) after the DIA-069 portability bug and DIA-070 reentrancy-gap work.
  Building a plugin again would duplicate native capability at section-10 cost
  for no new signal.

The only thing native does not expose is per-tool-call DURATION (it exposes
counts). That is a nice-to-have, not worth a plugin.

### Scope

1. `scripts/session-analytics.sh` - thin, idempotent wrapper over the proven
   native surface with canned views:
   - per-agent value: cost + tokens + session count over subagent sessions
     (`parent_id IS NOT NULL`), sorted by cost;
   - per-model usage: `opencode stats --models` (top N, N configurable);
   - per-tool usage: `opencode stats --tools` (top N);
   - session hierarchy sanity: depth/count of subagent chains via `parent_id`.
     Guard: fails with a clear message when `opencode db`/`opencode stats` are
     unavailable (e.g. outside the OpenCode data dir) - never silently empty.
2. `scripts/__tests__/session-analytics.bats` - bats coverage wired into
   `make test-shell`; hermetic fixtures for the script's own arg/error
   handling (the opencode queries themselves are smoke-tested, not mocked).
3. Make target `make session-analytics` (mirrors `jsonl-stats` / `test-shell`
   wiring style).
4. README index row in `docs/dev-infra-audit/tickets/README.md`.

### Out of scope

- Any plugin change (delegation-observer untouched) - zero section-10 scope.
- Replacing `scripts/jsonl-stats.sh` / `scripts/session-log` - those cover the
  delegation SEMANTICS layer (registry.jsonl/messages.jsonl); this wrapper
  covers the native COST/TOKENS layer. Complementary to DIA-156 (in-memory
  SQLite query layer over the JSONL records).

## Verification

- [ ] `make test-shell` exit 0 (session-analytics.bats green).
- [ ] `make test-config` exit 0.
- [ ] Smoke against the real data dir: `bash scripts/session-analytics.sh`
      returns the per-agent cost/tokens table (matches the verified query
      shape above), exit 0.
- [ ] Guard path: running the script outside the OpenCode data dir prints a
      clear failure message, non-zero exit, no empty-success.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Merge

> Merged to `omo-slim-changes` 2026-08-15 (serialized squash lane) as commit
> `fd867d0` — squash of `omos/dia-182` @ 78ee9e7 onto the 49cb3de lineage
> (base 8a737a3). Files: `scripts/session-analytics.sh`,
> `scripts/__tests__/session-analytics.bats`, `Makefile` (header doc + .PHONY
>
> - `session-analytics` target; auto-merged cleanly with DIA-180's test-config
>   hunk — disjoint regions). README row -> CLOSED + summary counts in the
>   ledger commit.

**R3 merge-gate evidence** (`docker compose ps`, before the first merge of the
lane, 2026-08-15):

- poetry-dev Up 9 hours (healthy)
- poetry-postgres Up 9 hours (healthy)

**Gate results (this lane, post-merge):**

- `make test-config`: every validator through `validate-decision-variants`
  passes; the run aborts at `validate-grilling-gate` on the same SIBLING
  lane mid-edit as DIA-181 (DIA-085 invalid intermediate `gate_state:
full-interview` in the working tree — not touched by this merge; 143/144
  tickets pass).
- bats: 383 tests, 381 ok, 2 not-ok — the same two external failures as
  DIA-180/DIA-181 (DIA-188 sibling invalid `opencode.json` real-tree probe +
  pre-existing DIA-186 overnight TUI assertion). All 21 `session-analytics`
  tests green (arg/error handling, `--view`/`--top` validation, `--top` env
  default, `--help`, bash -n, per-view flag forwarding to `opencode stats`,
  Makefile auto-discovery wiring).
- `make test-shell` full target blocked by the DIA-188 sibling invalid-JSON
  state in the `test-opencode-docker` prerequisite (same as DIA-180/DIA-181).
- Pre-commit hook passed (no `--no-verify`; container up).
