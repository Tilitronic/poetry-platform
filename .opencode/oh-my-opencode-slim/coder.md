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