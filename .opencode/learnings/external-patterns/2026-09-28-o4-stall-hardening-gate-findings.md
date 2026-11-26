---
title: O4 permission stall hardening gate findings (DIA-260928-nm2u)
date: 2026-09-28
ticket: DIA-260928-nm2u
source: ai-specialist gate + read-only recon (AGENTS.md 2.5 step 1, before the O4 design)
verdict: GO-with-conditions (O-B + O-D chosen)
tags: permissions, ask-stall, watchdog, plugin-sdk, unattended-runs, envelope, opencode-config
---

# O4 permission stall hardening gate findings

Section-2.5 step-1 registration of the read-only research gate plus external
recon that preceded the O4 design. Not re-derivable by other lanes: it
required live fetching of upstream docs and issue trackers on 2026-09-28.

Tier tags: **T1** = a file in this repo, **T2** = a dated external URL.

## Mechanism (T1, recon 2026-09-28)

- **[T1]** The fatal arm is the UNANSWERED 300 s window. Auto-reject at
  +300.018 s is followed 69 ms later by `session_complete` and a ~98-char
  envelope whose `<task_result>` body is EMPTY (the cod-8 death). A HUMAN
  reject at 28.2 s in the same probe series SURVIVED with text (cod-12). The
  reject decision is exonerated; the LATE automatic reject is the killer.
  Unproven hypothesis: the auto-reject lands after the session already went
  idle, so the refusal arrives too late for the model to continue.
- **[T1]** The watchdog's ONLY lever on core is the permissions endpoint
  `postSessionIdPermissionsPermissionId` with body
  `{response: "once"|"always"|"reject"}`
  (`.opencode/plugins/needs-input-observer.ts:436-439`). There is NO abort
  call anywhere in the plugin tree.
- **[T1]** The bound is project-owned, not core: env
  `PERMISSION_STALL_TIMEOUT_MINUTES`, default 300 s, single read site
  `needs-input-observer.ts:316-323`; not settable from opencode.jsonc.
  Raising it is a stopgap, not a fix.

## Runtime capability limits (T1 types + T2 upstream)

- **[T1 types, T2 upstream]** The installed plugin SDK DECLARES a hook
  `"permission.ask"` with output `{status: "ask"|"deny"|"allow"}`
  (`@opencode-ai/plugin/dist/index.d.ts` around lines 225-227), but NO
  project plugin subscribes to it, and upstream issue #7006 (open since
  2026-01-05, fix PRs still pending) records that core never triggers it.
  Migration target only.
- **[T2]** No per-tool-call abort exists (only whole-session abort). No API
  exists to inject a synthetic tool result.
