# DIA-092 — §10 snip-plugin-removal (opencode-snip mechanical lock fix)

<!-- Campaign c-20260809-residual-closure, session 5. Filed by the docs lane to
     unblock the s10 ticket gate (DIA-063): a conspecter dispatch was blocked
     because no correlating ticket exists for the s10 opencode-snip-removal work.
     Root cause confirmed by cod-2 audit + ai--1 s10 gate + res-1 web research.
     Status: CLOSED 2026-08-13 (ledger reconciliation, night run; all six
     section-10 phases COMPLETE - Phase 5 verify COMPLETE, validation PASSED
     2026-08-11; Phase 6 register COMPLETE). Docs-lane update
     2026-08-11: ticket rewritten
     to the IMPLEMENTED Modified Option A (council 5/5 amended the original
     ai--1 plan; see Implementation status for the empty-return incident). -->

---

id: DIA-092
title: "§10 snip-plugin-removal (opencode-snip mechanical lock fix)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # parent symptom tickets cross-referenced in Description: DIA-075, DIA-078
discovered: 2026-08-11
source: fix-lane
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0104c5761ffetqGEfqlKtd1ghp"
lane_id: "docs"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-092-snip-plugin-removal-s10.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["ai--1 §10 gate (opencode-snip mechanical-lock fix recommendation, HIGH confidence)", "cod-2 audit (snip deny-rule lock confirmation)", "res-1 web research (opencode-snip issue #7, snip wiki no-SKIP_SNIP, opencode.ai/docs/config, anomalyco#18108)"]

---

## Description

**Summary:** the global `opencode-snip@1.6.1` plugin mechanically locks ALL bash
lanes. It rewrites **every** bash command to `snip <cmd>` via a
`tool.execute.before` hook (plugin source `src/index.ts:37`), and the snip deny
rules added as the DIA-078 fix (session 3, §10-routed) now block every one of
those rewritten invocations — so no `make test-config`, no checksums, no
`git pull` work in any coder/docs lane this session. This is the root-cause
ticket for the DIA-075 (snip jq truncation) and DIA-078 (snip wrapper loop)
failure class, and it unblocks the §10 ticket gate (DIA-063) for the conspecter
dispatch that was previously blocked for lack of a correlating ticket.

**Status:** OPEN, in-progress - Phase 1 (ai-specialist gate) DONE, Phase 2
(council decision) DONE - council voted 5/5 to REJECT the original "remove as
dead config" recommendation and adopted Modified Option A (keep the four snip
deny rules as DORMANT guardrails). Phases 3-4 (design + implement) COMPLETE -
implementation landed 2026-08-11 via the cod-6 audit-first recovery lane.
Phase 5 (restart + 9-item post-restart verification checklist) COMPLETE -
validation PASSED 2026-08-11 (make test-config exit 0, bash unlocked, no snip
emissions; checklist items recorded in Verification). Phase 6 (registration)
COMPLETE - S10-P6 registered 2026-08-11 (CHANGELOG entry + learnings outcome
updated).

### Root cause (confirmed: cod-2 audit + ai--1 §10 gate + res-1 web research)

- Global plugin `opencode-snip@1.6.1` registered in
  `~/.config/opencode/opencode.jsonc:147` (plugin array).
- The plugin hooks `tool.execute.before` (plugin source `src/index.ts:37`) and
  rewrites EVERY bash command to `snip <cmd>` before execution.
- The mechanical snip deny rules from the DIA-078 fix (global
  `~/.config/opencode/opencode.jsonc` L95–96; project coder
  `.opencode/opencode.jsonc` L180–181) then DENY every rewritten invocation →
  all bash lanes lock (no make, no checksums, no git pull).
- `opencode-snip` issue #7 documents the permission-matching breakage: the
  hook-rewritten command no longer matches the permission ruleset the agent
  model sees, so the deny fires against commands the model never intended to
  run through `snip`.

### Parent tickets (symptom tickets this root-cause fix resolves)

- **DIA-075** — snip jq truncation (checksum-mismatch via `snip jq` wrapper).
- **DIA-078** — coder lane snip-wrapper identical-command loop (broader than jq).

## Verification

