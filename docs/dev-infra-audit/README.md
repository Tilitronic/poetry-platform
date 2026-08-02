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

| Status | Meaning |
|--------|---------|
| `OPEN` | Ticket accepted; work not started, or fix in progress. |
| `FIXED` | Fix implemented and committed; not yet re-verified. |
| `VERIFIED` | Fix re-verified on a clean run (gate passes; evidence recorded in the ticket's Re-verify section). |
| `CLOSED` | Verified AND no further action required (may be closed-as-won't-fix / info when explicitly accepted). |
| `BLOCKED` | Cannot proceed; dependency unmet, environment broken, or decision pending. Note the blocker in the ticket. |

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
     readiness (see DIA-015)
   - `make test-infra` (full stack smoke) — when a container run is warranted
2. **Triage** — any failure or inventory defect becomes a ticket (or updates an
   existing one). Assign severity per the ticket severity guide.
3. **Fix lane** — one ticket at a time, smallest first (Minor → Major → Critical →
   Blocker, unless a Blocker/Critical gates the rest).
4. **Re-verify** — after a fix, re-run the affected gate(s) *and* the full gate set
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

| Artifact | Content |
|----------|---------|
| `inventory.md` | Authoritative read-only recon output (verbatim). |
| `tickets/README.md` | Ledger index (ID → title / area / severity / status / file). |
| `tickets/_TEMPLATE.md` | Ticket template (fields + allowed values). |
| `tickets/DIA-*.md` | One file per ticket (initial set: DIA-001 … DIA-018). |

## Severity Guide

- **Blocker** — environment/gate cannot run at all (e.g. DIA-015); nothing else proceeds.
- **Critical** — a gate is silently skipped or a hook/config risks loss or false-green.
- **Major** — a gate is missing, misconfigured, or a real functional gap.
- **Minor** — hygiene, docs, or configuration cleanup with no gate impact.
- **Info** — observation only; close as verified when evidence is recorded.

## Current State

Seed tickets DIA-001 … DIA-018 are recorded from the inventory + baseline run.
One `BLOCKER` (DIA-015 — pnpm/Volta toolchain, environment repair) gates all JS
gates; environment repair is tracked separately.
