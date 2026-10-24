# DIA-075 — DIA-061 boot-gate checksum-mismatch via `snip jq` wrapper + recurring coder snip-jq loop

<!-- Incident 2026-08-09: the c-20260809-residual-closure campaign closed with handoff
     checksum 060baeb4… (verified self-consistent at write time, cod-18, messages.jsonl
     row 1392, 18:11:09Z). On the next boot the batch-approval boot gate escalated
     checksum-mismatch (messages.jsonl row 1398, 18:47:43Z): the checksum verification
     lane had computed 0025ca8f… via `snip jq` instead of the canonical `bash -c` jq
     passthrough. The gate refused to resume; the developer chose investigation-first
     (row 1399, 18:49:27Z). THIS LANE is that investigation: root cause + ticket.

     UPDATE 2026-08-13 (INDEPENDENT VERIFICATION + CLOSED): the root cause was
     structurally eliminated by DIA-092 (opencode-snip@1.6.1 plugin removal,
     CLOSED 2026-08-13). The global plugin rewrote EVERY bash command to
     `snip <cmd>` via a tool.execute.before hook - with the plugin removed
     from the global plugin array (~/.config/opencode/opencode.jsonc "plugin":
     dcp, envsitter-guard, openspec, oh-my-opencode-slim only - no
     opencode-snip), the wrapper no longer intercepts any lane invocation, so
     the jq-output truncation class cannot fire. DIA-092 Phase 5 post-restart
     checklist 9/9 PASS (2026-08-11): make test-config exit 0, bash unlocked,
     zero snip references in plugin arrays, no snip-prefixed emissions;
     DIA-092 Phase 6 registration complete. Repo scan this lane: zero `snip`
     wrapper/alias/function in scripts/, .opencode/scripts/, .opencode/plugins/
     (grep exit 1 - no matches; only historical docs, CHANGELOG, learnings, and
     the DORMANT deny rules retained per council 5/5). Current boot-gate
     checksum flow uses the delegated coder lane per DIA-093 (lane-0 coder
     delegation post-batch-approval, canonical `bash -c` jq passthrough,
     plugin atomic-write handoff with computed checksum - no snip jq wrapper
     anywhere). Stored checksum proven intact (canonical 060baeb4... MATCH in
     the original investigation). Ticket flipped CLOSED 2026-08-13 per
     Re-verify convention. -->

---

id: DIA-075
title: "DIA-061 boot-gate checksum-mismatch via snip jq wrapper + recurring coder snip-jq loop"
area: docs
severity: Major
status: CLOSED
blocked_by: []
discovered: 2026-08-09
source: test-lane
date: 2026-08-09
created: 2026-08-09
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_018238137ffeVaB0ANfJ0zpQkZ"
lane_id: "cod-19"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: "ses_018466e00ffezjqhlNtip6ppmx"
attempts: 1
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-075-checksum-mismatch-snip-jq-loop.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["messages.jsonl#row1392 (write-time checksum 060baeb4… self-consistent)", "messages.jsonl#row1398 (boot-gate checksum-mismatch escalation 18:47:43Z)", "messages.jsonl#row1399 (investigation-first-deferred 18:49:27Z)", "registry.jsonl#seq1686-1689 (checksum lane ses_01845796cffeLLYVZag0H8UGzf FAILED)", "messages.jsonl#row1340 (cod-6 snip-wrapper loop crisis)", "messages.jsonl#row1339 (cod-7 bash -c passthrough recovery)"]

---

## Description

**Summary:** the DIA-061 batch-approval boot gate verifies the handoff checksum by
re-computing sha256 over the canonical serialization of `prognosis` (DIA-061 canonical —
`jq -c '.prognosis | to_entries | sort_by(.key) | from_entries'` piped through
`tr -d '\n' | sha256sum`). On 2026-08-09 the verification lane ran the computation through
the **`snip` command wrapper** (`snip jq -c '<filter>' <file>`) instead of the canonical
`bash -c "jq ..."` passthrough, producing a **deterministic wrong checksum
`0025ca8f3f43b8e255dc0d158234b1c54dbe3f1991b8d19a89d2cc133587a97f`** — repeated
identically ~12 times — vs the stored **`060baeb43d4e7def17c97853b573fcc02a63003a5dbc8573b9956f148d37e379`**.
The gate escalated checksum-mismatch and refused to resume; the developer chose
investigation-first. The same `snip`-wrapper failure previously caused the **cod-6
snip-wrapper loop** earlier the same day (crisis row 1340), recovered by re-dispatch as
cod-7 using the `bash -c` passthrough.

