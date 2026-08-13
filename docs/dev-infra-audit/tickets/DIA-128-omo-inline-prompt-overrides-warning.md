# DIA-128 - OMO plugin repeatedly warns "inline prompt overrides prompt file" for coder and analyzer agents

<!-- Bug ticket filed 2026-08-13 from a developer screenshot. The developer
     captured a screenshot of the OpenCode TUI and asked to "log the bug on the
     screenshot to fix". An observer agent analyzed the screenshot (evidence
     path below). This is a ticket-ledger documentation ticket ONLY - no
     config, code, agent, or skill changes were made.

     UPDATE 2026-08-13 (FIX IMPLEMENTED, commit 15f68a4, branch
     omo-slim-changes): the dual inline `prompt` keys (coder x3 preset
     blocks, analyzer x1 root agents block) were removed from
     .opencode/oh-my-opencode-slim.jsonc and their content relocated to
     project-level prompt files .opencode/oh-my-opencode-slim/coder.md
     (new, full replacement) and analyzer_append.md (new, append file).
     make test-config exit 0 after the fix. ai-auditor APPROVE with 1
     Suggestion (dual-runtime prompt-precedence ambiguity) - ACCEPTED and
     applied as an ASCII regression note at the top of both prompt files
     (local vendored plugin FILE-wins vs npm 2.2.13 INLINE-wins split,
     dist/index.js:19282). Restart-verify PENDING next opencode launch:
     zero inline-override warnings for coder/analyzer + relocated prompts
     active. Status stays OPEN until restart-verify completes. -->

---

id: DIA-128
title: "OMO plugin repeatedly warns 'inline prompt overrides prompt file' for coder and analyzer agents"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-13
source: session-observation (developer screenshot + observer analysis, 2026-08-13)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Fix record (2026-08-13, commit 15f68a4) ---

fix_status: IMPLEMENTED
fix_commit: 15f68a4
fix_branch: omo-slim-changes
review_verdict: ai-auditor APPROVE with 1 Suggestion (dual-runtime precedence ambiguity, ACCEPTED -> regression note)
validation: make test-config exit 0
restart_verify: PENDING (next opencode launch)

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_005a18eb8ffe9m92BcMsR668Fk"
lane_id: ""
agent: "observer"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [] # no files touched - documentation-only ticket
artifacts: []
evidence: [".opencode/images/ses_005a18eb8ffe9m92BcMsR668Fk/clipboard-55d186f3.png"]

---

## Description

The OpenCode TUI, running the oh-my-opencode-slim (OMO) plugin, emits REPEATED
plugin warning messages in quick succession (4+ times), alternating between two
agents:

- `coder`
- `analyzer`

The warning text (verbatim, as shown in the screenshot):

> [oh-my-opencode] Agent 'coder': inline prompt overrides prompt file (coder.md). Remove the inline prompt to use the file.

> [oh-my-opencode] Agent 'analyzer': inline prompt overrides prompt file (analyzer.md). Remove the inline prompt to use the file.

Each agent emits the warning for its own prompt file reference:

- `coder` -> `coder.md`
- `analyzer` -> `analyzer.md`

Both agents therefore appear to have BOTH an inline prompt AND a prompt file
defined in the OMO configuration. The plugin detects the conflict and warns
that the inline prompt takes precedence over the file, i.e. the prompt file is
being ignored.

Why it matters: the repeated warning spam pollutes the TUI status/output on
every affected session, masks other messages, and indicates the agent prompt
intent is split across two locations - the effective prompt (inline) and the
intended prompt file (coder.md / analyzer.md) diverge, so documentation drift
is likely. The duplicate emission (4+ times in quick succession) is itself
suspicious and needs confirmation.

## Reproduction context

- Application: OpenCode TUI with the oh-my-opencode-slim plugin (build/plugin 1.18.18 per status bar).
- Repo: ~/Projects/poetry-platform (this repo).
- Git branch: omo-slim-changes.
- Affected agents: coder, analyzer.
- Affected files referenced by the warnings: coder.md, analyzer.md (agent prompt files).

## Evidence

- Screenshot analyzed by the observer agent:
  `.opencode/images/ses_005a18eb8ffe9m92BcMsR668Fk/clipboard-55d186f3.png`
