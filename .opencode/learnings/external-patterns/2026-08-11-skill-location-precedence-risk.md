# Skill-location precedence risk - global-wins bug and hybrid pin+reconcile (2026-08-11)

- **Date:** 2026-08-11
- **Source:** DIA-084 artifacts-folder-audit skill-location risk + ai-specialist deeper research (Session 11 disposition); implementation commit 49459a8 (skill-location reconcile); S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED - two-tier skill convention documented in .opencode/skills/README.md; precedence bug fixed; no name collisions remain; make test-config exit 0 (224 known WARNs).
- **Outcome note:** global-wins shadowing eliminated for every project skill; risk outside this home dir documented with mitigation (pin-at-project when load-bearing). Ticket DIA-084 CLOSED 2026-08-11.

## Ticket

- **DIA-084** (Medium, CLOSED) - "audit the artifacts folders - ensure proper order/structure, naming conventions, archive policies, index files, cross-references".
- **Related:** DIA-052 (skill dup cleanup + two-tier dup detection), DIA-088/090 (skill recovery), validate-skills.sh (frontmatter + cross-location duplicate checks).

## Root cause pattern

- **global-wins precedence bug (debugging-workflow).** When the same skill name exists in BOTH locations, the GLOBAL copy shadows the PROJECT copy. The global copy of debugging-workflow referenced disabled agents @fixer/@code_architect; the project copy references @coder. The stale global copy shadowed the project version, so the project's debugging-workflow contract never loaded. Fix: global copy deleted so the project copy loads.
- **Duplicate-name collisions elsewhere.** book-rag, git-diff, playwright-browser also existed in both tiers (global + project) - shadow risk and/or dead weight, and make test-config flags byte-exact duplicates as HARD failures.

## Fix (implemented 2026-08-11, hybrid pin + reconcile)

- **5 skills pinned at project level from the global tree:** tdd-craftsman, teaching, mermaid-diagramming, console-charting, simplify - project copies now resolve in this repo regardless of where it is cloned or run (CI/containers/other machines without this user's home).
- **4 global overlap copies deleted** (project copies already present, kept): book-rag, debugging-workflow, git-diff, playwright-browser. debugging-workflow was the precedence bug - the global copy referenced disabled agents (@fixer/@code_architect) and shadowed the project copy (@coder); deleting the global copy lets the project version load. After deletion, no project skill name exists globally -> no shadowing, no byte-exact duplicates.
- **8 global-only skills remain** (non-load-bearing, accepted): clonedeps, codemap, deepwork, oh-my-opencode-slim, reflect, release-smoke-test, verification-planning, worktrees. These are user-specific workflow tools intentionally kept global; the repo's builds/tests/agent contracts do not require them.
- **Two-tier convention documented:** .opencode/skills/README.md - which skills live where, why, resolution order, and the "one skill in exactly ONE location" rule going forward.
- **Risk outside this home dir documented:** an OpenCode runtime outside ~/.config/opencode (CI container, dev container without home mount, another machine) will NOT resolve the 8 global-only skills; mitigation = pin at project level (copy in + delete global copy) whenever a workflow makes one load-bearing.

## Outcome

- Implemented + validated: make test-config exit 0 (224 known WARNs) - validate-skills.sh confirms no cross-location duplicates; husky pre-commit ran live (no --no-verify); ASCII-only (DIA-079).
- S10-P6 registration complete 2026-08-11: CHANGELOG entry added + this learnings registration + ticket CLOSED.

## Reusable lesson

Skill resolution is GLOBAL-WINS when a name exists in both tiers - a stale global copy silently shadows the project copy (worst case: the project skill contract never loads). Never keep a same-named skill in both locations: pin project-relevant skills at project level (committed with the repo), delete the global overlap copies, and document the two-tier convention (plus the outside-this-home risk) so future audits do not rediscover the bug. make test-config (validate-skills.sh) is the gate that catches accidental reintroduction of duplicate skill names.

## Tags

DIA-084, DIA-052, DIA-088, DIA-090, skill-location, precedence, global-wins, two-tier, pin-and-reconcile, validate-skills, debugging-workflow, non-load-bearing, documentation
