# DIA-063 §10 ticket-gate non-determinism — recency-boundary flake + boot deadlock, root cause H1, tri-state fix (2026-08-10)

- **Date:** 2026-08-10
- **Source:** DIA-063 Option B fix implementation + ai--6 Phase-6 re-review cycle 1/2 (session `ses_015dabb9affeBu0yAK5OOfcAgE`, fix lane). Registered per AGENTS.md §10 ("orchestrator registers the findings"); follows `2026-08-09-dia063-ticket-creation-gate.md` (Option B recommendation) and `2026-08-07-plugin-hook-order-and-gate-gaps.md`.
- **Status:** DIA-063 RESOLVED (fix implemented 2026-08-10); DIA-076 VERIFIED + ARCHIVED (M4 complete).

## Ticket

- **DIA-063** (Blocker → RESOLVED) — "Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced."
- **DIA-075** (companion) — `snip jq` truncation caused false checksum mismatch / loop.
- **DIA-076** (Major, OPEN) — fix-implementation tracking ticket (`docs/dev-infra-audit/tickets/DIA-076-dia063-fix-implementation.md`).

## Symptom

- **Recency-boundary flake:** the SAME nominal §10 dispatch PASSED the gate, then was
  BLOCKED by it 9 minutes later — a sharp boundary cliff with no config change between
  the two dispatches.
- **Boot deadlock 3×:** boot-gate dispatches (handoff checksum verification) were
  themselves flagged as §10 work → circular deadlock on every boot attempt.

## Root cause

- **H1 (CONFIRMED):** `parseTicketDate` parsed date-only ticket frontmatter
  (`date: 2026-08-10`) as local midnight → `isRecent` becomes a sharp 24h cliff.
  Combined with path-1 requiring `isSessionOwned || isRecent` even when the dispatch
  carries an explicit OPEN DIA-id reference, long-lived valid tickets (>24h) over-fired.
- **H2 / H3 (ELIMINATED):** no permission/path mismatch and no config-hint false
  positive on the failing dispatches (confirmed via the narrowed `configWorkHint`
  regex, A3).

## Design intent

- The gate exists to prevent stale-ticket abuse (dispatching against a closed/archived
  ticket) — a failure mode NEVER observed in practice.
- The old `/DIA-\d+/` exemption regex was REMOVED in the cycle-2 rework as a direct
  bypass (any DIA-id string in the prompt would pass the gate) — the tri-state
  explicit-id check restores intent without the bypass.

## Fix

- **Tri-state path-1 (C1):** an explicit DIA-id reference resolves ONLY against OPEN
  tickets (explicit-id precedence); session-owned/recent fallback applies only to
  implicit references.
- **Boot-gate exemption (A2/M1):** dispatches matching `checksum\s+verif | handoff\s*integrit`
  (DIA-061 checksum/handoff-integrity pattern) are exempt from the §10 gate — breaks
  the boot deadlock. Bare `sha256\b` arm dropped.
- **`configWorkHint` narrowed (A3):** `/opencode\.jsonc|AGENTS\.md|skill|plugin/i` —
  the `.opencode\/` arm dropped so `.opencode/session/` transient files don't trigger.
- **Path-3 warn-not-throw (A4):** weak correlation emits `ticket_gate_weak_correlation`
  as a `console.warn`; explicit-ids-no-match remains a HARD throw.

## Companion — DIA-075 snip jq truncation + 3-layer guardrail

- **Symptom:** bare `snip jq` truncated long values (e.g., checksums) → false
  mismatch / retry loop.
- **Layers:** (1) `~/.config/snip/config.toml` `[filters.enable] jq = false`
  (user-home, NON-§10); (2) coder prompt anti-snip guardrail (forbids `snip jq` for
  hashing/integrity work + anti-loop rule); (3) orchestrator canonical checksum
  dispatch brief (mandates the canonical `bash -c` jq passthrough) — all 3 presets in
  oh-my-opencode-slim.jsonc. Probe: `scripts/test-ticket-gate.sh` wired into
  `make test-config`.

