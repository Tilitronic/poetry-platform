# Gate Research: delegation-observer plugin fixes (C1/C3/H1)

Date: 2026-08-26
Source: @ai-specialist section-2.5 gate research (session ses_fc4ceafcdffeUapUVDcuWfjaN0)
Tickets: DIA-260826-pjm (datetime ID parsing), DIA-260826-jcte (force worktree removal), DIA-260826-zvu4 (verification-only SILENT_FAILURE)

## T1 pjm - datetime ticket ID parsing

Root cause: JS regex alternation is ordered; \d+ greedily matches the 6-digit date prefix of DIA-260825-aapj. 4 of 6 sites wrong (1165, 2735, 2760, 3079), 2 correct (2693, 2700).
Fix pattern: single source of truth - exported const regex pair at module top, datetime-first alternation.
Suffix is [a-z0-9]+, NOT the nominal DIA-234 {4}: ledger reality is 53 four-char
plus 2 three-char suffixes (pjm, oyh) - a {4} gate rejects its own campaign ticket.
  TICKET_ID_RE = /^DIA-(\d{6}-[a-z0-9]+|\d+)$/          (validation, full anchor)
  TICKET_ID_FIND_RE = /\bDIA-(\d{6}-[a-z0-9]+|\d+)\b/g   (free-text scan; add \b missing at :3079)
  filename variant: start-anchor only.
Replace all 6 inline literals with const refs (~30 lines). Tests: new dia-ticket-id-parser.test.mjs (sequential/datetime/edge/boundary cases) + extend dia217-ticket-gate.test.mjs with a real datetime-format ticket fixture. Risk: low.
Refs: egghead.io Zod single-source-of-truth (2024-11-15); mintlify.wiki tsgonest validation (2026).

## T2 jcte - autonomous force worktree removal

Current: apoptosis spawnSync `git worktree remove --force` (:3746-3748, :4030-4032) bypasses WORKTREES_FORCE guard, DIA-117 deny scope, and dirty-tree detection.
Fix pattern: safeRemoveWorktree() helper - (1) missing dir -> git worktree prune; (2) `git -C <path> status --porcelain --untracked-files=no` -> if dirty, warn + append apoptosis_worktree_dirty row + SKIP (developer decides); (3) clean -> remove WITHOUT --force. Never set WORKTREES_FORCE from plugin code (~50 lines). Both apoptosis sites call the helper.
Tests: extend dia220-apoptosis-paracrine.test.mjs (clean removed / dirty skipped+row / missing pruned), mock spawnSync via mock.module("node:child_process"). Risk: medium (apoptosis is last-resort; dirty trees persist by design).
Refs: @pi-stef/team cleanup.ts removeWorktreeIfEmpty (jsdelivr, 2026); worktrunk.dev/remove/ force-vs-force-delete separation (2026).

## T3 zvu4 - verification-only coder SILENT_FAILURE

Current: edits===0 && !READ_ONLY_LANES.has(coder) -> false crisis (:3843-3870).
Fix pattern (Option A, smallest diff): marker-phrase detection in dispatch text - /\b(verification.only|read.only.verif|verify.only)\b/i captured at task-dispatch time into verificationOnlySessions Set; exempt in empty-result check; clean up on completion (~20 lines). Document marker convention in orchestrator_append.md.
Tests: extend empty-result-detection.test.mjs (marker+zero-edit -> no crisis; no-marker+zero-edit -> crisis preserved; marker+edits -> no crisis). Risk: low.
Refs: arcane-bear/agent-router keyword intent classification (2026-04-19); NVIDIA AI-Q intent classifier docs (2026).

## Recommended implementation order

T1 (pjm) -> T3 (zvu4) -> T2 (jcte). T1/T3 low risk small diffs; T2 most edge cases.