### Incident timeline (2026-08-09)

| Time (Z) | Event                                                                              | Ref                     |
| -------- | ---------------------------------------------------------------------------------- | ----------------------- |
| 18:11:09 | Handoff final state written (cod-18); DIA-061 checksum `060baeb4…` self-consistent | messages.jsonl row 1392 |
| 18:13:08 | Checksum-verification lane spawned — `ses_01845796cffeLLYVZag0H8UGzf`              | registry seq 1686       |
| 18:46:53 | Lane FAILED (session error) — ~34 min, snip jq loop                                | registry seq 1687       |
| 18:47:43 | Boot gate escalated **checksum-mismatch** (ticket DIA-061)                         | messages.jsonl row 1398 |
| 18:49:27 | Developer decision: **investigation-first-deferred**                               | messages.jsonl row 1399 |
| 18:50:15 | Investigation lane dispatched — `ses_018238137ffeVaB0ANfJ0zpQkZ` (this lane)       | registry seq 1690       |

### Canonical verification (this investigation, Step 1)

The canonical command — `bash -c "jq -c '.prognosis | to_entries | sort_by(.key) |
from_entries' .opencode/session/current-handoff.json" | tr -d '\n' | sha256sum` —
produces **`060baeb43d4e7def17c97853b573fcc02a63003a5dbc8573b9956f148d37e379`**,
which **MATCHES** the stored `checksum` field in `current-handoff.json`
(`060baeb43d4e7def17c97853b573fcc02a63003a5dbc8573b9956f148d37e379`).

**Conclusion: the handoff file is intact — the mismatch was purely the snip-wrapper
artifact.** The `snip jq` invocation is the only path that yields `0025ca8f…`.

Git evidence: `.opencode/session/` is gitignored (repo `.gitignore` lines 78-79,
"Orchestrator session state (transient, regenerated per session)"); `git ls-files
.opencode/session/` is empty → `current-handoff.json` is NOT tracked/committed, so git
provides no post-write modification evidence. Working tree porcelain is clean. The
handoff is a transient runtime artifact written and verified at cycle close.

## Root cause — the `snip` wrapper jq truncation quirk

### What `snip` is

`snip` is a command-output filter wrapper: `snip v0.23.0 — CLI Token Killer`
(`/home/qualt/.opencode/bin/snip`, a 10 MB statically-linked stripped ELF binary).
It wraps shell commands and applies **built-in output filters** to trim verbose output
for token economy. It is wired into the OpenCode plugin stack as
`opencode-snip@1.6.1` (`~/.config/opencode/opencode.jsonc` line 134). Filter set:
`snip verify` reports 132 built-in filters; `snip check -- jq ...` confirms
`filter: jq` — jq is a built-in filter target.

### The mangling mechanism

When a command is invoked **through the wrapper** as
`snip jq -c '<filter>' <file>`, snip recognizes jq as a filterable command and
**truncates the jq output** (deterministic truncation with a trailing `…` elision) to
keep token counts low. It does **not** mangle the filter argument itself — it mangles
the _output_, which is what gets hashed.

Empirically verified (this investigation):

| Invocation                                                                        | Output size   | sha256                   |
| --------------------------------------------------------------------------------- | ------------- | ------------------------ |
| `bash -c "jq -c '<filter>' current-handoff.json"` (canonical passthrough)         | 4985 bytes    | `060baeb4…` ✅ stored    |
| `snip jq -c '<filter>' current-handoff.json` (wrapped)                            | **121 bytes** | `0025ca8f…` ❌           |
| `snip jq -c '<filter>' /tmp/opencode/snip-demo.json` (tiny input, 10-byte output) | unchanged     | identical to passthrough |

The truncated 121-byte output begins `{"fixes_applied":"Commits (branch
further-dev-infrastructure-development): d16f1d9 (DIA-070 ledger row CLOSED), 203cf…`
— i.e. the correct sorted first key, then a hard truncation with `…`. Small outputs
(below the truncation threshold) pass through unchanged, which is why the demo file
hashed identically through both paths. **Any jq output above the threshold is
deterministically truncated → a deterministic but wrong checksum**, reproduced
identically every run (hence the ~12× identical `0025ca8f…`).

### Why `bash -c` is the safe canonical path

`bash` is not a snip filter target: invoking
`snip bash -c "jq ..."` (or plain `bash -c "jq ..."` outside the wrapper) emits
`snip: no filter for "bash", passing through` and runs jq un-truncated. This is exactly
the recovery that worked for cod-7.

