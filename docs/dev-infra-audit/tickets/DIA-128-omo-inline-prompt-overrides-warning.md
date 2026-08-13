# DIA-128 - OMO plugin repeatedly warns "inline prompt overrides prompt file" for coder and analyzer agents

<!-- Bug ticket filed 2026-08-13 from a developer screenshot. The developer
     captured a screenshot of the OpenCode TUI and asked to "log the bug on the
     screenshot to fix". An observer agent analyzed the screenshot (evidence
     path below). This is a ticket-ledger documentation ticket ONLY - no
     config, code, agent, or skill changes were made. -->

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
