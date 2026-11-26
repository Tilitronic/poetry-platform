# DIA-078 — coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq)

<!-- Recurrence of the DIA-075 snip-wrapper failure class on a DIFFERENT command:
     cod-2 and cod-3 both errored looping `snip make test-config` (identical command
     + identical EXIT_CODE=0 output, 7+ repetitions, no progress) until session
     error. Filed by the docs lane (code-executor re-route) 2026-08-10. -->

<!-- UPDATE 2026-08-14 (CLOSED - 3-part mechanical fix implemented + audited;
     live restart-verify DEFERRED to a post-change session per the DIA-123
     second-boot pattern):
     CLOSURE SUMMARY: (1) PHASE 4 (2026-08-10) removed the snip guardrail
     sections from all 3 coder presets (opencode-go, cebula, free) in
     .opencode/oh-my-opencode-slim.jsonc (grep -ci 'snip' = 0 matches) - prompt
     guardrails proven structurally ineffective (3 consecutive lanes violated
     them despite explicit instructions); added MECHANICAL bash denies
     { "snip": "deny", "snip *": "deny" } to project .opencode/opencode.jsonc
     (coder L313-316, coder-escalated L337-340) and global
     ~/.config/opencode/opencode.jsonc (code-executor agent block L93-99).
     (2) PHASE 5 RESTART-VERIFY (cod-2, ses_fffe80cd3ffeQ743XPZBKIUaZH, HEAD
     7546220): coder leg LIVE-PROVEN (runtime probe bash:"snip echo..." DENIED,
     129 effective rules, both snip denies); code-executor leg FAILED first
     check (128 rules, 0 denies) - flat bash:allow in code-executor.md
     frontmatter (L10) clobbered the jsonc deny object (remeda mergeDeep
     primitive-over-object, config.ts result.agent = mergeDeep(result.agent ??
     {}, ConfigAgent.load(dir))). (3) VARIANT A FIX (cod-4,
     ses_fffd36b4dffe9rKdn0yX36VWnM; ai-specialist Phase 1 gate
     ses_fffda5947ffew04U3aIH37NkV2, Variant A confirmed with Tier-1 evidence):
     flat bash:allow removed from frontmatter L10, stale L12-14 comment replaced
     with the root-cause explanation; post-fix opencode debug agent
     code-executor = 130 rules with BOTH snip denies. Phase 6 audit (ai-auditor,
     ses_fffd1d538ffe40t2OLtybsuuFB) CONFORMANT-WITH-NOTES (4 PASS, notes 5/6/7);
     developer disposition 2026-08-14 ACCEPT ALL + CLOSE; note 7 gigaplan latent
     clobber hazard filed as DIA-154. Ticket status OPEN -> CLOSED + closed
     2026-08-14; README index row flip DEFERRED (README.md carries
     concurrent-session uncommitted hunks, DIA-153 lease - the row lands when
     that lane commits). -->

---

id: DIA-078
title: "coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty (cross-ref DIA-075 in Description)
discovered: 2026-08-10
source: fix-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-14
closed: 2026-08-14

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
evidence: ["ses_014d638bfffemyvUdhEaa4uhTq", "ses_014cf7024ffe1gvwIMsRvHb0jH", ".opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md", ".opencode/learnings/external-patterns/2026-08-14-interview-completeness-vs-batch-drop.md"]

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

FIX IMPLEMENTED (3-part mechanical, all section-10 routed; ai-specialist Phase 1 gate
ses_fffda5947ffew04U3aIH37NkV2 confirmed Variant A with Tier-1 evidence -
findings: .opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md):

1. GUARDRAIL REMOVAL (Phase 4, 2026-08-10): snip guardrail sections removed
   from all 3 coder presets (opencode-go, cebula, free) in
   .opencode/oh-my-opencode-slim.jsonc (grep -ci 'snip' = 0 matches). Prompt
   guardrails are structurally ineffective - 3 consecutive lanes violated them.
