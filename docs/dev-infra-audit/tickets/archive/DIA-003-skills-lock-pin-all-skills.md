# DIA-003 — skills-lock.json contains only cli-review

---

id: DIA-003
title: "skills-lock.json contains only cli-review — pin all skills"
area: opencode-config
severity: Minor
status: CLOSED
blocked_by: []
discovered:
source: inventory
date: 2026-08-02
created: 2026-08-02
updated: 2026-08-03

---

## Description

The skills lock file (`.opencode/…/skills-lock.json`, per audit-plan m5) pins only
`cli-review`. Every other skill used by the workspace resolves unpinned, so skill
behavior can drift between installs and break reproducibility of the dev loop
(docs skills, openspec skills, playwright-browser, etc.).

## Verification

1. Locate `skills-lock.json` and inspect its contents.
2. Compare the locked set against the 15 skills listed in inventory section 8
   (`.opencode/skills/`).
3. Confirm which skills are unpinned.

## Fix

> **Deferred** — the `skills-lock.json` format only supports
> remote-github-skill entries; the vendored fork is reference-only; local skills are
> already git-pinned. See the `13fc7bd` CHANGELOG note. Revisit if/when the lock
> format grows local-skill support.

## Re-verify

> To be filled at re-verify time.

## Disposition

CLOSED 2026-08-03 (owner directive, campaign closeout). DEFERRED disposition
retained: skills-lock pinning has a format limitation (cannot pin all skills in
current format); no upstream change. Archived per archive policy.
