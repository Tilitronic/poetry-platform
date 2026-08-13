# DIA-127 - OMO slim 2.2.13 update evaluation (research + safety decision)

---

id: DIA-127
title: "OMO slim 2.2.13 update evaluation - research what is new, decide safety/worth for the project"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

---

## Description

A new oh-my-opencode-slim version, 2.2.13, is available (developer-reported 2026-08-13). The project runs a customized OMO slim config (.opencode/oh-my-opencode-slim.jsonc) with 3 presets (opencode-go, cebula, free) and heavily customized agents (orchestrator, coder, reviewer, conspecter, etc.). Notably the conspecter permission hardening from commit 753e374 (crwl bash allow, webfetch deny, websearch MCP removed from all 3 presets) must not regress.

Before any upgrade, research what 2.2.13 contains and decide whether updating is:
(a) worth it - net benefit vs the current pinned version;
(b) safe - no regression to the customized config (agent-name lockstep contract via scripts/validate-agent-names.sh, presets, permissions, model assignments), no breaking changes to the OMO presets/agents/skills the project depends on, no OpenCode-version incompatibility;
(c) good for the project long-term - maintenance burden, stability, alignment with newest best practices.

Route per section 10 (AI Devtools Modernization Workflow): gate research by @ai-specialist (web-fresh), findings reviewed by the developer (practice-protected), design via @architector if non-trivial, implementation by @coder, validation via make test-config + restart-verify, independent review by @ai-auditor.

## Evidence (2026-08-13)

Research by the ai-specialist lane: 12 cited sources reviewed for OMO slim
2.2.13 (changelog/diff, release notes, breaking-change scan). Current pin:
2.2.8. Target: 2.2.13.

Pre-flight PASS: opencode version 1.18.18 >= required 1.18.13 (compatibility
floor for 2.2.13), so the update is compatible with the installed OpenCode.

Developer decision 2026-08-13: UPDATE NOW.

Actions taken: global pin changed to 2.2.13 (outside repo,
`~/.config/opencode/opencode.jsonc` line 148, done by lane cod-7); project
comment synced (`.opencode/opencode.jsonc` line ~135 comment bump
2.2.8 -> 2.2.13).

restart-verify PENDING (post-restart): confirm OMO 2.2.13 loaded, websearch
works for ai-specialist, conspecter bash works (DIA-126 catch-all-first fix
also requires the restart to take effect).

Rollback plan: revert global pin to 2.2.8 in
`~/.config/opencode/opencode.jsonc` line 148, then restart opencode.

ai-auditor review pending (section-10 independent review step).

## Verification

- [x] Changelog/diff for 2.2.13 vs the current pinned version collected, with source URLs cited (DONE 2026-08-13 - 12 cited sources by ai-specialist lane)
- [x] Impact analysis: what changes in agents, skills, presets, models, permissions, MCPs, plugins (DONE 2026-08-13)
- [ ] Compatibility check against current .opencode/oh-my-opencode-slim.jsonc customizations (3 presets, conspecter permission changes from 753e374, agent-name lockstep S1-S4 contract via validate-agent-names.sh, make test-config exit 0) (PARTIAL 2026-08-13 - pre-flight PASS opencode 1.18.18 >= 1.18.13 and make test-config exit 0; restart-verify PENDING)
- [x] Recommendation documented with rationale: update now / defer / skip (DONE 2026-08-13 - developer decision: UPDATE NOW)
- [ ] If update recommended: section 10 chain executed (ai-specialist gate -> developer decision -> design -> implement -> make test-config exit 0 -> restart-verify -> ai-auditor review) (IN PROGRESS 2026-08-13 - gate/decision/implement done; restart-verify PENDING; ai-auditor review PENDING)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