- **[T2]** `--auto` does NOT cascade to child/subagent session asks (upstream
  #36868, #43888); headless/serve asks hang forever with no timeout (upstream
  #36762, #14473). This project's agent lanes are children, so auto-approve
  is not a fix here.
- **[T2]** The official docs do NOT cover the non-interactive unanswered-ask
  case; `ask` is documented as "wait for a decision from the client". Docs
  pages permissions/plugins/server/sdk/cli were current as of 2026-09-28.
- **[T2]** Precedent from another product: Claude Code's non-interactive path
  DENIES the tool call by default when no hook answers, and stopping the run
  requires an explicit opt-in flag - a non-fatal deny default is an
  established design.
- **[T1]** The stall sweep CANNOT distinguish a lane blocked on a human ask
  from a genuinely dead lane: it filters solely on dispatch_state with zero
  permission/waiting awareness, so an ask-blocked lane is stamped
  `escalation: "dead"` at ~60 minutes (false death).
- **[T1]** The invariant test is UNIMPLEMENTED: no test injects an
  outstanding ask and advances a clock past the stall bound; the closest
  existing test injects a backdated ask so a 0 ms timer fires in real time.

## Options ranked

- **O-A** config two-tier unattended permission profile (map every
  ask-capable class to allow or deny): zero code, covers only ENUMERATED
  classes.
- **O-B** run-mode-gated fast ask synthesis: resolve a pending ask within
  milliseconds of observing it (reply `once` for a narrow allow-sublist,
  else `reject`), so the fatal late window never occurs.
- **O-C** adopt the native `permission.ask` hook once upstream lands it:
  unusable today.
- **O-D** observer-side envelope guard: never emit a zero-length
  `<task_result>`; synthesize a non-empty diagnostic envelope for a
  stall-terminated lane.
- **DECISION (2026-09-28):** developer chose **O-B + O-D**, gated on
  `OPENCODE_UNATTENDED=1` exported by `scripts/overnight.sh`, with a
  single-entry allow-sublist (`rm` with exactly one non-flag target under
  `.scratch/`). Design persisted at
  `.sdd/permission-stall-hardening/architecture.md`.

## Sources

| Source | Date | Reliability note |
| --- | --- | --- |
| https://opencode.ai/docs/permissions/ | fetched 2026-09-28 | Official docs, high reliability |
| https://opencode.ai/v2/docs/permissions/ | fetched 2026-09-28 | Official docs, high reliability |
| https://opencode.ai/docs/plugins/ | fetched 2026-09-28 | Official docs, high reliability |
| https://opencode.ai/docs/server/ | fetched 2026-09-28 | Official docs, high reliability |
| https://opencode.ai/docs/sdk/ | fetched 2026-09-28 | Official docs, high reliability |
| https://opencode.ai/docs/cli/ | fetched 2026-09-28 | Official docs, high reliability |
| https://github.com/anomalyco/opencode/issues/7006 | 2026-01-05 | Dormant `permission.ask` hook; upstream tracker, high reliability |
| https://github.com/anomalyco/opencode/issues/36762 | 2026-07-13 | Headless ask hangs forever; upstream tracker, high reliability |
| https://github.com/anomalyco/opencode/issues/36868 | 2026-07-14 | `--auto` does not cover child-session asks; upstream tracker, high reliability |
| https://github.com/anomalyco/opencode/issues/43888 | 2026-08-21 | Subagent `external_directory` ask hangs; upstream tracker, high reliability |
| https://github.com/anomalyco/opencode/issues/14473 | (undated issue) | Serve-mode hang; upstream tracker, high reliability |
| https://code.claude.com/docs/en/hooks | fetched 2026-09-28 | Non-interactive deny-by-default precedent; vendor docs, high reliability |

## What would change this

- Upstream landing of the `permission.ask` hook (#7006) makes O-C viable and
  would let O-B retire its synthesis path; re-check the SDK dist types and
  the issue state before the next design pass.
- A core change that makes `--auto` cascade to child-session asks
  (#36868 / #43888) would make auto-approve a real fix here, removing the
  need for the allow-sublist.
- Core gaining a non-interactive unanswered-ask default (deny, non-fatal)
  would collapse O-B into configuration.
- Any probe series where the auto-reject at ~300 s does NOT produce an empty
  envelope would falsify the "late reject is the killer" mechanism finding
  and reopen the reject-decision question.
- Documentation of the non-interactive unanswered-ask case (currently
  absent) would supersede the "docs do not cover it" finding.

## Adjacent existing learnings

Not duplicates; read alongside this file:

- `.opencode/learnings/external-patterns/2026-09-27-permission-asks-unattended-gate.md`
  - permission merge semantics, `deny` vs `ask`, `--auto` behavior, and the
    project-owned stall bound (the earlier gate that framed ask handling).
- `.opencode/learnings/external-patterns/2026-09-27-cause-b-permission-ask-stall-gate.md`
  - CAUSE B of the coder-lane early-termination defect: the unanswered-ask
    window as killer, config ground truth, and the anchored `.scratch`
    allow-list candidates.

This file adds only what those two did not have: the late-reject/empty
envelope mechanism probe, the runtime capability limits (SDK types plus
upstream issue evidence), the O-A..O-D option ranking, and the 2026-09-28
developer decision.

## Outcome (appended 2026-09-28)

- **Outcome:** IMPLEMENTED and independently audited the same day
  (2026-09-28).
- **What landed:** fast ask resolution gated on `OPENCODE_UNATTENDED=1`
  (exported by `scripts/overnight.sh`) with a single-entry allow-sublist,
  plus the ungated O-D envelope guard; new pure lib
  `.opencode/plugins/lib/permission-fast-resolve.ts`.
- **Verification evidence:** fast-resolve suite 8 pass / 0 fail; full plugin
  suite 563 pass / 1 skip / 0 fail; `make test-config` exit 0;
  `make test-shell` exit 0 plan 1..724 with zero not-ok; eslint and prettier
  exit 0 on the changed TS files.
- **Audit:** SOUND-with-conditions; conditions 1 (typecheck evidence) and 3
  (non-interference pin) applied the same day; the two live probes remain
  OWED (does the SDK accept a reply at T~0; does core honor the
  `output.output` mutation) and the fallback path is what currently carries
  the invariant's second clause in production.
- **New finding registered:** the repo has NO typecheck target covering
  `.opencode/plugins` and missing `@types/node` makes even untouched plugin
  files fail the repo-convention per-file tsc - filed as its own ticket
  **DIA-260928-gpcc**.
- **Design record:** `.sdd/permission-stall-hardening/architecture.md`.
