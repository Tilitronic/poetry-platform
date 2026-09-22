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

Why restart loops do NOT help (DIA-260920-cry5):

A restart loop for `opencode serve` (headless server) would be safe and
useful -- the server is stateless and restart restores service. However,
this project launches opencode ONLY as an interactive TUI (`make opencode`
runs `opencode` inside the Docker dev container with `-it`). A crash in
interactive mode destroys the in-memory conversation, context window, and
agent state. A restart loop would restart a fresh shell, not restore the
session. The manual session-guard practice (section 3) -- bounded chunks,
written handoffs, RSS/elapsed checkpoints -- is the correct mitigation for
interactive TUI usage. If `opencode serve` is added in the future, a
restart wrapper would become useful and should be revisited then.

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

## 4a. Version landscape (updated 2026-09-20)

Bun 1.3.14 is the runtime embedded in all opencode releases through at
least v1.18.32 (the latest available as of this writing). Upgrading
opencode does NOT upgrade Bun -- the Bun binary is bundled at build time
and has remained 1.3.14 across opencode releases.

- opencode PR #44946 attempted to bump Bun but is blocked on an upstream
  Bun 1.4.x regression (different failure mode). No merge date is known.
- No env var, flag, or `--disable-native-addons` option exists to avoid
  the crash path (napi_module_register / process_dlopen).
- The crash is non-deterministic and correlates with long sessions plus
  high subprocess-spawn count (opencode issues #40219, #40812 -- both
  OPEN as of 2026-09-20).

Bottom line: there is no Bun version upgrade path available today. The
manual session-guard practices in section 3 remain the only operational
mitigation until either (a) Bun 1.4.x stabilizes and opencode merges the
bump, or (b) Bun ships a fix for the napi crash in a 1.3.x point release.

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

## 8. Where opencode runs on Windows vs Linux (2026-09-22)

On Windows, opencode executes on the WSL host -- NEVER inside the dev
container. Only on Linux does opencode run inside the container
(make opencode / docker compose exec).

### Why this matters

The Bun crash (section 1) happens in the HOST (WSL) opencode process
for the Windows/WSL workflow. Rebuilding the container image (bun 1.4.2 /
opencode 1.18.32) does NOT change crash exposure on Windows -- the host
opencode binary embeds its own Bun version (1.3.14 as of this writing).

### How to tell which runtime you are in

- `/.dockerenv` absent + `/proc/1/cgroup` shows "0::/init.scope" =
  host/WSL session.
- `/.dockerenv` present + `/proc/1/cgroup` shows docker = container
  session.
- Container sessions are Linux-only. Host sessions can be WSL (Windows)
  or native Linux.

### Fix path

The effective fix for the Windows/WSL crash is a HOST opencode build
that embeds Bun >= 1.4.0 (waiting for the release that includes PR
#44946 + companion #48397). The container pin bump is orthogonal for
Windows users.

Do NOT claim the container rebuild mitigates the crash on Windows/WSL.
The container rebuild IS correct and useful for Linux container sessions
(make opencode workflows) but has no effect on the host-side crash.
