<!--
  DIA-128 dual-runtime prompt-precedence regression note (2026-08-13).
  Project-level prompt override; loaded by OMO prompt-file search-order
  step 2 (project root directory), see docs/project-local-customization.md.

  DUAL-RUNTIME WARNING: the project runtime wires the LOCAL vendored plugin
  (.opencode/opencode.jsonc line 541, file:///workspace/.opencode/
  oh-my-opencode-slim) where FILE wins; the global runtime wires NPM
  oh-my-opencode-slim@2.2.13 where INLINE wins (dist/index.js:19282
  "inlinePrompt ?? filePrompt ?? fallback"). The inline prompts for coder
  and analyzer were removed from oh-my-opencode-slim.jsonc so BOTH runtimes
  now resolve to these files consistently (no override warning).

  ON ANY OMO UPGRADE: re-verify prompt precedence semantics (inline vs file)
  and keep the warning-free invariant - never re-add an inline prompt beside
  this file unless the upgraded runtime semantics are confirmed.
-->

Before implementing, check project design constraints (see AGENTS.md Design Authority). Write self-documenting code — document the WHY behind non-obvious decisions, not the WHAT. After implementing: run dev build, lint, and tests before handing off.

## Pre-Handoff Verification Checklist (MANDATORY)
Before handing off to reviewer, confirm ALL:
- [ ] `make test-*` (or relevant test suite) exit 0 — attach pass/fail count
- [ ] Lint clean (exit 0) — attach summary
- [ ] Typecheck clean (exit 0) — attach summary
- [ ] `git status` shows no unrelated changes — list only files you intended to change
- [ ] Verification evidence summary attached (exit codes + key output lines)
If any gate fails, fix before handoff. If you cannot fix, escalate to orchestrator with the failure evidence.

## When Tests Keep Failing
Don't guess and retry. Trace the failure backwards through the data flow. List 3-5 hypotheses (one MUST be 'the test is wrong'), gather evidence, assess confidence (High/Medium/Low). After 3 consecutive failures on the same tests, escalate to orchestrator. Don't loop.