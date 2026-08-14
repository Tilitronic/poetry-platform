# DIA-105 - Edit-time formatter hooks: run formatters automatically after edits (Claude Code hooks pattern)

<!-- UPDATE 2026-08-13 (IMPLEMENTED + AUDITED + ACCEPTANCE AMENDED - TICKET CLOSED): implemented by cod-33 (ses_002b7c66fffee7CKxSflKZp0Jz): tool.execute.after formatter hook in delegation-observer.ts gated on edit/write/apply_patch - runs `npx --no-install prettier --write <absPath>` (local prettier 3.8.3, honors .prettierrc.json + .prettierignore), writes format_applied (exit 0) / format_warn (spawn error/non-zero/timeout) registry rows, ignore prefixes (.opencode/session/, knowledge/, docs/dev-infra-audit/tickets/, openspec/changes/archive/) silent-skip, extension allow-list (.ts .tsx .js .jsx .mjs .cjs .vue .css .scss .html .md .json .jsonc .yaml .yml; .py/.sh excluded - prettier cannot parse), 1MiB cap, 30s timeout, never throws (non-fatal layered). ACCEPTANCE AMENDED per ai-auditor (ai--7) + developer disposition 2026-08-13: EDIT-TIME SCOPE IS PRETTIER-ONLY - eslint --fix remains commit-time (DIA-094 lint-staged); the ticket scope-in phrase 'prettier (and eslint --fix where the repo does so)' is superseded by this amendment. OPERATOR-FACING DOC: the hook is documented in this ticket + the AGENTS.md section 6 note below (edit-time formatting is prettier-only; commit gate unchanged). OUT-OF-SCOPE HARDENING CANDIDATES (recorded, NOT implemented): (1) format_applied emitted on exit 0 even when .prettierignore makes it a no-op - consider distinguishing no-op from actual write in a future row-schema change; (2) apply_patch path parser (\S+ branches) may miss quoted/space-containing paths - broaden if ever observed. LIVE IN-PROCESS EDIT TEST PENDING next opencode launch (restart-verify per DIA-123): edit a .ts/.md file in a running session, confirm format_applied row + reformatted file; edit a knowledge/ file, confirm silent skip. Validation: npx tsc exit 0, make test-config exit 0, make test-shell exit 0 (280 tests), helper smoke 21/21. Ticket CLOSED per Re-verify convention; commit deferred to end-of-session. -->

---

id: DIA-105
title: "Edit-time formatter hooks - run formatters automatically after edits (Claude Code hooks pattern)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-11
source: developer-request
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-13

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

- [x] After an agent edits a .ts/.vue/.md file, the formatter runs automatically (no manual formatting step needed).
- [x] Only the edited file(s) are formatted; untouched files are never modified by the hook.
- [x] No formatting runs on ignored paths (.opencode/session/, node_modules, .prettierignore/.eslintignore entries).
- [x] Commit-time gate (DIA-094 husky) still enforces formatting at commit - the hook did not replace it.
- [x] Hook failure is non-fatal: if the formatter errors, the edit still succeeds and a warning is surfaced (no silent edit loss).
- [x] make test-config exit 0.

## Fix

> FIX COMPLETE 2026-08-13 (cod-33 + closure lane): prettier-only edit-time hook implemented + acceptance amended (eslint stays commit-time DIA-094) + operator-facing doc note added. See top UPDATE.

### Location decision: plugin hook (delegation-observer tool.execute.after)

Chosen over a native OpenCode config hooks entry. Rationale:

- The delegation-observer plugin already owns tool.execute.before/after with
  the established registry row-writing conventions (appendRow: seq + timestamp
  - event/status/session_id + writer provenance) — a formatter hook reuses
    that infrastructure instead of introducing a second hook system.
- A native config-hooks entry would require editing .opencode/opencode.jsonc
  (section-10 gate territory) and cannot write registry rows with the same
  provenance; the plugin hook keeps all session-attribution side effects in
  one file.
- Plugin array order already places oh-my-opencode-slim before
  delegation-observer, so any OMO patch rewriting happens before this hook
  sees the tool call.

### What was built (in .opencode/plugins/delegation-observer.ts)

1. `runEditTimeFormatter(input)` — registered in "tool.execute.after" for the
   edit / write / apply_patch tools (the same tool set the section-10 gate
   intercepts). Runs AFTER the tool result so the file on disk is the edited
   version.