2. MECHANICAL DENY (Phase 4, 2026-08-10): bash deny rules
   { "snip": "deny", "snip \*": "deny" } in project .opencode/opencode.jsonc
   coder.permission.bash (L313-316 coder + L337-340 coder-escalated) and global
   ~/.config/opencode/opencode.jsonc code-executor agent block (L93-99).
3. VARIANT A FRONTMATTER CLOBBER FIX (cod-4, ses_fffd36b4dffe9rKdn0yX36VWnM):
   flat `bash: allow` in ~/.config/opencode/agents/code-executor.md frontmatter
   (L10) CLOBBERED the jsonc deny object - OpenCode loads .md frontmatter LAST
   (config.ts result.agent = mergeDeep(result.agent ?? {}, ConfigAgent.load(dir)))
   and remeda mergeDeep replaces an object with an incompatible primitive.
   Removed the flat allow + replaced the stale L12-14 comment with the
   root-cause explanation. Post-fix: opencode debug agent code-executor = 130
   rules with BOTH snip denies (was 128 / 0).

## Re-verify

PHASE 5 RESTART-VERIFY (cod-2, ses_fffe80cd3ffeQ743XPZBKIUaZH, HEAD 7546220):

- coder leg LIVE-PROVEN: runtime probe `bash: "snip echo..."` DENIED by the
  OpenCode permission runtime; opencode debug agent coder = 129 effective rules
  with BOTH snip denies; no snip-prefixed commands in a fresh coder lane; no
  byte-identical loop; make test-config exit 0; make test-shell exit 0 (286
  bats); 5 concurrent-session files preserved.
- code-executor leg FAILED first check: opencode debug agent code-executor =
  128 effective rules, 0 snip denies - flat `bash: allow` in code-executor.md
  frontmatter (L10) clobbered the jsonc deny object (remeda mergeDeep
  primitive-over-object replacement; .md frontmatter loads after the jsonc
  agent blocks).
- Variant A fix (cod-4, ses_fffd36b4dffe9rKdn0yX36VWnM): flat bash:allow removed
  from frontmatter L10, stale L12-14 comment replaced with the root-cause
  explanation. Post-fix: opencode debug agent code-executor = 130 rules with
  BOTH snip denies; coder 130 + coder-escalated 131 unaffected; make test-config
  exit 0.
- Phase 6 audit (ai-auditor, ses_fffd1d538ffe40t2OLtybsuuFB):
  CONFORMANT-WITH-NOTES - 4 PASS (mechanical deny, coverage, Variant A
  soundness, preset hygiene), 3 notes (5 restart-verify evidence pending, 6
  stale ticket text L97 fixed by this closure, 7 gigaplan latent hazard filed as
  DIA-154). Developer disposition 2026-08-14: ACCEPT ALL + CLOSE.

DEFERRED live restart-verify (DIA-078 follow-up): confirm runtime effect in a
POST-change OpenCode session - dispatch a fresh code-executor lane and confirm
bash:"snip X" DENIED + plain commands pass.

## Evidence — session 3 (2026-08-10) defense-in-depth landed

