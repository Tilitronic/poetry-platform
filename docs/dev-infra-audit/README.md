# Dev-Infra Audit — Campaign Overview

Repo: `/home/qualt/Projects/poetry-platform`
Ledger: `docs/dev-infra-audit/tickets/`

## Purpose

A **multi-loop dev-infra audit** that systematically walks every piece of developer
infrastructure in the repository, per feature:

1. **Inventory** — capture the authoritative state of the infra (see `inventory.md`).
2. **Vertical test per feature** — for each feature/component, run its automated gate(s)
   and record the result.
3. **Fix** — when a gate fails or a defect is found, fix it (via the standard
   feature/dev-infra workflow — spec → implement → test → review).
4. **Re-verify until 1 clean cycle** — repeat the verification pass until the **entire
   audit run** completes with every automated gate green and zero open
   Blocker/Critical tickets.

The audit is complete when one full pass of all gates succeeds: that is the
**"clean cycle"**.

## Status Legend

| Status     | Meaning                                                                                                    |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| `OPEN`     | Ticket accepted; work not started, or fix in progress.                                                     |
| `FIXED`    | Fix implemented and committed; not yet re-verified.                                                        |
| `VERIFIED` | Fix re-verified on a clean run (gate passes; evidence recorded in the ticket's Re-verify section).         |
| `CLOSED`   | Verified AND no further action required (may be closed-as-won't-fix / info when explicitly accepted).      |
| `BLOCKED`  | Cannot proceed; dependency unmet, environment broken, or decision pending. Note the blocker in the ticket. |

Transitions: `OPEN → FIXED → VERIFIED → CLOSED`. `BLOCKED` is a holding state; a
blocked ticket must state what unblocks it. A ticket may also go `OPEN → CLOSED`
directly when the disposition is "won't fix / no action" (must be recorded as such).

## Loop Protocol

Each loop is one complete pass over the campaign:

1. **Baseline** — run every automated gate exactly once and record raw results:
   - `make test-shell` (bats suites + bash -n + node --check)
   - `make test-python` (pytest api-server)
   - `make test-config` (opencode config validation)
   - `pnpm verify` (format / js / js-tests / python) — subject to environment
     readiness (see the archived DIA-015 ticket)
   - `make test-infra` (full stack smoke) — when a container run is warranted
2. **Triage** — any failure or inventory defect becomes a ticket (or updates an
   existing one). Assign severity per the ticket severity guide.
3. **Fix lane** — one ticket at a time, smallest first (Minor → Major → Critical →
   Blocker, unless a Blocker/Critical gates the rest).
4. **Re-verify** — after a fix, re-run the affected gate(s) _and_ the full gate set
   for the affected area. Fill the ticket's Re-verify section with evidence.
5. **Loop close** — end the loop when all gates pass with **zero open
   Blocker/Critical** tickets. Remaining Minor/Info tickets may stay open but must
   not block the clean cycle unless they represent gate failures.

## Clean Cycle Definition

A **clean cycle** is a single full audit pass in which:

- **Every automated gate passes** — `make test-shell`, `make test-python`,
  `make test-config`, `pnpm verify` (JS + Python lanes), and `make test-infra`
  all exit 0 with no skipped/failing suites (or the skip is explicitly documented
  and accepted, e.g. container-down warnings per design).
- **Zero open Blocker/Critical tickets** — every Blocker/Critical ticket is
  `VERIFIED` or `CLOSED`.

Until both conditions hold, the audit continues looping (inventory → vertical test
→ fix → re-verify).

## Campaign Artifacts

| Artifact               | Content                                                                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `inventory.md`         | Authoritative read-only recon output (verbatim).                                                                                    |
| `tickets/README.md`    | Ledger index (ID → title / area / severity / status / file).                                                                        |
| `tickets/_TEMPLATE.md` | Ticket template (fields + allowed values).                                                                                          |
| `tickets/DIA-*.md`     | One file per ticket (current set: DIA-037 … DIA-049 — 13 active; completed tickets archived in the 2026-08-03 cleanup — see below). |

## Severity Guide

- **Blocker** — environment/gate cannot run at all (e.g. a gate that cannot run because a required tool is missing); nothing else proceeds.
- **Critical** — a gate is silently skipped or a hook/config risks loss or false-green.
- **Major** — a gate is missing, misconfigured, or a real functional gap.
- **Minor** — hygiene, docs, or configuration cleanup with no gate impact.
- **Info** — observation only; close as verified when evidence is recorded.

## Current State

### Phase A — Inventory (complete)

`inventory.md` captures the authoritative recon output for every piece of dev
infrastructure.

### Phase B — Baseline vertical tests (complete)

Every automated gate run once and recorded: `make test-shell`, `make test-python`,
`make test-config`, `pnpm verify`, `make test-infra`. Failures and inventory defects
triaged into seed tickets DIA-001 … DIA-018.

### Phase C — Fix lanes (complete)

Wave-1 fix lanes closed seed-ticket defects (DIA-001 … DIA-018); wave-2 fix lanes
recorded DIA-019 … DIA-035 from their fix evidence. All 32 completed tickets were
validated post-fix and their ticket files archived in the 2026-08-03 ledger cleanup
(see [Ticket ledger cleanup](#ticket-ledger-cleanup-2026-08-03)). Zero open
Blocker/Critical tickets.

### Phase D — Full-cycle verification (complete — CLEAN)

All 12 automated gates re-run in one clean pass and reported **PASS**: `make
test-shell`, `make test-python`, `make test-config`, `make audit-python`, `pnpm
verify` (JS + Python lanes), and `make test-infra`. The two severity-gated tickets
(DIA-008 Critical and DIA-015 Blocker) were closed and validated during the fix
lanes; their fix/re-verify evidence was archived with the 2026-08-03 ledger
cleanup. The 4 tickets that remained after the initial cleanup (DIA-003 / DIA-006 /
DIA-030 / DIA-034) were CLOSED and archived 2026-08-03 by owner directive
(dispositions recorded in their archive files; see [Ticket ledger
cleanup](#ticket-ledger-cleanup-2026-08-03)). As of the 2026-08-03 cleanup, the
only active ledger row was **DIA-037** (OPEN, backlog — make test-skills gate)
— superseded 2026-08-04 by the dev-environment audit (13 active rows, see
[below](#2026-08-04-dev-environment-audit-in-progress)).

Clean-cycle criterion met: every automated gate passes and zero open
Blocker/Critical tickets (the only Blocker/Critical tickets, DIA-008 and DIA-015,
were CLOSED before their tickets were archived). See the [Clean Cycle
Definition](#clean-cycle-definition).

### Phase E — Orchestrator operating model (complete)

Config-lane change (openCode-config, §10 route): the orchestrator was made
delegation-only with path-scoped `read`/`edit` permissions, a session
messages-log + HANDOFF self-rerun protocol (`.opencode/session/`, gitignored)
was established, and `docs/dev-infra-audit/NEXT-RUN.md` was added — the
operating manual the next orchestrator instance follows to rerun the audit flow
and track the ledger (single OPEN row: DIA-037, make test-skills gap). The
DIA-036 ticket itself was validated and archived in the 2026-08-03 ledger
cleanup. DIA-003/006/030/034 were CLOSED + archived 2026-08-03 (owner
directive). Ledger (2026-08-03): **1 OPEN** (DIA-037, Minor/backlog).

### Ticket ledger cleanup (2026-08-03)

36 tickets audited 2026-08-03 → 32 completed+validated deleted (git-recoverable)
→ 4 retained (2 DEFERRED, 2 MONITOR) CLOSED + archived 2026-08-03 (owner
directive; dispositions in `tickets/archive/`) → single active row DIA-037
(OPEN, backlog); zero open Blocker/Critical (as of 2026-08-03 — superseded
2026-08-04, see below).

### 2026-08-04 dev-environment audit (in progress)

New audit loop opened 2026-08-04: **8 tickets filed** (DIA-038 … DIA-045) on
top of the DIA-037 backlog row, plus 4 tickets from the validation and E2E
phases (DIA-046 … DIA-049) — ledger now **13 active**. Gates run per the
[NEXT-RUN.md §3 flow](NEXT-RUN.md#3-audit-rerun-flow):

- **Validation phase (VALIDATE ×3 → VERIFIED)** — DIA-038 (Makefile gate
  matrix: test-config / test-shell / jsonl-stats / check-tools), DIA-039 (pnpm
  verify pipeline + pnpm audit), DIA-040 (Python gates: verify-python /
  audit-python / container pytest). Covers NEXT-RUN.md §3 items 1–5. The loop
  found 2 real gate failures — DIA-046 (prettier format) and DIA-047 (esbuild
  audit) — both now VERIFIED; **validation loop all gates green**.
- **E2E phase (E2E ×2 → complete)** — DIA-041 (Docker `make test-infra` full
  run, ~18h, ends with the stack down; NEXT-RUN.md §3 item 6) then DIA-042
  (browser Playwright flows; **blocked by DIA-041** — stack must be restored
  with `make up` first; NEXT-RUN.md §3 item 7). DIA-041 **VERIFIED** — full
  `make test-infra` PASS after the stale `pnpm_store` volume refresh (evidence
  in the ticket's Re-verify). DIA-042 browser flows: author-studio PASS
  (http://localhost:9000, HTTP 200, CM6 editor, 3/3 interactions, 0 console
  errors, 0 failed requests); publishing-platform **FAIL** —
  `ERR_CONNECTION_REFUSED` :3000 (stub app → **DIA-049**). DIA-042 stays
  E2E/open until publishing-platform has a runnable dev entry. Stack restored
  **UP** (`make up`) after the DIA-041 run.
- **OPEN backlog (OPEN ×5)** — DIA-043 (Husky hooks not CI-enforced — re-scoped
  Minor 2026-08-04 after confirming `.husky/` IS git-tracked per DIA-008
  resolution), DIA-044 (tools/opencode-docker not wired into root Makefile
  gates), DIA-045 (OpenCode config drift backlog — ai-specialist review
  findings F6–F21), DIA-048 (stale pnpm_store named volume + presence-only skip
  guard masks author-studio probe failures — Major; operational refresh done,
  probe-freshness fix pending), DIA-049 (publishing-platform is a stub — no
  runnable dev entry).

Ledger rollup (2026-08-04, 13 active): severity **Major ×1 + Medium ×7 + Minor
×5**; status **OPEN ×5 + VERIFIED ×6 + E2E ×1 + IMPLEMENTED ×1** (DIA-037). Zero
open Blocker/Critical. `VALIDATE` / `E2E` are audit-phase statuses added to the
ticket vocabulary (see `tickets/_TEMPLATE.md`); tickets transition to fix-lane
states (FIXED → VERIFIED → CLOSED) via their Fix → Re-verify sections.

**Fix-lane progress (2026-08-04):** validation loop all gates green after
DIA-046 (prettier format: `pnpm exec prettier --check` on the 5 files +
`pnpm verify:format` exit 0) and DIA-047 (esbuild advisory: `pnpm.overrides`
esbuild `>=0.28.1` added; `pnpm install` + `pnpm audit` exit 0). E2E complete:
DIA-041 (full `make test-infra`) PASS post volume-refresh and VERIFIED;
DIA-042 browser flows — author-studio PASS, publishing-platform stub FAIL →
DIA-049 (stays E2E/open). Stack restored UP (`make up`) for the browser E2E.
