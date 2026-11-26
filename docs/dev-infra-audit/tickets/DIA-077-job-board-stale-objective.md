# DIA-077 — OMO background job board shows stale objective for coder-lane sessions (description-reuse)

<!-- Display-layer quirk in the OMO background job board sentinel
     (src/utils/background-job-board.ts): the displayed objective is reused across
     coder-lane sessions instead of reflecting each session's actual task
     description. Attribution corrected 2026-08-10 after the ai--1 root-cause trace
     — the OMO plugin owns the defect; delegation-observer was exonerated. -->

---

id: DIA-077
title: "OMO background job board shows stale objective for coder-lane sessions (description-reuse)"
area: opencode-config
severity: Low
status: DEFERRED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: test-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-10

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_014d638bfffemyvUdhEaa4uhTq"
lane_id: "docs"
agent: "coder"
model: ""
parent_session_id: "ses_0157ee16cffegdBsSp9uGdasiy"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-077-job-board-stale-objective.md"]
artifacts: []
evidence: ["ses_0157ee16cffegdBsSp9uGdasiy"]

---

## Description

The Background Job Board sentinel shows the previous session's objective (e.g.
'Verify handoff checksum DIA-061') reused for ALL coder-lane sessions regardless of
the actual task description — a description-reuse defect in the observer's job-board
capture. Not reproducible from registry.jsonl/messages.jsonl rows alone (ai--1
2026-08-10 examined rows and saw correct per-session attribution in the JSONL; the
stale display is a job-board rendering/description-capture layer issue). Impact:
cosmetic/monitoring confusion; no functional or data impact.

## Verification

1. Dispatch 2+ coder-lane sessions with distinct objectives in one session.
2. Check the background job board sentinel — confirm whether each row shows its own
   objective or the first session's.
3. Confirm the fix shows per-session objectives.

## Fix

> DEFERRED (ai--1 §10 gate, 2026-08-10) — see "Root cause" below. Revisit on the
> OMO update cycle or if the stale display ever causes a mis-dispatch. Fix path if
> pursued: an OMO vendored-fork patch (or upstream contribution) to
> `src/utils/background-job-board.ts` — NOT a §10-routed change to
> delegation-observer.ts (that plugin is exonerated; see root cause).

## Root cause (ai--1 §10 gate, 2026-08-10)

- **Root cause is NOT the delegation-observer plugin.** `delegation-observer.ts`
  writes correct per-row `task_ref`/`objective` to `registry.jsonl`
  (L1044-1059: per-delegation `agentName`/`laneId`/`taskRef` derived from
  `input.args` — `subagent_type`, `task_id`, `description`/`prompt`).
- **The bug is in the OMO plugin Background Job Board display layer:**
  `.opencode/oh-my-opencode-slim/src/utils/background-job-board.ts`
  `registerLaunch()` L128 uses `objective: input.objective ?? existing.objective`,
  and `resolveReusable()`/`resolveRecoverable()` (L388+) can return a previous
  task ID for a new dispatch — stale-objective display reuse within a single
  OpenCode session.
- **In-memory only:** the board resets on restart; JSONL ground truth is correct;
  cosmetic/monitoring impact only.
- **Disposition: DEFERRED** — revisit on OMO update cycle or if the stale display
  ever causes a mis-dispatch. Not §10-routed for delegation-observer; an OMO
  vendored-fork patch or upstream contribution would be the fix path.

## Re-verify

> To be filled at re-verify time.
