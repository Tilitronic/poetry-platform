# DIA-130 - Duplicated OMO inline-override warnings still visible in opencode TUI (residual after DIA-128)

<!-- Follow-up ticket filed 2026-08-13 from a LIVE developer screenshot captured
     during the current session, showing the OMO 2.2.13 "inline prompt overrides
     prompt file" warnings STILL VISIBLE in the opencode TUI "Loading plugins..."
     notification area - each warning DUPLICATED (4 lines: 2x coder, 2x
     analyzer) - even though DIA-128 was flipped CLOSED (commit 2af1016) on
     log-grep evidence of zero occurrences.

     The DIA-128 close-out evidence (grep of the running process plugin log)
     does not cover the emission path that reaches the TUI. This ticket tracks
     the residual/duplicated warning symptom and the root-cause investigation
     (all config sources: project and user opencode.jsonc, project and user OMO
     configs, preset files, emission path in dist/index.js, duplication cause,
     screenshot staleness). This is a ticket-ledger documentation ticket ONLY -
     no config, code, agent, or skill changes were made. -->

---

id: DIA-130
title: "Duplicated OMO inline-override warnings still visible in opencode TUI 'Loading plugins...' area (residual after DIA-128)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # follow-up of DIA-128 (CLOSED 2026-08-13); no blockers
discovered: 2026-08-13
source: session-observation (developer live screenshot 2026-08-13, residual symptom of DIA-128)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_004adb8c8ffe5eEyKiKuVzdHcr" # session where the screenshot was captured (matches DIA-128 re-verify running-session reference)
lane_id: "coder-escalated -> base-coder" # one-shot escalated lane silently failed; base coder lane implemented the fix (see Escalation record)
agent: "coder"
model: ""
parent_session_id: ""
attempts: 2 # 1 one-shot escalation (silent failure) + 1 base coder implementation
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-130-duplicated-inline-override-warning-ui.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: [".opencode/images/ses_004adb8c8ffe5eEyKiKuVzdHcr/clipboard-16e86e93.png"]

---

## Description

The opencode TUI "Loading plugins..." notification area STILL shows the OMO
2.2.13 inline-override warnings for the `coder` and `analyzer` agents during
the current session - each warning DUPLICATED (4 lines total: 2x coder, 2x
analyzer) - despite DIA-128 being flipped CLOSED (commit 2af1016, 2026-08-13)
on log-grep evidence showing zero "inline prompt overrides prompt file"
occurrences in the running plugin log.

Verbatim warning strings (same OMO 2.2.13 emission recorded in DIA-128; the
current authoring model cannot read the screenshot directly, so the strings
below are taken from the DIA-128 verbatim record plus the live developer
report - see Evidence):

> [oh-my-opencode] Agent 'coder': inline prompt overrides prompt file (coder.md). Remove the inline prompt to use the file.

> [oh-my-opencode] Agent 'analyzer': inline prompt overrides prompt file (analyzer.md). Remove the inline prompt to use the file.

Why it matters:

- DIA-128 was closed as resolved, but the user-visible defect persists: the
  close-out verification evidence (grep of the plugin log file) does not cover
  the emission path that reaches the TUI notification surface, so the
  "zero occurrences" grep could not see the warnings even while the TUI showed
  them. The close-out evidence chain is therefore incomplete for this symptom.
- The duplicated emission (each warning fires twice) indicates the agent config
  is being processed twice (config-source merge, preset iteration, or double
  load), which is itself unresolved.
- As long as the warning fires, the effective agent prompt intent is split
  between an inline prompt and a prompt file at the emitting runtime, so the
  prompt actually used may not be the one documented - the same documentation
  drift DIA-128 was meant to eliminate.

## Evidence