### Source/line-number caveat

`snip` is a **stripped ELF binary** — no source, no line numbers available. Searched for
a definition/alias/function: `~/.bashrc`, `~/.zshrc`, `~/.profile`, `~/.config`
(binary/config references only), `~/.opencode/bin/snip` (the binary), `snip config`
(filters dir `~/.config/snip/filters` is empty → filters are built-in), glob `**/*snip*`
(repo: none), `find /` for `*.filter*` (timed out; not re-run). The mechanism is
documented here from black-box observation: built-in jq filter with output truncation.

## Recurring coder loop — registry evidence

Same failure class recurs because coder lanes keep invoking jq through the `snip`
wrapper. Evidence from `messages.jsonl` / `registry.jsonl` (2026-08-09 session,
orchestrator `ses_01a6deadbffetuzYeV7Ziepxtk`):

**cod-6 snip-wrapper loop → cod-7 recovery (earlier same day):**

- messages.jsonl row 1333 (09:42:02Z): `ses_01a37febcffejMof0S7NTJeh6U` — "session error — delegation failed", `escalated`
- messages.jsonl row 1340 (09:45:03Z): crisis — `"cod-6 ses_01a37febcffejMof0S7NTJeh6U error — snip-wrapper loop, cancelled, re-dispatched as cod-7"`, `cleared`
- messages.jsonl row 1338 (09:44:55Z): cod-7 `ses_01a18ab74ffezlZU5wAvVgqCU2` in-flight; row 1339 (09:45:02Z): cod-7 done — "Fix 498, commit plugin, cleanup (retry)" landed via bash -c passthrough (8ceef31)

**Today's cancelled checksum-verification lane:**

- registry seq 1686 (18:13:08Z): spawn `ses_01845796cffeLLYVZag0H8UGzf`, parent `ses_018466e00ffezjqhlNtip6ppmx`, `RUNNING`
- registry seq 1687 (18:46:53Z): `FAILED` — "session error — delegation failed" (messages row 1396)
- registry seq 1688–1689: backward-transition anomaly + COMPLETE — the ~34-minute lane produced no successful checksum and was cancelled
- messages row 1398 (18:47:43Z): boot gate `checksum-mismatch` escalation

**Loop pattern:** the coder re-runs the identical `snip jq ... | tr -d '\n' | sha256sum`
command instead of progressing; each run deterministically returns the same wrong
`0025ca8f…`; the lane spins until session-error/cancel, and the boot gate stays red until
the developer intervenes. The correct value was available all along via `bash -c`
passthrough (proven by cod-7 and by this investigation).

## Impact

- **Boot-gate friction:** every cycle close + reboot pair is a DIA-061 checksum gate;
  any verification lane that uses `snip jq` deterministically fails the gate.
- **Lost lane time:** the cancelled checksum lane burned ~34 minutes (18:13:08 →
  18:46:53) re-running the identical failing command.
- **Resume delay:** the gate refused to resume until developer chose
  investigation-first (18:47:43 → 18:49:27 + investigation).
- **No integrity compromise:** canonical verification MATCHES the stored checksum —
  the handoff file is intact. The mismatch was a computation artifact, not tampering.
- **Recurrence risk:** this is the second occurrence in one day (cod-6 then the
  boot-gate lane); without a guardrail it will recur on every future boot gate.

## Verification

1. **Canonical checksum MATCHES stored (PASSED — this investigation):**
   `bash -c "jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' .opencode/session/current-handoff.json" | tr -d '\n' | sha256sum`
   → `060baeb43d4e7def17c97853b573fcc02a03063a5dbc8573b9956f148d37e379` == stored `checksum` field.
2. **Reproduce the artifact:** `snip jq -c '<same filter>' .opencode/session/current-handoff.json | tr -d '\n' | sha256sum`
   → `0025ca8f3f43b8e255dc0d158234b1c54dbe3f1991b8d19a89d2cc133587a97f` (deterministic; repeatable).
3. **Truncation proof:** wrapped jq output is 121 bytes vs 4985 bytes canonical (see Root cause table).
4. **Git scope:** `git ls-files .opencode/session/` empty (gitignored); working tree porcelain clean.
5. **Post-fix:** boot gate passes with no developer intervention when the verification lane
   uses `bash -c` passthrough (or snip is removed from the jq path); no identical-command
   repetition observed in 2+ consecutive cycles.

## Fix

