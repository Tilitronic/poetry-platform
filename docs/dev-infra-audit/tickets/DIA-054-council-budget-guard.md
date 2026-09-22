# DIA-054 — NEXT-RUN.md §2 council budget guard (COUNCIL-BUDGET-GUARD)

<!-- Task T3 of openspec/changes/ai-self-improvement-auditor-and-cleanup (validated,
     openspec validate exit 0, 2026-08-06). DOC-ONLY ticket — 0 code changes.
     THIS TICKET DOES NOT IMPLEMENT; it encodes the spec + acceptance. -->

---

id: DIA-054
title: "NEXT-RUN.md §2 council budget guard (COUNCIL-BUDGET-GUARD)"
area: docs
severity: Medium
status: DONE
blocked_by: []
discovered: 2026-08-06
source: inventory
date: 2026-08-06
created: 2026-08-06
updated: 2026-08-06

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Summary:** add a `COUNCIL-BUDGET-GUARD` bullet to
`docs/dev-infra-audit/NEXT-RUN.md` §2 (Orchestrator Operating Rules) capturing
the council-dispatch credit budget rule + thresholds (base 1500 / warn 75% =
1125 / hard-stop 90% = 1350) and the `token_stats` detection mechanism. Non-code
deliverable; no automated test (visual review + grep).

**Insertion point (per design.md §4):** immediately after the existing
`CRISIS-DETECTION` bullet and BEFORE `PROGNOSIS-DISCIPLINE` — the surrounding
bullets must remain intact and well-formed.

**Exact text (per design.md §4):**

> **COUNCIL-BUDGET-GUARD**: the orchestrator MUST monitor cumulative
> council-dispatch credit spend against a 1500-credit session budget. **Warn**
> at 75% (1125 credits): emit a visible notice to the developer with the current
> spend + remaining budget; continue dispatching. **Hard-stop** at 90% (1350
> credits): cease all council dispatches for the remainder of the session;
> notify the developer; hand off remaining council-needs to the next session via
> the HANDOFF.md prognosis. Detection: `token_stats` + the council-dispatch
> subset of the spend; credit cost per councillor dispatch is model-dependent
> (use the live `token_stats` cost field, not a static lookup).

**Semantics (design.md §4):** the 1500 base is a session budget, not a
per-dispatch cap; the warn threshold is informational (dispatch continues); the
hard-stop is a dispatch freeze. Detection reuses the existing `token_stats`
call pattern from the SELF-RERUN rule. Council itself is confined to C1–C5
crisis states per the owner-approved plan (findings ai--1 D6).

**Scope guard:** doc-only — no code files change. If implementation touches
anything beyond `NEXT-RUN.md`, that is scope creep and must be flagged.

**Routing:** AGENTS.md §2.4 (dev-infra docs) → implement via @coder, review by
@reviewer (two-axis).

## Verification

1. `grep -c 'COUNCIL-BUDGET-GUARD' docs/dev-infra-audit/NEXT-RUN.md` — returns `1`.
2. `grep -c '1500' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥ 1 (base budget).
3. `grep -c '1125' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥ 1 (75% warn threshold).
4. `grep -c '1350' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥ 1 (90% hard-stop threshold).
5. Visual: bullet present in §2, insertion point correct (CRISIS-DETECTION
   before, PROGNOSIS-DISCIPLINE after), surrounding bullets intact.
6. Doc-only guard: `git status --porcelain` shows ONLY `NEXT-RUN.md` (and this
   ticket's own lane files) — 0 code changes.

## Fix

**Fix (2026-08-06, campaign T3 — ledger row 487):** cod-9 implemented doc-only:
`docs/dev-infra-audit/NEXT-RUN.md` §2 — `COUNCIL-BUDGET-GUARD` bullet inserted between
CRISIS-DETECTION and PROGNOSIS-DISCIPLINE (8 insertions, §2 continuation style), exact
design.md §4 wording: 1500-credit session budget; **Warn** 75% (1125) — visible notice +
continue; **Hard-stop** 90% (1350) — cease council dispatches + notify + hand off via
HANDOFF.md prognosis; detection = `token_stats` council-dispatch subset (model-dependent
cost). Grep acceptance DIA-054 1-4 all met (COUNCIL-BUDGET-GUARD=1, 1500=1, 1125=1,
1350=1); make test-config exit 0; doc-only guard respected (0 code changes).

## Re-verify

**Re-verify (2026-08-06 — ledger row 488):** rev-3 two-axis review — **PASS / PASS,
0 findings** (verbatim comparison vs design.md §4 identical modulo list marker + §2
wrap; Standards 0, Spec 0; thresholds arithmetically correct; no scope creep).
Ticket flipped **OPEN → DONE** (2026-08-06) per owner authorization (G1 gate row 503 +
certification path row 509).
