# DIA-093 orchestrator boot no-bash deadlock - lane-0 coder checksum delegation (A+E+F) (2026-08-11)

- **Date:** 2026-08-11
- **Source:** Campaign c-20260809-residual-closure session 6 - developer directive + analyzer root-cause analysis (5-Whys); fixes A+E+F implemented by coder lane; S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED + VALIDATED - `make test-config` exit 0; ai-auditor conditional-pass resolved; follow-ups F-1/F-2/F-4 closed. Restart PENDING (config live next boot).
- **Outcome note:** boot gate now delegates the DIA-061 checksum to a lane-0 coder post-approval (no waiver menu); exit protocol mandates a coder-computed checksum (never null); stale direct-bash mandate purged from 3 OMO presets + orchestrator_append.md.

## Ticket

- **DIA-093** (Major, OPEN) - "Orchestrator boot: 'I have no bash tool' - DIA-061 checksum not delegated to coder lane".
- **Related:** DIA-091 (no-bash recurring symptom), DIA-061 (handoff checksum stays null), DIA-075 (checksum-mismatch class), DIA-063 (batch-approval boot gate / ticket-creation gate).

## Root cause pattern (5-Whys)

- **bash-denied orchestrator** - opencode.jsonc:74 bash deny (orchestrator has no bash tool by design).
- **+ prompt text mandating bash** - stale orchestrator prompts still demanded a direct bash checksum pipeline.
- **+ gate forbidding pre-approval delegation** - orchestrator_append.md:221 forbids delegation before approval.
- **= boot deadlock** - the mandatory DIA-061 checksum step could never run: the orchestrator cannot compute it and cannot delegate it; exit gap wrote `checksum: null` (NEXT-RUN.md 7.2) with no delegated compute path.

## Fix (implemented 2026-08-11, fixes A+E+F)

- **FIX A (boot gate):** orchestrator_append.md + NEXT-RUN.md 7.3 - missing/invalid checksum no longer blocks presentation; lane-0 coder delegation computes the DIA-061 checksum immediately after batch approval (no waiver menu).
- **FIX E (exit protocol):** orchestrator_append.md + NEXT-RUN.md 7.2 - a coder lane computes the checksum before the handoff write; `checksum: null` only on crisis/crash exits, with resume_instructions flagging the lane-0 requirement.
- **FIX F (stale prompt removal):** 3 orchestrator prompts (opencode-go / cebula / free presets in .opencode/oh-my-opencode-slim.jsonc) - stale checksum-pipeline text replaced with delegated DIA-061 wording.

## Outcome

- Implemented + validated: `make test-config` exit 0; ai-auditor conditional-pass resolved; follow-ups F-1/F-2/F-4 closed (2026-08-11).
- S10-P6 registration complete 2026-08-11: CHANGELOG entry added + this learnings registration.

## Reusable lesson

Any privileged/mechanical step the orchestrator cannot run itself must have an explicit delegation path in the boot/exit protocol, not a waiver menu. A waiver only defers the deadlock to the next session; a lane-0 delegation post-approval resolves it permanently. Exit protocols must never write a null value for a mandatory field - delegate the computation to a lane that can run it.

## Tags

DIA-093, DIA-061, DIA-091, DIA-063, checksum-delegation, boot-deadlock, no-bash, orchestrator, lane-0, exit-protocol, waiver-vs-delegate