> IMPLEMENTED - root cause structurally eliminated by DIA-092 (CLOSED
> 2026-08-13); independent closure verification 2026-08-13 (see UPDATE block
>
> - Re-verify).

**Implemented fix (DIA-092, Modified Option A, council 5/5):** remove the
`opencode-snip@1.6.1` plugin from the global plugin array
(`~/.config/opencode/opencode.jsonc` - its `tool.execute.before` hook rewrote
every bash command to `snip <cmd>`, which is what put jq invocations through
the truncating wrapper). With the plugin gone, NO lane invocation passes
through `snip` - the jq truncation class (and the broader identical-command
loop class, DIA-078) cannot fire. Retained as DORMANT zero-cost guardrails per
council 5/5: the `{"snip": "deny", "snip *": "deny"}` permission rules
(project `.opencode/opencode.jsonc` coder L180-181 / global L95-96) and
`doom_loop: deny` - they never need to fire live but block any model that
re-invents the prefix.

**Original remediation recommendations (evaluated during fix design):**

- **(a) snip wrapper:** fix or remove snip's jq output-truncation handling, or exclude
  jq (and any command whose output is hashed) from the filter set; document
  `bash -c "jq ..."` passthrough as the canonical invocation for checksum work.
  Because snip is a third-party binary with built-in filters, the safest immediate fix
  is a prompt/guardrail (b) rather than patching the binary. -> **Superseded by the
  structural DIA-092 plugin removal (the wrapper is no longer in the command path).**
- **(b) Coder prompt guardrail:** forbid `snip` for jq and any JSON query; forbid
  identical-command repetition (anti-loop rule: "if the output is byte-identical to the
  previous run and you have no new step, STOP and escalate"). Encode both in the coder
  agent prompt and/or orchestrator dispatch brief. -> **Implemented as interim defense
  (DIA-076 Layer-2/Layer-3 + DIA-078 hardening), retained post-removal.**
- **(c) DIA-061 canonical serialization:** already documented in the boot-gate rules
  (handoff `resume_instructions` step 1 references the canonical `bash -c` form and the
  "snip-wrapper jq quirk — bash -c passthrough" note). Extend the boot-gate rule to
  mechanically reject/flag any checksum-verification command that routes through `snip`.
  -> **Superseded: the DIA-093 fix delegates checksum verification to a lane-0 coder
  using the canonical `bash -c` passthrough (NEXT-RUN.md 7.3 step 7); the plugin
  atomic-write handoff computes/stores the checksum itself (DIA-120 clarification).**

**S10 routing note:** the DIA-092 fix touches `.opencode/` config -> it was routed
through S10 (ai-specialist gate -> council 5/5 -> coder -> ai-auditor Phase-6 review),
Phase 5 validated 2026-08-11 (9/9 checklist), Phase 6 registered. The snip binary
itself is outside the repo (tooling dependency); its upstream jq-filter behavior was
flagged in DIA-092 (res-1 research, opencode-snip issue #7).

## Re-verify

> COMPLETE - closed per re-verify convention 2026-08-13.

1. **Boot gate passes with zero developer intervention using the canonical `bash -c` jq
   passthrough.** -> **PASSED:** DIA-076 M3/M4 (2026-08-10) boot-gate checksum
   verification dispatches ran WITHOUT gate block and WITHOUT intervention;
   computed == stored via canonical passthrough (`6163028d...` M3, `0d70c13c...`
   M4 session 2). DIA-092 Phase 5 (2026-08-11): bash unlocked, no snip
   emissions; 9/9 checklist PASS.
2. **No `snip jq` invocation in the checksum lane; no identical-command loop in 2+
   consecutive cycles.** -> **PASSED:** DIA-092 Phase 5 monitoring (first 10+ bash
   executions post-restart, zero snip-prefixed rewrites) + this lane's repo scan
   (zero `snip` wrapper/alias/function in scripts/, .opencode/scripts/,
   .opencode/plugins/). The opencode-snip plugin that mechanically rewrote
   commands is removed - the `snip` prefix is now DORMANT-deny blocked.
3. **Stored checksum continues to match canonical computation (`060baeb4...` for the
   2026-08-09 handoff).** -> **PASSED:** original investigation proved the stored
   checksum intact (canonical MATCH); the mismatch was purely the wrapper
   artifact. Current flow: plugin atomic-write handoff computes/stores the
   checksum itself (DIA-120); lane-0 coder re-verifies via `bash -c`
   passthrough (DIA-093). -> **CLOSED.**
