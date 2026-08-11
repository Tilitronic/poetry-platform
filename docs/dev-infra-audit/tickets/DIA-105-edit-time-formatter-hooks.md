# DIA-105 - Edit-time formatter hooks: run formatters automatically after edits (Claude Code hooks pattern)

---

id: DIA-105
title: "Edit-time formatter hooks - run formatters automatically after edits (Claude Code hooks pattern)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-11
source: developer-request
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Formatting enforcement currently happens only at COMMIT time: the husky pre-commit
hook (DIA-094) runs lint-staged (prettier --write + eslint --fix) inside the dev
container, and DIA-096 forbids --no-verify. There is no EDIT-time enforcement:
when an agent edits a file, no formatter runs automatically, so formatting diffs
accumulate until commit and pollute code review with noise.

This ticket tracks implementing the Claude Code "hooks" pattern (PostToolUse:
run the project formatter immediately after an edit) as an OpenCode equivalent.
Relevant existing infrastructure:

- .opencode/plugins/delegation-observer.ts already implements tool.execute.before
  / tool.execute.after hooks - the natural home for a PostToolUse-style formatter
  hook (or a native OpenCode config hooks entry).
- Commit-time gate must REMAIN (DIA-094): the edit-time hook supplements, never
  replaces, the commit gate.
- The dev container (DIA-094 gate) must be respected: decide host vs container
  execution for the formatter.

Scope (in):

- Automatically run prettier (and eslint --fix where the repo does so) on files
  an agent edits, immediately after the edit tool returns.
- Decide and document the hook location: delegation-observer tool.execute.after
  vs native OpenCode config hooks; recommend one with rationale.
- Respect ignore rules: never format .opencode/session/, node_modules, generated
  artifacts, or files the repo's .prettierignore/.eslintignore already excludes.
- Do not reformat files the agent did not touch (no whole-tree passes).

Scope (out):

- No change to the commit-time gate (DIA-094 stays).
- No formatter config changes (prettier/eslint configs are out of scope).
- No editor/IDE integration (this is about agent edit hooks, not human editor
  save hooks).

## Investigation

- Read .opencode/plugins/delegation-observer.ts tool.execute.after implementation
  to confirm feasibility of a formatter hook there.
- Check OpenCode native hooks support in .opencode/opencode.jsonc and the
  delegation-observer plugin registration; compare plugin-hook vs config-hook
  approaches (side effects, ordering, failure handling).
- Identify the exact formatter commands the repo uses (Makefile lint-staged
  config, package.json, .prettierrc/.eslintrc) so the hook runs the SAME
  formatter config as the commit gate.
- Verify the DIA-094 docker gate interaction: can the hook run on the host, or
  must it dispatch into the dev container? Document the decision.
- Check .prettierignore/.eslintignore to define the no-format path set.

## Deliverables

- Formatter hook implementation (plugin tool.execute.after event or config hook)
  with rationale for the chosen location.
- Ignore-path handling (no-format set).
- Documentation of the hook in the relevant skill or AGENTS.md section.
- Verification evidence that the hook fires after edits and formats only the
  edited file.

## Verification

- [ ] After an agent edits a .ts/.vue/.md file, the formatter runs automatically (no manual formatting step needed).
- [ ] Only the edited file(s) are formatted; untouched files are never modified by the hook.
- [ ] No formatting runs on ignored paths (.opencode/session/, node_modules, .prettierignore/.eslintignore entries).
- [ ] Commit-time gate (DIA-094 husky) still enforces formatting at commit - the hook did not replace it.
- [ ] Hook failure is non-fatal: if the formatter errors, the edit still succeeds and a warning is surfaced (no silent edit loss).
- [ ] make test-config exit 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