**9-item post-restart checklist (Phase 5, PENDING - run after OpenCode
restart):**

1. `make test-config` exits **0**.
2. `grep` shows **zero** `snip` references in plugin arrays (global
   `~/.config/opencode/opencode.jsonc` + project `.opencode/opencode.jsonc`).
3. Full OpenCode restart with **no stale process** left behind.
4. Smoke test: `bash -c "echo unlock-test"` succeeds.
5. Permitted bash commands pass; denied patterns still block.
6. An **explicit** `snip jq` invocation is still denied (guardrail intact).
7. `doom_loop` deny rule still fires on the identical-command loop class.
8. DIA-092 checklist items all recorded as pass/fail in this ticket.
9. Monitor the **first 10 bash executions** after restart for any
   `snip`-prefixed rewrite or deny surprise.

**Phase 5 RESULT (2026-08-11, PASSED):** validated live in session 6 (first
post-restart session).

1. PASS - `make test-config` exit 0.
2. PASS - `grep` shows zero `snip` references in plugin arrays (global
   `~/.config/opencode/opencode.jsonc` + project `.opencode/opencode.jsonc`);
   `opencode-snip@1.6.1` absent from the global plugin array.
3. PASS - session 6 runs post-restart; no stale process left behind.
4. PASS - `bash` unlocked; plain commands execute without rewrite.
5. PASS - permitted bash commands pass; dormant deny patterns still block
   explicit `snip` invocations.
6. PASS - explicit `snip jq` invocation still denied (guardrail intact,
   retained as DORMANT per council 5/5).
7. PASS - `doom_loop` deny rule retained (identical-command loop class).
8. PASS - this checklist recorded in the ticket.
9. PASS - no `snip`-prefixed rewrite or deny surprise in the first 10+ bash
   executions (no snip emissions in lane bash invocations this session).

Original verification plan (superseded by the 9-item checklist above, kept for
traceability):

1. Restart OpenCode (Phase 5 validation).
2. Coder lane runs plain `make test-config` -> **exit 0** (no snip-prefixed
   rewrite, no deny).
3. Checksum via `bash -c` passthrough (canonical DIA-061 form) computes and
   MATCHES the stored handoff checksum.
4. No `snip`-prefixed emissions appear in any lane's bash invocations
   (registry/messages log scan).
5. DIA-075 / DIA-078 Re-verify criteria continue to hold (no identical-command
   loop, no truncation artifact).

## Fix

> IMPLEMENTED state below is current truth (landed 2026-08-11). The original
> ai--1 plan is retained at the end of this section for traceability and is
> SUPERSEDED where it contradicts the implemented Modified Option A.

**IMPLEMENTED Modified Option A (6 changes) - council 5/5 amended the original
plan on 2026-08-11; implementation landed via the cod-6 audit-first recovery
lane (Phases 3-4 COMPLETE):**

1. **REMOVE `opencode-snip@1.6.1` from the global plugin array**
   (`~/.config/opencode/opencode.jsonc:147`) - DONE 2026-08-11. Eliminates the
   `tool.execute.before` rewrite at its source.
2. **KEEP the four snip / `snip *` deny rules** - global code-executor
   (`~/.config/opencode/opencode.jsonc` L95-96) + project coder
   (`.opencode/opencode.jsonc` L180-181), each annotated with a DORMANT
   dormancy comment. This is the council 5/5 REVERSAL of the original "remove
   as dead config" recommendation: the rules stay as a zero-cost hallucination
   guardrail (if a model ever re-invents the `snip` prefix, the deny still
   blocks it).
3. **KEEP `doom_loop:deny`** - global L98 + project L178 (still guards the
   identical-command loop class; not a snip mechanism).
4. **Reword 3 orchestrator prompts** in `oh-my-opencode-slim.jsonc`
   L26/204/393 with POSITIVE framing, never naming the forbidden token
   (e.g. 'use `bash -c` passthrough, not output-filtering wrappers'). The
   token "snip" is fully purged from that file so prompts cannot prime it.
5. **Append post-mortem corrections** to `memory/lessons.md` +
   `memory/failures.md` (snip-plugin rewrite mechanism + why prompt guardrails
   failed structurally).
