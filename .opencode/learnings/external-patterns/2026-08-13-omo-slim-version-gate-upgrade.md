# OMO slim version-gate upgrade: 2.2.8 -> 2.2.13 (DIA-127, 2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-127 upgrade evaluation - ai-specialist gate research (12 cited sources, web-fresh), developer decision (practice-protected), pin change by lane cod-7, ai-auditor independent review (session ses_00561027affeWdPCmgU2VBjg7O). Registered per AGENTS.md section 10 Phase 6.
- **Status:** APPLIED - implemented 2026-08-13 (pinned 2.2.13 + validated); ai-auditor APPROVE-WITH-CHANGES; Step B res019 conspect persistence PENDING (DIA-127 ticket stays OPEN until it completes).
- **Ticket:** DIA-127 (OPEN) - "OMO slim 2.2.13 update evaluation - research what is new, decide safety/worth for the project" (docs/dev-infra-audit/tickets/DIA-127-omo-slim-2-2-13-update-evaluation.md).

## Research summary (gate)

- DIA-127 upgrade evaluation for oh-my-opencode-slim 2.2.8 -> 2.2.13: ai-specialist lane reviewed 12 cited sources (changelog/diff, release notes, breaking-change scan). Developer decision 2026-08-13: UPDATE NOW.
- OMO 2.2.13 schema confirms the surfaces the project depends on are intact: presets, agents, disabled_agents, council, websearch.
- Compatibility floor met: opencode >= 1.18.13 required by 2.2.13; installed opencode 1.18.18 (pre-flight PASS).
- No-regression check: conspecter permission hardening from commit 753e374 (crwl bash allow, webfetch deny, websearch MCP removed from all 3 presets) preserved.

## Pin change (implementation)

- Global pin: `~/.config/opencode/opencode.jsonc` line 148 -> "oh-my-opencode-slim@2.2.13" (outside repo, done by lane cod-7).
- Project comment sync: `.opencode/opencode.jsonc` line 135 comment bump 2.2.8 -> 2.2.13.
- Rollback plan (documented in ticket): revert global pin to 2.2.8 at line 148, then restart opencode.

## Validation evidence

- make test-config exit 0 (20 agents audited, 0 gaps, 249 warnings; agent-name lockstep S1-S4 via validate-agent-names.sh 24/24).
- restart-verify PASS chain (post-pin session 2026-08-13, evidence recorded in DIA-127 ticket "Restart-verify evidence" section):
  - (a) OMO 2.2.13 LOADED - inferred from pinned install dir package.json (version 2.2.13), runtime skill-sync staging into 2.2.13 paths at session start, auto-update-checker "Already on latest version". Stale 2.2.8 install dir still present in cache.
  - (b) ai-specialist websearch PASS - websearch granted in ALL 3 OMO presets (opencode-go/cebula/free); websearch is a permission action in OMO 2.2.13 schema and a builtin tool in opencode 1.18.18.
  - (c) conspecter bash PASS - prior same-session proof (ses_0059b11dbffegxB19B4ywdBVs5): bash present, crwl runs with args, webfetch absent+denied. Full re-verify pending next-session restart (942fcda wildcard hardening loads then).

## ai-auditor verdict

- APPROVE-WITH-CHANGES (session ses_00561027affeWdPCmgU2VBjg7O). Developer disposition: ACCEPT findings 1 (CHANGELOG entry), 2 (learnings registration), 3 (REFERENCE-ONLY version fix); DEFER finding 5 to Step B (ticket status stays OPEN until res019 conspect persistence completes); NOTE finding 4 (explicit runtime version fingerprint for future upgrades - no action now, one-line note added in ticket verification section).

## Outcome field

- Implemented 2026-08-13: pinned 2.2.13 (global line 148 + project comment sync), validated (make test-config exit 0, restart-verify PASS), ai-auditor APPROVE-WITH-CHANGES, this Phase-6 registration (CHANGELOG entry + learnings + REFERENCE-ONLY fix + ticket checklist marks). Step B res019 conspect persistence PENDING - DIA-127 ticket status remains OPEN until it completes.

## Tags

DIA-127, omo-slim, version-gate, upgrade-evaluation, 2.2.13, pin, section-10, ai-specialist, ai-auditor, restart-verify
