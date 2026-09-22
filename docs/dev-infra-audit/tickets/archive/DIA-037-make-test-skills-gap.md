# DIA-037 — make test-skills gap: no validation of SKILL.md content

<!-- Created 2026-08-03 during the skills fork+adapt campaign (arc-1). Uses the
     updated _TEMPLATE.md format including the Blocked by field. -->

---

id: DIA-037
title: "make test-skills gap — no validation of SKILL.md content"
area: opencode-config
severity: Minor
status: IMPLEMENTED
blocked_by: []
discovered:
source: test-lane
date: 2026-08-03
created: 2026-08-03
updated: 2026-08-03

---

## Description

`make test-config` validates JSONC syntax of the OpenCode config files
(`.opencode/scripts/validate-opencode-config.sh`) but performs no validation of
SKILL.md **content**. There is no test that a skill's YAML frontmatter parses,
that the required fields (`name`, `description`) are present, or that
descriptions follow the 'Use when' prefix convention (see
`.opencode/skills/writing-skills/SKILL.md`). A malformed or convention-violating
skill silently ships and degrades agent behavior without any gate firing.

Relevant as the skills catalog grows (arc-1 adds 3 new project skills, bringing
the project total to 18): content validation becomes a recurring regression
surface.

Scope note (2026-08-03, §10 Phase 6 review): also cover severity-vocabulary harmonization — \_TEMPLATE.md enum (Blocker|Critical|Major|Minor|Info) vs ledger usage of Medium (DIA-030, DIA-034); reconcile or document.

## Verification

- [ ] A test (or script) exists that parses the frontmatter of every SKILL.md under `.opencode/skills/` (and `~/.config/opencode/skills/` if in scope)
- [ ] It fails when frontmatter does not parse (missing/invalid `name` or `description`)
- [ ] It fails when a description does not start with 'Use when' (or a documented convention exception)
- [ ] It is wired into `make test-config` (or a documented equivalent gate)

## Fix

> **Partial (2026-08-03)**: severity-vocab harmonization sub-scope resolved by T3 Phase 1 — \_TEMPLATE.md enum now includes Medium, status enum now includes DEFERRED/MONITOR/IMPLEMENTED. Remaining: make test-skills gate (SKILL.md frontmatter validation script + make test-config wiring).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Implementation

Implemented 2026-08-03 via OpenSpec change test-skills-gate: make test-skills gate validates SKILL.md content (HARD: YAML/name/description/name==dir; SOFT: activation phrase + license). Verified: make test-config PASS, bats 17/17, test-shell 71/71.