6. **DEFERRED** - native `tool_output.max_lines` / `max_bytes` +
   `compaction.prune` config is NOT being added: native defaults are already
   active (`max_lines=2000` / `max_bytes=50KB`, `compaction.prune:true`
   project L20), so explicit config would be a no-op. Deferred and documented
   in memory appends instead. Revisit only if token overflow is observed.

**Original plan (SUPERSEDED) - ai--1 recommendation at filing time, amended by
the council 5/5 decision (kept for traceability; bracket notes show the
implemented-state disposition of each item):**

1. **Remove `opencode-snip@1.6.1` from the global plugin array**
   (`~/.config/opencode/opencode.jsonc:147`) - eliminates the
   `tool.execute.before` rewrite at its source. [KEPT AS-IS in the
   implemented state.]
2. **Remove the snip / `snip *` deny rules** - global
   `~/.config/opencode/opencode.jsonc` L95-96 + project coder
   `.opencode/opencode.jsonc` L180-181 (no longer needed once the plugin is
   gone; plain commands must pass). [REVERSED by council 5/5 - rules KEPT as
   DORMANT guardrails in the implemented state.]
3. **KEEP `doom_loop:deny`** - global L98 + project L178 (still guards the
   identical-command loop class; not a snip mechanism). [KEPT AS-IS in the
   implemented state.]
4. **Reword 3 orchestrator prompts** in `oh-my-opencode-slim.jsonc`
   L26/204/393: 'do not use `snip jq`' -> 'use `bash -c` passthrough, not
   output-filtering wrappers' (avoids priming the forbidden token; matches
   cod-4 insight that naming `snip` primes the prefix). [KEPT in the
   implemented state, with positive framing never naming the token.]
5. **Append correction notes** to `memory/lessons.md` + `failures.md`
   (snip-plugin rewrite mechanism + why prompt guardrails failed
   structurally). [KEPT in the implemented state as post-mortem appends.]
6. **ADD native `tool_output.max_lines` / `max_bytes` + `compaction.prune`
   config** - res-1 finding: OpenCode native truncation
   (`truncate.ts`, `max_lines=2000` / `max_bytes=50KB`) gives token economy
   WITHOUT command rewriting. [DEFERRED in the implemented state - native
   defaults already active; explicit config would be a no-op.]

## Implementation status

- **Phase 1** (ai-specialist gate): COMPLETE.
- **Phase 2** (council decision): COMPLETE - 5/5 vote for Modified Option A.
- **Phase 3** (design) + **Phase 4** (implement): COMPLETE - landed 2026-08-11
  via the cod-6 audit-first recovery lane.
- **Phase 5** (restart + 9-item post-restart verification checklist): COMPLETE -
  validation PASSED 2026-08-11 (make test-config exit 0, bash unlocked, no snip
  emissions; 9-item checklist recorded with PASS in Verification).
- **Phase 6** (registration: memory appends, changelog, learnings outcome):
  COMPLETE - S10-P6 registered 2026-08-11 (CHANGELOG entry added in
  `.opencode/CHANGELOG.md`; learnings outcome updated to validation-passed in
  `external-patterns/2026-08-10-dia078-snip-deny-gate.md`; memory appends done
  by the implementation lane 2026-08-11).

**Empty-return incident (lane note):** cod-4 and cod-5 returned empty outputs
(suspected DIA-079 non-ASCII serialization in the delegation registry); cod-6
switched to an ASCII-only protocol and succeeded, which is why this ticket's
edits and the implementation lane's reports use ASCII-only text.

## Re-verify

2026-08-13: status aligned OPEN -> CLOSED (ledger reconciliation, night run).
All six section-10 phases complete; Phase 5 post-restart verification checklist
9/9 PASS 2026-08-11; Phase 6 registration complete; plugin opencode-snip@1.6.1
removed, deny rules dormant per council 5/5. README index row was stale OPEN.

## Evidence — res-1 sources

- opencode-snip issue #7 — permission-matching breakage (hook-rewritten
  commands vs deny ruleset).
- snip wiki — `no-SKIP_SNIP` (bypass documentation).
- opencode.ai/docs/config — native `tool_output` / `compaction` config surface.
- anomalyco#18108 — upstream/related anomaly reference.