- Restart-verify smoke lane (cod-2, code-executor, ses_0141e70c4ffecZdbULmiVT4yt4): 6 snip-prefixed invocations despite an explicit "NEVER prefix any command with snip" instruction + 1 byte-identical re-run. Proof snip is model self-generation, not harness injection: `snip rc=$?` caused fork/exec rc=0 error; stray `snip return` in a Python heredoc caused a SyntaxError.
- Implementation lane (cod-3, code-executor, ses_0140d90e4ffeHn7mwErbAtk792): 3+ snip-prefixed invocations (snip ls, snip grep, snip echo, snip make test-config).
- Extension lane (cod-4, code-executor, ses_013f6ad3affe7wJ6dan9RcSlgx): 5 snip-prefixed invocations.
- CONCLUSION: 3 consecutive code-executor lanes violated the prompt-level guardrail despite explicit instruction → prompt guardrails are structurally ineffective; mechanical permission deny is the correct enforcement (now landed).
- Mechanism (landed 2026-08-10, §10-routed, ai--1 gate + ai--2 Phase 6 review):
  - Project: .opencode/opencode.jsonc coder.permission.bash = { "snip": "deny", "snip \*": "deny" } (L313-316 coder + L337-340 coder-escalated in the current file; the L155-159 refs from session 3 moved as the file grew).
  - Global: ~/.config/opencode/opencode.jsonc code-executor agent block, permission.bash = same pattern (JSONC parsed OK exit 0). CORRECTED 2026-08-14 (Variant A, cod-4): the original claim that frontmatter "retained bash:allow" and that the jsonc block enforces the deny was WRONG - a flat `bash: allow` string in code-executor.md frontmatter (L10) REPLACED the jsonc deny object entirely (remeda mergeDeep primitive-over-object replacement; config.ts loads .md frontmatter LAST: result.agent = mergeDeep(result.agent ?? {}, ConfigAgent.load(dir))), so the jsonc block did NOT enforce the deny (128 rules, 0 snip denies). Fixed by removing the flat bash:allow (L10) and replacing the stale L12-14 comment with the root-cause explanation; post-fix opencode debug agent code-executor = 130 rules with BOTH snip denies. Full merge semantics: .opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md.
  - Effective after OpenCode restart (developer restarts at end of session 3).
- Insight (cod-4): the "don't say snip" instruction itself primes the prefix — prompt wording that names the forbidden token can trigger it. Mechanical deny avoids this.
- Restart-verify pending: next session smoke must confirm (a) no snip-prefixed commands in a fresh docs lane, (b) no byte-identical loop, (c) `bash: "snip X"` DENIED + `bash: "X"` passes for both coder and code-executor.

## Evidence — session 4 (2026-08-10) live loop-halt efficacy + fix implemented

- cod-1 (session-4 boot lane): errored after 9+ repeated command attempts despite explicit instruction; mechanical bash deny fired each time; the loop-halt permission did NOT stop it → LIVE-EFFICACY ANSWERED: the loop-halt deny does not fire for this pattern (open question from session-3 handoff now answered).
- cod-2 (implementation lane): looped on its own loaded prompt text while editing that same text out (priming chicken-and-egg) — stopped without retry violation.
- Fix implemented (2026-08-10, §10 Phase 4): guardrail sections removed from all 3 coder presets (opencode-go L70, cebula L256, free L444); loop-halt deny added to global code-executor permission (global opencode.jsonc L98); model change was a no-op (active cebula coder already V4-flash).
- Phase 5 validation (make test-config + live probe) PENDING restart.

## Evidence - session 5 (2026-08-14) audit + closure

- ai-specialist Phase 1 gate (ses_fffda5947ffew04U3aIH37NkV2): Variant A
  (remove flat frontmatter bash:allow, let the jsonc object govern) confirmed
  with Tier-1 source evidence; findings registered in
  .opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md
  (merge semantics CONFIRMED: .md frontmatter loads last and wins for
  conflicting keys; remeda mergeDeep replaces an object with an incompatible
  primitive).
- Phase 6 audit (ai-auditor, ses_fffd1d538ffe40t2OLtybsuuFB):
  CONFORMANT-WITH-NOTES - 4 PASS (mechanical deny, coverage, Variant A
  soundness, preset hygiene), 3 notes (5 restart-verify evidence pending -
  DEFERRED live restart-verify recorded in Re-verify; 6 stale ticket text L97 -
  fixed this closure; 7 gigaplan latent clobber hazard - filed as DIA-154).
- Evidence files (this campaign):
  - .opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md
  - .opencode/learnings/external-patterns/2026-08-14-interview-completeness-vs-batch-drop.md
- The session-3 "Restart-verify pending" (L100) and session-4 "PENDING restart"
  (L107) items are RESOLVED by the Phase 5 results above (coder leg
  live-proven, code-executor leg fixed via Variant A); the remaining gap is the
  DEFERRED post-change-session live check recorded in Re-verify.
