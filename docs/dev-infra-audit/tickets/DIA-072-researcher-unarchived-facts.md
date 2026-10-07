# DIA-072 — researcher returns unarchived facts: 4/16 sources failed to persist during conspect Phase A

<!-- Owner-reported process gap in the §11 knowledge workflow
     (research → conspect → analysis): the researcher returned findings with
     PERSISTENCE_RECOMMENDED: true and 16 source URLs, but conspect Phase A
     (source archival) FAILED on 4/16 URLs (0 bytes, scraping-blocked). The
     conspect was authorized to proceed with the 12 saved sources; the 4
     unarchived facts are flagged `[source not archived — from researcher
     res-1 findings]`. Documents the archive-before-claim gap. NO code/config
     change by this ticket; fix is pipeline/process (see Fix direction). -->

---

id: DIA-072
title: "researcher returns unarchived facts: 4/16 sources failed to persist during conspect Phase A"
area: docs
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-09
source: knowledge-pipeline
date: 2026-08-09
created: 2026-08-09
updated: 2026-08-09

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_01cca6ac1ffeKQo8pVqXS0kKgk"
lane_id: ""
agent: "orchestrator"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-072-researcher-unarchived-facts.md"]
artifacts: ["knowledge/res006-telemetry-plugin-alternatives/res006-telemetry-plugin-alternatives-conspect.md", "knowledge/res006-telemetry-plugin-alternatives/sources/", "knowledge/res006-telemetry-plugin-alternatives/sources/.source-urls.txt"]
evidence: ["ses_01cca6ac1ffeKQo8pVqXS0kKgk (orchestrator)", "ses_01c25478dffeOisBBzKW352HQW (researcher lane res-1)", "ses_01c21c2f2ffeE4JrjPUd3xKUy1 (conspecter Phase A con-1)", "ses_01c1e0c4dffeokeKNAZqE59bLH (conspecter con-2)"]

---

## Description

**Summary:** the research pipeline persists sources only at conspect time
(Phase A), AFTER the researcher has already returned findings in conversation.
Facts sourced from un-archivable URLs therefore rest on ungrounded claims —
only the researcher's prose, no saved source.

**Facts from today's session (2026-08-09):**

1. **res-1** (researcher lane, ses_01c25478dffeOisBBzKW352HQW) returned
   findings on opencode-telemetry / opencode-token-monitor alternatives with
   `PERSISTENCE_RECOMMENDED: true` and **16 source URLs**.
2. **con-1** (conspecter Phase A, ses_01c21c2f2ffeE4JrjPUd3xKUy1) attempted to
   archive all 16 URLs via trafilatura (crawl4ai fallback): **4 FAILED with
   0 bytes**:
   - https://registry.npmjs.org/opencode-telemetry
   - https://registry.npmjs.org/opencode-token-monitor
   - https://www.npmjs.com/package/@devtheops/opencode-plugin-otel
   - https://ccusage.com/guide/opencode/
     Cause: scraping-blocked (npm registry/npmjs and ccusage reject default
     trafilatura/crawl4ai user-agents; likely need headless browser or browser
     UA).
3. The guard gate stopped Phase B (no conspect). Developer authorized
   continuing with the 12 saved sources, with the 4 failed facts flagged
   `[source not archived — from researcher res-1 findings]` in the conspect
   (`knowledge/res006-telemetry-plugin-alternatives/`).
4. **Developer principle (verbatim intent):** "Факт без збереженого джерела
   не повинен рахуватися" — a fact without a saved source must not count.

**Root cause:** source archival happens at conspect time (Phase A), i.e. AFTER
the researcher's claims are already in the conversation. Nothing verifies
archivability at research time, so un-archivable URLs produce ungrounded facts
that were nevertheless retained (with a flag) in the conspect.

**Impact:** Medium (data integrity of the knowledge base). Unarchived facts
cannot be re-grounded or cited; the knowledge base's traceability contract
(claim → saved source) is violated when archival fails.

## Verification

1. Reproduce: dispatch a research request, then conspect Phase A over the
   researcher's URLs — check `knowledge/res*/sources/.source-urls.txt` for
   `NOT ARCHIVED` markers and `knowledge/res*/sources/*.md` for 0-byte files.
2. Confirmed failing today: 4 zero-byte files under
   `knowledge/res006-telemetry-plugin-alternatives/sources/`
   (`registry-opencode-telemetry.md`, `registry-opencode-token-monitor.md`,
   `npm-devtheops-opencode-plugin-otel.md`, `ccusage-opencode-guide.md`) and 4
   `NOT ARCHIVED (scraping blocked)` markers in `.source-urls.txt`.
3. Post-fix (acceptance): future conspect Phase A achieves **100% source
   archival (0 NOT ARCHIVED flags)**; OR if a source is unarchivable, the
   ticket is closed with the policy decision documented (e.g. "claims from
   unarchived sources are excluded from conspects" accepted).

## Fix

**Fix direction (recommended):**

- **(a) Persist at research time.** The researcher should persist sources at
  research time (or at minimum the raw content/URLs) so archive-before-claim
  holds.
- **(b) Enforce archive-before-claim in the pipeline.** The research-pipeline
  skill should enforce that researcher output includes locally-saved sources
  (or the pipeline verifies sources are archivable BEFORE treating claims as
  grounded).
- **(c) Robust downloader fallback.** Add curl with browser user-agent /
  playwright / headless browser fallback for scraping-blocked sites (npm
  registry/npmjs, ccusage).

**§10 routing note:** any change to the research-pipeline skill or researcher
agent definition is §10-routed (AI-tooling config, global AGENTS.md §10) — this
ticket records the gap; the §10 change is a separate work item.

**Adopted fix (2026-08-09):** (c) 3-tier fallback chain implemented in
`.opencode/oh-my-opencode-slim.jsonc` (conspecter Phase A: registry JSON API →
trafilatura → curl+browser-UA → crawl4ai headless) + (b) Archive-Before-Claim
policy in `.opencode/skills/research-pipeline/SKILL.md`. Commits: 024de3f,
92a4474 (fallback-C stdin correction after Phase-6 audit). §10 Phase-6 review
(ai--3) ISSUES-FOUND → fixed → re-review (ai--4) SOUND. `make test-config`
exit 0.

## Re-verify

**Closure (2026-08-09) per Verification item 3 policy path:** the 2 remaining
unarchivable URLs (www.npmjs.com package page, ccusage.com/guide/opencode/) are
documented environment-limited gaps (crawl4ai not installed in the test
environment); claims from unarchived sources are EXCLUDED from conspects per
the adopted Archive-Before-Claim policy (developer principle: "Факт без
збереженого джерела не повинен рахуватися"). Future re-verify: after crawl4ai
provisioning, re-run Phase A on those 2 URLs to achieve 100% archival
(acceptance per Verification item 3a).

1. Future conspect Phase A: 0 `NOT ARCHIVED` flags in
   `knowledge/res*/sources/.source-urls.txt`; no 0-byte source files.
2. If unarchivable sources are accepted by policy: closure note documents the
   accepted policy decision (per Verification item 3).
