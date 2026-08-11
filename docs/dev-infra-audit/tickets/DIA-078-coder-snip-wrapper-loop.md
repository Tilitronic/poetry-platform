# DIA-078 — coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq)

<!-- Recurrence of the DIA-075 snip-wrapper failure class on a DIFFERENT command:
     cod-2 and cod-3 both errored looping `snip make test-config` (identical command
     + identical EXIT_CODE=0 output, 7+ repetitions, no progress) until session
     error. Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-078
title: "coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty (cross-ref DIA-075 in Description)
discovered: 2026-08-10
source: fix-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-10

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_014b72222ffe8GU87ux7tj65Xd"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: "ses_0157ee16cffegdBsSp9uGdasiy"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-078-coder-snip-wrapper-loop.md"]
artifacts: []
evidence: ["ses_014d638bfffemyvUdhEaa4uhTq", "ses_014cf7024ffe1gvwIMsRvHb0jH"]

---

## Description

DIA-075 documented the snip-wrapper jq truncation + the coder identical-command loop,
with a Layer-2 guardrail forbidding `snip jq` for hashing/integrity work. On
2026-08-10 the coder lane repeated the failure class on a DIFFERENT command: cod-2
(ses_014d638bfffemyvUdhEaa4uhTq) and cod-3 (ses_014cf7024ffe1gvwIMsRvHb0jH) both
errored looping `snip make test-config` — identical command + identical EXIT_CODE=0
output, 7+ repetitions, no progress — until session error. The `snip` wrapper itself
is NOT the truncation problem for `make` (it passes through: "no filter for make,
passing through") — the loop is the model's habit of prefixing commands with `snip`
and then re-running the identical command instead of progressing.

Root cause hypothesis: the DIA-075 Layer-2 guardrail was scoped to `snip jq`
(hashing/integrity), so it did not catch `snip make`; the anti-loop rule ("if output
is byte-identical to previous run and no new step, STOP and escalate") was either not
present in the active coder prompt or not strong enough.

Impact: repeated failed coder dispatches (2 in one session), lane-time loss,
verification friction; DIA-075's own Re-verify criteria ("no identical-command loop
in 2+ consecutive cycles") are at risk.

## Verification

1. Reproduce: dispatch coder with a docs task requiring `make test-config`; observe
   whether it prefixes `snip` and loops.
2. Post-fix: coder completes the task in one pass with plain commands (no `snip`
   prefix, no identical-command repetition).
3. DIA-075 Re-verify continues to hold (no loop in 2+ consecutive cycles).

## Fix

Fix direction (developer-directed 2026-08-10): "configure snip better / teach agents
to bypass snip in such situations" —

(a) strengthen the coder (and code-executor) prompt guardrail: forbid prefixing ANY
command with `snip` (snip is only for interactive display trimming; for command
execution and any output that is checked (exit codes, hashes, test summaries) run
plain commands);
(b) harden the anti-loop rule: if a command's output is byte-identical to the previous
run AND no new step was taken, STOP and escalate (do not re-run);
(c) consider `~/.config/snip/config.toml` filter-bypass env/alias so
`snip make`/`snip bash` are no-ops or auto-stripped.

§10-routed if touching .opencode/ prompts/config; snip config.toml is user-home
(non-§10).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Evidence — session 3 (2026-08-10) defense-in-depth landed

- Restart-verify smoke lane (cod-2, code-executor, ses_0141e70c4ffecZdbULmiVT4yt4): 6 snip-prefixed invocations despite an explicit "NEVER prefix any command with snip" instruction + 1 byte-identical re-run. Proof snip is model self-generation, not harness injection: `snip rc=$?` caused fork/exec rc=0 error; stray `snip return` in a Python heredoc caused a SyntaxError.
- Implementation lane (cod-3, code-executor, ses_0140d90e4ffeHn7mwErbAtk792): 3+ snip-prefixed invocations (snip ls, snip grep, snip echo, snip make test-config).
- Extension lane (cod-4, code-executor, ses_013f6ad3affe7wJ6dan9RcSlgx): 5 snip-prefixed invocations.
- CONCLUSION: 3 consecutive code-executor lanes violated the prompt-level guardrail despite explicit instruction → prompt guardrails are structurally ineffective; mechanical permission deny is the correct enforcement (now landed).
- Mechanism (landed 2026-08-10, §10-routed, ai--1 gate + ai--2 Phase 6 review):
  - Project: .opencode/opencode.jsonc coder.permission.bash = { "snip": "deny", "snip \*": "deny" } (L155-159).
  - Global: ~/.config/opencode/opencode.jsonc code-executor agent block, permission.bash = same pattern (JSONC parsed OK exit 0); code-executor.md frontmatter retained bash:allow + comment pointing to the jsonc block (frontmatter supports flat tool→action only).
  - Effective after OpenCode restart (developer restarts at end of session 3).
- Insight (cod-4): the "don't say snip" instruction itself primes the prefix — prompt wording that names the forbidden token can trigger it. Mechanical deny avoids this.
- Restart-verify pending: next session smoke must confirm (a) no snip-prefixed commands in a fresh docs lane, (b) no byte-identical loop, (c) `bash: "snip X"` DENIED + `bash: "X"` passes for both coder and code-executor.

## Evidence — session 4 (2026-08-10) live loop-halt efficacy + fix implemented

- cod-1 (session-4 boot lane): errored after 9+ repeated command attempts despite explicit instruction; mechanical bash deny fired each time; the loop-halt permission did NOT stop it → LIVE-EFFICACY ANSWERED: the loop-halt deny does not fire for this pattern (open question from session-3 handoff now answered).
- cod-2 (implementation lane): looped on its own loaded prompt text while editing that same text out (priming chicken-and-egg) — stopped without retry violation.
- Fix implemented (2026-08-10, §10 Phase 4): guardrail sections removed from all 3 coder presets (opencode-go L70, cebula L256, free L444); loop-halt deny added to global code-executor permission (global opencode.jsonc L98); model change was a no-op (active cebula coder already V4-flash).
- Phase 5 validation (make test-config + live probe) PENDING restart.