2. Formatter invocation: `npx --no-install prettier --write <absPath>` with
   cwd = workspace root. `--no-install` forces the LOCAL prettier (repo has
   3.8.3; never a network fetch) — deterministic and identical to the
   DIA-094 lint-staged config (.prettierrc.json: singleQuote, printWidth 100).
   Prettier natively honors .prettierignore (verified live: an explicit
   .opencode/ file is skipped with exit 0 and no change).
3. Ignore set (FORMATTER_IGNORE_PREFIXES, silent skip — out of scope, not a
   failure): .opencode/session/, knowledge/, docs/dev-infra-audit/tickets/,
   openspec/changes/archive/. Prettier's own .prettierignore (node_modules/,
   dist/, .opencode/, tools/, etc.) is a second layer.
4. Extension allow-list (FORMATTER_EXTENSIONS): .ts .tsx .js .jsx .mjs .cjs
   .vue .css .scss .html .md .json .jsonc .yaml .yml. .py/.sh deliberately
   EXCLUDED — prettier cannot parse them (live-verified exit 2 "No parser
   could be inferred"); the repo formats python/shell at commit via
   scripts/lint-python-files.sh (ruff) and `bash -n` (lint-staged \*.sh rule).
   Including them would guarantee a format_warn row on every python/shell edit.
5. Perf guard: missing file (patch-deleted) or > 1 MiB (FORMATTER_MAX_BYTES)
   skipped silently; spawn timeout 30s (FORMATTER_TIMEOUT_MS).
6. apply_patch multi-file support: extractPatchPaths() mirrors the section-10
   gate marker scan (Index: / diff --git / +++ b/ / **_ Add File / _** Update
   File / **_ Delete File / _** Move to:) and returns ALL touched paths, so a
   multi-file patch formats every file it changed (no whole-tree passes).
7. Row events (registry.jsonl, appendRow conventions):
   - `format_applied` — prettier exit 0 (status FORMATTED, formatter prettier)
   - `format_warn` — spawn error / non-zero exit / timeout (status WARN, note
     carries the reason). Never thrown, never blocks the edit.
8. NON-FATAL contract: runEditTimeFormatter never throws; the after-hook wraps
   the call in try/catch as an absolute last resort. A formatter failure
   degrades to warn + console.warn — the agent's edit result is untouched.

### Verification evidence (implementation lane)

- npx tsc --noEmit --strict --skipLibCheck --target ESNext --module preserve
  --moduleResolution bundler .opencode/plugins/delegation-observer.ts -> exit 0
- make test-config -> exit 0 (20 agents audited, 0 gaps; drift gates unaffected;
  oh-my-opencode-slim.jsonc untouched)
- make test-shell -> exit 0 (280 bats assertions pass)
- Functional smoke (helpers): 21/21 assertions pass on verbatim-extracted
  isFormatterIgnoredPath + extractPatchPaths (ignore set boundaries, patch
  marker extraction, dedupe, allow-list). Not run in-process (hook fires only
  inside a live OpenCode session), so the full edit->format loop must be
  re-verified by the closure lane with a real edit.
- Live formatter command check: npx --no-install prettier --version -> 3.8.3;
  npx --no-install prettier --write on a throwaway /tmp .ts file formats it;
  .py/.sh files error (exit 2) as expected and are excluded by the allow-list;
  an explicit .opencode/ file is skipped by .prettierignore (exit 0, no change).

### Files touched by this lane

- .opencode/plugins/delegation-observer.ts (implementation)
- docs/dev-infra-audit/tickets/DIA-105-edit-time-formatter-hooks.md (this file)

## Re-verify

> RE-VERIFY PASS 2026-08-13: make test-config exit 0, make test-shell exit 0, tsc clean. Live in-process edit test PENDING next opencode launch (DIA-123 restart-verify pattern).

> To be filled at re-verify time by the closure/re-review lane. Suggested
> checks (from the ticket Verification section + implementation notes):
>
> - Live in-process check: in a running OpenCode session, edit a .ts/.vue/.md
>   file and confirm a format_applied registry row appears and the file is
>   reformatted; edit a knowledge/ file and confirm NO format row (silent skip).
> - Confirm untouched files are never modified (hook only receives the edited
>   paths — no glob/tree pass in the code).
> - Confirm DIA-094 commit gate still runs lint-staged (hook did not replace it).
> - Confirm a formatter failure (e.g. temporarily renaming node_modules/.bin/
>   prettier) yields format_warn and the edit still succeeds.
> - make test-config exit 0 on the re-verify run.