- Session (from evidence path): ses_005a18eb8ffe9m92BcMsR668Fk.
- Bug description source: observer analysis of the above screenshot (2026-08-13).

## Open questions

- Is the warning emitted once per agent evaluation (correct) or duplicated
  unnecessarily (e.g. once per agent-instance/preset, re-emitted on every
  dispatch, or doubled by a message-transform pass)? The 4+ emissions in quick
  succession suggest duplication, but this needs confirmation during the fix.
- What exactly triggers the emission: agent dispatch, config reload, plugin
  startup, or a combination?
- Which OMO config location holds the inline prompts for coder and analyzer
  (preset blocks, per-agent overrides, or the project .opencode config)?
- Is the same inline-prompt-plus-file conflict present for OTHER agents that
  simply did not appear in this screenshot window?

## Suggested fix direction (NOT implemented - documentation only)

Both the `coder` and `analyzer` agents appear to have BOTH an inline prompt and
a prompt file in the OMO configuration. The fix will likely remove one of the
two (either drop the inline prompt so the prompt file is honored, or drop the
prompt file and keep the inline prompt - whichever matches the intent of the
current agent definitions). Before changing anything, confirm the intended
source of truth for each agent's prompt and audit whether other agents have
the same conflict.

Routing note: any actual fix touches `.opencode/` OMO config, so it must route
through the section-10 AI Devtools Modernization Workflow (gate research ->
developer decision -> design -> implement -> validate -> ai-auditor review ->
register). DIA-063 section-10 ticket gate is satisfied by this ticket. DIA-125
(automate ticket management) is unrelated but relevant background on how
tickets are created.

## Verification

How to confirm the defect exists (before fix):

- Launch OpenCode on branch omo-slim-changes with OMO plugin 1.18.18 and
  dispatch the coder and analyzer agents; observe the TUI for the repeated
  "[oh-my-opencode] Agent 'coder': inline prompt overrides prompt file
  (coder.md)..." and the analyzer equivalent.
- Grep the OMO configuration (preset + agent blocks) for inline `prompt`
  entries for coder and analyzer and confirm a coder.md / analyzer.md prompt
  file also exists - both present = conflict confirmed.
- Count emissions per dispatch to answer the duplication open question.

> To be filled at fix time with the full verification result.

## Fix

IMPLEMENTED 2026-08-13 (commit 15f68a4, branch omo-slim-changes).

- Root cause: the coder and analyzer agents had BOTH an inline `prompt`
  string in `.opencode/oh-my-opencode-slim.jsonc` AND a resolvable prompt
  file. OMO 2.2.13 emits the warning whenever both are present
  (dist/index.js:19280) because inline wins - `inlinePrompt ?? filePrompt
?? fallback` (dist/index.js:19282) - so the prompt file was being ignored.
- Fix: removed the inline `prompt` keys for coder (3 preset blocks) and
  analyzer (1 root agents block) from `.opencode/oh-my-opencode-slim.jsonc`
  and relocated the content to project-level prompt files (search-order
  step 2, project root directory):
  - `.opencode/oh-my-opencode-slim/coder.md` (new) - full replacement
    prompt (was the inline coder prompt, 13 lines).
  - `.opencode/oh-my-opencode-slim/analyzer_append.md` (new) - append file
    holding the OWNERSHIP TRACKING + COUNCIL DELEGATION sections (were part
    of the inline analyzer prompt).
- ai-auditor Suggestion (accepted): dual-runtime prompt-precedence
  ambiguity - the project runtime wires the LOCAL vendored plugin
  (`.opencode/opencode.jsonc` line 541, `file:///workspace/.opencode/
oh-my-opencode-slim`) where FILE wins, while the global runtime wires NPM
  `oh-my-opencode-slim@2.2.13` where INLINE wins. An ASCII regression note
  documenting this split was added at the top of both prompt files so
  future OMO upgrades re-verify inline-vs-file semantics before re-adding
  inline prompts.
- Verification: make test-config exit 0 (post-fix).

## Re-verify

> To be filled at re-verify time.

PENDING (2026-08-13): next opencode launch - confirm ZERO
"[oh-my-opencode] Agent '<name>': inline prompt overrides prompt file"
warnings for coder and analyzer, and the relocated prompts active (coder.md
full replacement + analyzer_append.md appended). Status stays OPEN until
this passes.