1. **Live screenshot (developer, current session):**
   `.opencode/images/ses_004adb8c8ffe5eEyKiKuVzdHcr/clipboard-16e86e93.png`
   (17,175 bytes, file mtime 15:31 local, session ses_004adb8c8ffe5eEyKiKuVzdHcr
   - the same session DIA-128's re-verify cites as the running session).
     Shows the warnings in the TUI "Loading plugins..." area, each duplicated.
     NOTE: the authoring model has no image input support and could not read the
     screenshot pixels; the verbatim strings above come from the DIA-128 record
     (same plugin emission) plus the live report. Re-confirm visually at fix time.
2. **Plugin log does not capture the emission (verified 2026-08-13):**
   `grep -c "inline prompt overrides" ~/.local/share/opencode/log/oh-my-opencode-slim.20260813T133056.log` -> 0
   for the running process (PID 3530961, started 15:30:52). The warning is
   emitted to the TUI notification surface but is NOT written to the plugin log
   file - this is why the DIA-128 close-out grep showed zero while the TUI
   showed the warnings.
3. **Project-level config is clean (DIA-128 fix holds):**
   `.opencode/oh-my-opencode-slim.jsonc` contains 0 "inline prompt"
   occurrences; the 4 inline keys deleted by commit 15f68a4 (coder x3 preset
   blocks, analyzer x1 root agents block) remain gone; project prompt files
   `.opencode/oh-my-opencode-slim/coder.md` (2039 bytes) and
   `analyzer_append.md` (2530 bytes) exist.
4. **USER-LEVEL config still dirty (prime suspect, verified 2026-08-13):**
   `~/.config/opencode/oh-my-opencode-slim.jsonc` STILL contains inline
   `"prompt"` keys for the same agents the DIA-128 fix cleaned at project
   level:
   - `coder`: inline prompt in TWO preset blocks (lines 77, 197).
   - `analyzer`: inline prompt in the root agents block (line 411).
     And user-level prompt files exist alongside:
     `~/.config/opencode/oh-my-opencode-slim/coder.md` (2356 bytes) and
     `~/.config/opencode/oh-my-opencode-slim/analyzer.md` (8593 bytes) - the
     exact inline-plus-file conflict DIA-128 removed only from the PROJECT
     config. The user-level config was never touched by the DIA-128 fix.
5. **Dual runtime confirmed live (matches DIA-128 regression note):**
   - Global runtime: `~/.config/opencode/opencode.jsonc` line 148 wires npm
     `oh-my-opencode-slim@2.2.13`; per DIA-128 the npm runtime implements
     INLINE wins (`inlinePrompt ?? filePrompt ?? fallback`, dist/index.js:19282)
     with the warning gated on BOTH being defined (dist/index.js:19280). The
     npm runtime resolves the user-level config which still has inline prompts.
   - Project runtime: `.opencode/opencode.jsonc` line 541 wires the local
     vendored plugin `file:///workspace/.opencode/oh-my-opencode-slim`; FILE
     wins. The project config is clean, so this runtime alone would not warn.

## Relation to DIA-128

- DIA-128 root cause: `coder` and `analyzer` each had BOTH an inline `prompt`
  and a resolvable prompt file in the PROJECT config
  `.opencode/oh-my-opencode-slim.jsonc`; OMO 2.2.13 warns whenever both exist
  because inline wins and the file is ignored.
- DIA-128 fix (commit 15f68a4, + 144a332 regression note): deleted the 4
  inline `prompt` keys from the project config and relocated the content to
  project prompt files `coder.md` and `analyzer_append.md`.
- DIA-130 finding: the fix is INCOMPLETE for the user-visible symptom. (a) The
  same inline-plus-file conflict still exists at the USER level
  (`~/.config/opencode/oh-my-opencode-slim.jsonc` + user-level `coder.md` /
  `analyzer.md`), which the fix never touched and which the npm 2.2.13 runtime
  resolves with inline precedence - so the warning can still fire. (b) The
  DIA-128 close-out verification (log grep) does not cover the TUI emission
  path, so zero log hits was never proof the TUI was clean. (c) The
  duplication (2x per agent) was left unexplained.
- Status relationship: DIA-128 CLOSED does not resolve DIA-130; DIA-130 tracks
  the residual/duplicated symptom until a fix removes the warning from the TUI
  (visual re-verify) and the duplication cause is understood.

## Escalation record (2026-08-13)

1. **Escalated lane dispatched ONE-SHOT and silently failed.**
   - Lane: `coder-escalated` (kimi-k3), session `ses_004a15d0fffetpy1ShtsYHP78G`.
   - Dispatched at 13:45:11Z on 2026-08-13 with the full DIA-130 fix brief.
   - Read the 5 relevant config files (user jsonc, user coder.md, user
     analyzer.md, project jsonc, project prompt files) but wrote NOTHING.
   - Returned an EMPTY result (silent failure) at 13:54:44Z - no edits, no
     report, no error payload.
2. **State-inspection lane verified the window is clean.**
   - Lane: `cod-6`, session `ses_00497cabdffeSH8NnucCp2dqLB`.
   - Zero files modified during the escalation window (13:45:11Z-13:54:44Z).
   - User-level config `~/.config/opencode/oh-my-opencode-slim.jsonc` in exact
     pre-fix state: 3 inline `"prompt"` keys at lines 77/197/411, file valid
     (28199 bytes, closes with `}`).
   - User-level prompt files intact: `coder.md` (2356 bytes / 56 lines),
     `analyzer.md` (8593 bytes / 267 lines).
   - No backup files created; repo HEAD unchanged at `b6c400d`.
3. **ONE-SHOT no-retry rule observed** (kimi-k3 has a 490/month cap; a retry
   was not warranted). Developer approved the fallback to the base `@coder`
   lane on 2026-08-13 ("Ticket the failure + fix").
4. **This lane (base coder) implements the fix** - the DIA-128 precedent
   pattern applied at the USER level: relocate the 3 inline prompt contents
   verbatim into the user-level prompt files, delete the 3 inline `"prompt"`
   keys, add DIA-130 regression note comments.

## Open questions (root cause TBD by investigation)

- H1 - Config source: the npm 2.2.13 runtime resolves the user-level config
  `~/.config/opencode/oh-my-opencode-slim.jsonc` which still holds inline
  prompts for coder (lines 77, 197) and analyzer (line 411) alongside the
  user-level prompt files. Verify by checking which config the running process
  actually resolved (OMO startup/debug output), then confirming the warning
  disappears when the user-level inline prompts are removed/relocated.
- H2 - Emission path: warnings reach the TUI notification area at plugin-load
  time but are not written to `~/.local/share/opencode/log/oh-my-opencode-slim.*.log`
  (verified 0 hits while the TUI showed them). Verify by capturing the opencode
  process stdout/stderr or the TUI notification stream during plugin load.
- H3 - Duplication cause: each warning fires twice. Candidates: (a) project +
  user config merge double-processing, (b) preset iteration - coder has inline
  prompts in 2 user-level preset blocks, (c) double load (native opencode.jsonc
  - OMO, or project + user level). Verify by isolating each config source and
    counting emissions per source.
- H4 - Screenshot staleness: unlikely - the screenshot mtime (15:31 local) is
  AFTER the last config commit 144a332 (15:02:25) and inside the running
  process window (PID 3530961, 15:30:52). Confirm against the live TUI on the
  next launch.

## Suggested fix direction (NOT implemented - documentation only)

- Follow the DIA-128 precedent at the USER level: remove the inline `"prompt"`
  keys for coder (2 preset blocks, lines 77 and 197) and analyzer (1 root
  agents block, line 411) from `~/.config/opencode/oh-my-opencode-slim.jsonc`,
  keeping the user-level prompt files (`coder.md`, `analyzer.md`) as the source
  of truth - OR unify on a single config source so the conflict cannot recur.
- Determine and fix the duplication (H3) once the emission path is confirmed.
- Re-verify MUST include a TUI-visible check (screenshot or notification-area
  capture), not only a log grep - the DIA-128 close-out gap.
- Routing note: any fix touches `.opencode/` and/or user-level OMO config, so
  it must route through the section-10 AI Devtools Modernization Workflow (gate
  research -> developer decision -> design -> implement -> validate ->
  ai-auditor review -> register). DIA-063 section-10 ticket gate is satisfied
  by this ticket. DIA-128 is the immediate predecessor; DIA-125 (automate
  ticket management) is unrelated background.

## Verification

How to confirm the defect exists (before fix):

1. Launch opencode on branch omo-slim-changes and watch the "Loading
   plugins..." notification area during startup; count occurrences of the
   coder/analyzer inline-override warnings (currently expected: 4 lines - 2x
   coder, 2x analyzer - per the live screenshot).
2. Grep the user-level OMO config for inline prompts:
   `grep -n '"prompt"' ~/.config/opencode/oh-my-opencode-slim.jsonc`
   (coder lines 77, 197; analyzer line 411 present as of 2026-08-13).
3. Confirm which config the running process resolved (OMO startup/debug output
   or process env) - project config, user config, or a merge.
4. Count emissions per config source to characterize the duplication (H3).

How to prove the fix:

5. After removing the user-level inline prompts (or unifying config sources),
   relaunch opencode and confirm ZERO inline-override warnings in the TUI
   "Loading plugins..." notification area - a VISUAL check (screenshot or
   notification capture), not just zero hits in the plugin log.

> To be filled at fix time with the full verification result.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
