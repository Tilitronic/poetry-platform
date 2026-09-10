# Bun crash mitigation runbook (operational)

Ticket: DIA-260831-ezyv 'bun-1-3-14-segfault-sigill-crashes-opencode-during-long-orchestrator-session'
Scope: operational response only. No code changes. No image rebuilds here.
Affected version: Bun 1.3.14 (see Version pin strategy below).

## 1. Symptom recognition

You are hitting this issue when ALL of the following hold:

- The `opencode` process dies abruptly during a long orchestrator session.
- The log shows `panic: Segmentation fault at address 0x0` followed by
  `Illegal instruction    opencode` (SIGILL after segfault).
- Bun's own crash reporter prints: "This indicates a bug in Bun, not your code."
- Context matches the known instance: Linux x64 (baseline), long-running
  orchestrator lane, high memory (reference: RSS 4.12 GB, peak 5.23 GB,
  elapsed ~3373 s). High RSS / long elapsed time is a correlator, not proof.

Not this issue when:

- The crash message names project code (a JS/TS stack trace with no Bun
  reporter text) -- treat as an app bug, follow the normal debug path.
- The crash is immediate at startup on every launch -- suspect a bad install
  or corrupt cache, not this intermittent runtime crash.

## 2. Immediate response (first 5 minutes)

1. Do NOT restart the same long session blindly. Preserve evidence first.
2. Save the terminal output (at minimum 50 lines around the panic) to a file.
3. Copy the `bun.report` crash-report URL from the output. The known instance
   URL is recorded in DIA-260831-ezyv; each new crash produces its own URL --
   capture yours.
4. Note resource context: RSS/peak/elapsed if printed, session duration,
   what the orchestrator was doing (lane, phase, in-flight dispatch).
5. Restart with a FRESH, SHORT session; resume from the last committed state
   or handoff file, not from the crashed session's in-memory context.
6. Record the occurrence in the ticket (or a follow-up note): timestamp,
   bun.report URL, RSS/elapsed, trigger context. One line per crash is enough.

## 3. Manual session-guard workaround

Until an automated guard exists, apply these manual limits to long
orchestrator sessions:

- Split long orchestrator runs into bounded chunks. Prefer several short
  sessions with written handoffs over one multi-hour session.
- Watch memory: if RSS approaches ~4 GB, stop cleanly, write a handoff,
  and restart fresh. Do not push toward the 5 GB peak seen at the crash.
- Watch elapsed time: multi-hour continuous sessions are the risk zone
  (reference crash at ~56 min elapsed under heavy load -- treat ~1 h of
  heavy orchestration as a checkpoint, not a hard limit).
- Checkpoint discipline: commit or stash worktree state and write the
  session handoff BEFORE continuing past a checkpoint.
- After a crash: resume from the last checkpoint, re-dispatch only the
  unfinished slice. Never re-run the full long session end to end.

What NOT to do:

- Do not add retry loops that relaunch the identical long session.
- Do not raise memory limits as a fix -- the fault is in the Bun runtime,
  not in a quota.
- Do not implement an automated watcher in this runbook step -- that is
  follow-up work (see ticket Verification: session-context guard decision).

## 4. Version pin strategy

Bun is pinned in TWO Dockerfiles. Both must stay in lockstep:

- `Dockerfile.dev:34` -- `ARG BUN_VERSION=1.3.14` (dev workstation image).
- `tools/opencode-docker/Dockerfile:8` -- `ARG BUN_VERSION=1.3.14`
  (opencode-docker image).

Rules:

- Do NOT bump one file without the other. A split pin means host and
  container runtimes diverge and crash reports become uncomparable.
- Do NOT bump Bun as a mitigation for this crash without an explicit
  decision recorded in DIA-260831-ezyv (newer Bun may fix it or may carry
  its own regressions -- the bump is a tracked change, not an ad-hoc edit).
- When a bump IS approved: change both ARG lines to the same version,
  rebuild both images, run `bun --version` in each rebuilt image plus the
  standard pre-commit/config gates, and record the new version in the ticket.
- Until then: 1.3.14 stays pinned. This runbook mitigates operationally
  around the pinned version.

## 5. External tracking

- Each crash emits a `bun.report` URL. That URL is the upstream artifact:
  it opens the pre-filled Bun GitHub issue form (crash report included).
  It is NOT a filed issue, only the pre-filled form input.
- Accepted state: no external Bun issue filed, per explicit developer
  no-file decision. Internal tracking is DIA-260831-ezyv. No upstream
  issue URL exists by that decision.
- Ticket Verification requires: crash report reviewed + GitHub issue filed,
  OR a recorded decision not to file. Check DIA-260831-ezyv for current
  state before filing duplicates.
- If filing: attach the bun.report URL, Bun version (1.3.14), platform
  (Linux x64 baseline), RSS/peak/elapsed, and orchestrator-session context.
  Post the issue URL back into the ticket.
- Upstream fix tracking: watch the filed Bun issue for a fixed-in version;
  only then propose a pin bump per section 4.

## 6. Prevention checklist

- [ ] Short sessions with written handoffs (section 3) as default practice.
- [ ] RSS / elapsed checkpoints observed on long orchestrator runs.
- [ ] Every crash captured with its bun.report URL and context in the ticket.
- [ ] Upstream Bun issue filed or no-file decision recorded.
- [ ] Bun pins in both Dockerfiles verified equal (`grep BUN_VERSION`).
- [ ] Session-context guard follow-up decided (separate ticket or documented
      no-go) per ticket Verification.

## 7. Escalation

- Second crash with the same signature within a short window: stop long
  orchestrator work, escalate to the orchestrator owner with both
  bun.report URLs.
- Crash at low RSS / short elapsed (outside the known profile): still
  capture and file -- it weakens the high-memory correlation hypothesis and
  matters for the upstream report.
- Any data loss on crash: prioritize recovery from last checkpoint, then
  report. Do not attempt in-place repair of the crashed session state.
