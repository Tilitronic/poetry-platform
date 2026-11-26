# DIA-260820-dr0g - researcher agent deviates from 3-tier fetch chain, uses WebFetch/context7 instead of trafilatura/crawl4ai

---

id: DIA-260820-dr0g
title: "researcher agent deviates from 3-tier fetch chain, uses WebFetch/context7 instead of trafilatura/crawl4ai"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-20
source: baseline
date: 2026-08-20
created: 2026-08-20
updated: 2026-08-20

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

The researcher agent (res-2, DIA-260820-jlu0) deviated from the research-pipeline skill's 3-tier fetch chain. Observed behavior:

1. Used WebFetch 5+ times for Google search, arxiv searches, Wikipedia - WebFetch is NOT in the planned pipeline.
2. Used context7_resolve-library-id MCP tool - not in research pipeline.
3. Used gh_grep_searchGitHub 7+ times - acceptable for code search but not for source archival.
4. Only at the end switched to curl | trafilatura for actual source capture.

**Planned pipeline (research-pipeline skill):**

- Tier 1: npm registry JSON API (curl -s registry.npmjs.org)
- Tier 2: trafilatura (direct or after curl for JS-heavy)
- Tier 3: crawl4ai/crwl headless (LAST RESORT ONLY)

**Root cause hypotheses:**

- (a) Skill instructions not clear enough
- (b) Agent has tool preferences that override skill
- (c) No enforcement mechanism to ensure 3-tier chain compliance

**Required:**

- Audit researcher behavior across multiple sessions
- Determine root cause (skill clarity vs agent behavior vs missing enforcement)
- Propose fixes

**Related:** DIA-260820-jlu0 (where this was observed), research-pipeline skill definition.

## Verification

- [ ] Root cause identified and documented
- [ ] Fix implemented and tested

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
