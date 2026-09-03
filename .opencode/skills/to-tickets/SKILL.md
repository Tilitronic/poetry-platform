---
name: to-tickets
description: Use when a plan, spec, or the current conversation should be broken into a set of tracer-bullet tickets with declared blocking edges, published to the project's ticket ledger at docs/dev-infra-audit/tickets/.
compatibility: opencode
metadata:
  audience: developers
  workflow: task-planning
  forkedFrom: mattpocock/skills
---

<!-- Forked from mattpocock/skills (MIT License, https://github.com/mattpocock/skills). Original Copyright (c) Matt Pocock. -->
<!-- Adapted for poetry-platform: tracker hardcoded to the local-files ledger at docs/dev-infra-audit/tickets/ (DIA-NNN.md format from _TEMPLATE.md); Status uses our vocabulary (OPEN, not ready-for-agent); OpenSpec tasks.md integration added. -->

# To Tickets

Break a plan, spec, or conversation into a set of **tickets** — tracer-bullet vertical slices, each declaring the tickets that **block** it.

## Tracker

This project's tracker is **local files only**: tickets live in `docs/dev-infra-audit/tickets/` as `DIA-NNN.md` files, using the format from `_TEMPLATE.md`. There is no external issue-tracker integration.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary (see `CONTEXT.md`), and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets:

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change — rename a column, retype a shared symbol — whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify ticket — green is promised only there.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct — does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the ledger

**Use the CLI, not raw writes.** Run `scripts/tickets new` for each ticket — it allocates the next DIA number, writes the file from `_TEMPLATE.md` conventions, inserts the README index row in sort position, and recomputes the severity/status rollup counts in one bash call. Manual `write` toolcalls bypass the README row and rollup, breaking the ledger contract (DIA-229).

```bash
scripts/tickets new "<title>" --area <area> --severity <severity> [--blocked-by DIA-NNN,...] [--parent-epic DIA-NNN] [--source <src>]
```

After creating all tickets, verify the ledger is clean:
```bash
scripts/tickets rollup --check  # must exit 0
```

If you need to preview the frontier (startable tickets):
```bash
scripts/tickets frontier
```

The CLI format for each ticket file matches `_TEMPLATE.md`:

```md
# DIA-NNN — <Title>

---
id: DIA-NNN
title: "<short title>"
area: <docker | opencode-config | js-tooling | git-hooks | python-tooling | scripts | docs | secrets | env | tests-infra | ci | deps>
severity: <Blocker | Critical | Major | Medium | Minor | Info>
status: <OPEN | DEFERRED | MONITOR | FIXED | IMPLEMENTED | VERIFIED | CLOSED | BLOCKED | DISPATCHED | RUNNING | COMPLETE>
blocked_by: []  # DIA-NNN refs, or empty
discovered:
    source: <inventory | baseline | test-lane | fix-lane>
    date: YYYY-MM-DD
created: YYYY-MM-DD
updated: YYYY-MM-DD
# --- Session Attribution (v2 schema, optional) ---
session_id: ""           # OpenCode session ID that owned this ticket
lane_id: ""              # e.g. cod-1, ai--3
agent: ""                # agent name (coder, reviewer, etc.)
model: ""                # model ID used
parent_session_id: ""    # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0              # how many delegations attempted
lease_expires_at: ""     # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []        # list of file paths modified
artifacts: []            # list of artifact references (commits, test outputs)
evidence: []             # list of evidence URIs (messages.md#row, registry.jsonl#seq)
---

## Description

<What is wrong / what to build.>

## Verification

<Acceptance criteria as checkboxes — how to prove the ticket is done.>
```

- Status uses the project vocabulary: `OPEN` for new tickets. Use `DEFERRED` / `MONITOR` / `BLOCKED` when the disposition is known at creation time. `DISPATCHED` / `RUNNING` / `COMPLETE` are NOT manual values — they are set by the `delegation-observer` plugin at delegation time (DISPATCHED on task() invoke, RUNNING on child-session spawn, COMPLETE on session.idle) and should not be written by hand at ticket creation.
- **Creation-vs-Completion Field Split**: ticket creation populates only the v1 creation fields — `id`, `title`, `area`, `severity`, `status: OPEN`, `blocked_by`, `discovered`, `created`, `updated`, `Description`, `Verification`. The session-attribution fields (`session_id`, `lane_id`, `agent`, `model`, `parent_session_id`, `attempts`, `lease_expires_at`, `files_touched`, `artifacts`, `evidence`) are populated at **delegation time** by the `delegation-observer` plugin and the orchestrator — NOT at creation. Leave them at their defaults when creating a ticket.
- Severity includes Medium (harmonized 2026-08-03).
- Verification holds the acceptance criteria: the end-to-end behaviour this ticket makes work, from the user's perspective — not a layer-by-layer implementation list.
- Add a row to `docs/dev-infra-audit/tickets/README.md` and update the status/severity rollup counts.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Do NOT close or modify any parent issue.

In either form, avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## OpenSpec tasks.md integration

When the source is an OpenSpec change's `tasks.md`, map tasks → tickets 1:1 unless too large (split) or too small (merge). Preserve `tasks.md` blocking-edge annotations as `Blocked by` fields.