## Process lesson

- **Phase-6 independent review is @ai-auditor's lane** (not @ai-specialist) — project
  AGENTS.md §2.5/§2.4 review-matrix drift fixed (m1) so future Phase-6 audits dispatch
  the correct reviewer.
- Boot-gate dispatches MUST phrase "handoff checksum verification" so the exemption
  regex matches — a bare DIA-id or `sha256` string no longer exempts.

## Outcome

- Implemented 2026-08-10 (DIA-076 fix lane).
- `make test-config` exit 0 (18 passed / 0 failed / 33 warnings; validate-opencode-config
  ok; validate-agent-names 22 passed; validate-handoff 5 passed; probe PASS;
  tool-coverage 0 gaps); ticket-gate probe `scripts/test-ticket-gate.sh` exit 0 (6/6 PASS).
- ai--6 cycle 1/2: C1/M1/m1 verified-closed; M2 partial → evidenced in DIA-076.
- **M3 (post-restart smoke) PASSED 2026-08-10** (session `ses_0157ee16cffegdBsSp9uGdasiy`, orchestrator): C1 tri-state + B2 boot-gate exemption proven live (checksum verification dispatch via canonical `bash -c` jq passthrough ran without ticket-gate block; §10-scoped dispatch referencing long-lived OPEN DIA-071 passed). Registry seq 1770-1774; messages rows 1475-1481. Registry location confirmed: `.opencode/session/registry.jsonl` + `messages.jsonl` EXIST on disk (earlier "not found" glob was gitignore, not absence).
- **M4 (2-session durability) VERIFIED + ARCHIVED 2026-08-10:** session 2 (ses_0146a6425ffeHH6Yg3G5xpCwJM, ses_014693e89ffeftnU0Ue7JtP1ao, ses_0144a2262ffeAP7MDK0y5GeQri, ses_014475a8dffe72utMHBqLHa7Y3, ses_014422613fferxqtxtxcRPoLYY) reran boot-gate checksum verification (checksum MATCH 0d70c13c…), B2 exemption + C1 tri-state live, DIA-078 fix landed + audited conforms-with-caveats, `make test-config` exit 0 → DIA-076 → VERIFIED → archived per DIA-074.
- **Label correction 2026-08-10:** residual "await upstream PR #54 → bump version + remove interim guard" is a DIA-075 dependency, NOT DIA-069. The campaign handoff's open_tickets cited "DIA-069 (await upstream PR #54 merge)" but DIA-069 is the telemetry-plugin ticket (CLOSED, archived); the upstream-PR/interim-guard residual actually belongs to DIA-075 (snip wrapper jq-filter upstream flag, per DIA-075 Fix §10 note "flag its jq-filter behavior upstream").
- **NEW INCIDENT 2026-08-10:** coder snip-wrapper loop recurrence on `make` — cod-2 (ses_014d638bfffemyvUdhEaa4uhTq) and cod-3 (ses_014cf7024ffe1gvwIMsRvHb0jH) both errored looping `snip make test-config` (identical command + identical EXIT_CODE=0 output, 7+ repetitions, no progress) until session error → **DIA-078 created**; docs lane re-routed to code-executor. Lesson: the DIA-075 Layer-2 guardrail was scoped to `snip jq` only — guardrails must forbid snip-prefixing ANY command, not just hashing ones (snip is display-trimming only; run plain commands for anything checked: exit codes, hashes, test summaries).

## Reuse notes

- Boot-gate dispatches must phrase "handoff checksum verification" (exemption regex
  match) — never a bare DIA-id or `sha256` string.
- NEVER use bare `snip jq` for hashing/integrity work — it truncates; use the canonical
  `bash -c` jq passthrough or `printf '%s' | sha256sum` form.

## Tags

§10-gate, ticket-gate, DIA-063, DIA-075, DIA-076, non-determinism, recency-boundary, boot-deadlock, tri-state, snip-guardrail, ai-auditor
