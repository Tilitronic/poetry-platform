# DIA-XXX — <Title>

<!-- Copy this template to a new file `DIA-<NNN>.md` and replace placeholders.
     Keep the YAML frontmatter block intact. -->

---

id: DIA-XXX
title: "<short title>"
area: <docker | opencode-config | js-tooling | git-hooks | python-tooling | scripts | docs | secrets | env | tests-infra | ci | deps>
severity: <Blocker | Critical | Major | Medium | Minor | Info>
status: <OPEN | DEFERRED | MONITOR | FIXED | IMPLEMENTED | VERIFIED | CLOSED | BLOCKED>
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: <inventory | baseline | test-lane | fix-lane>
date: YYYY-MM-DD
created: YYYY-MM-DD
updated: YYYY-MM-DD

---

## Description

<What is wrong. Reference exact files and line refs where known. Why it matters
(impact on gates, clean-cycle, or daily dev loop).>

## Verification

<How to test the defect exists / how to prove the fix. Concrete commands, gates
to run, files to inspect.>

## Fix

<What changed — fill at fix time. Leave blank with this note until then.>

> To be filled at fix time.

## Re-verify

<Result of re-running Verification after the fix — fill at re-verify time.
Must include the actual gate output/exit code that proves VERIFIED.>

> To be filled at re-verify time.
