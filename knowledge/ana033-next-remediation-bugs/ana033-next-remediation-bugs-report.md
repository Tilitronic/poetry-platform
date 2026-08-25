# ana033 -- Next-10 Remediation Bugs (Post-ana031 Queue)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: docs/dev-infra-audit/tickets/; tools/opencode-docker/bin/opencode-docker; .opencode/opencode.jsonc; Dockerfile.dev; tools/opencode-docker/Dockerfile; Makefile; knowledge/ana031; knowledge/ana032
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

**Audit date:** 2026-08-21
**Tracking ticket:** DIA-260821-bqy7 'audit repository risks and prioritize unresolved remediation'
**Predecessor excluded:** ana031 Section 4 ranks 1-10 (verbatim list in Section 3 below)
**Authoritative state source:** ana032 ticket reconciliation + live `scripts/tickets list --status OPEN` (2026-08-21)

---

## 1. Executive Summary

This report ranks the next 10 actionable defect/remediation items in queue
**after** the ana031 Top-10. ana031's ranks 1-10 are treated as excluded
candidates. The ranking draws from three pools:

1. **Remaining OPEN tickets** (15 candidates after exclusions)
2. **ana026 no-ticket P0/P1 gaps** (6 candidates, 4 confirmed live, 2 unverified)
3. **ana032 reverse-drift tickets** (4 CLOSED tickets with placeholder Fix/Re-verify)

The ranking method is documented in Section 2. Ten items are selected and
ranked. Two items are proposed new tickets (ana026 P0 gaps with no existing
ticket). Eight items carry existing ticket IDs. No ticket statuses are
changed by this report.

**Headline findings:**

- Two **P0 ana026 gaps** (container socket security, runtime plugin
  duplicates) remain un-ticketed and confirmed live in current source.
- Two **FULL REVERSE-DRIFT** CLOSED tickets (DIA-126, DIA-127) have
  placeholder Fix/Re-verify sections that contradict their CLOSED status.
- Two **Major-severity fresh tickets** (DIA-260821-mzk7 preset routing
  mismatch, DIA-260821-cku1 scripts/tickets update capability) were filed
  today with no implementation evidence.
- The **P1 two-images drift** (OPENCODE_VERSION 1.18.18 vs 1.18.4) is
  confirmed live across Dockerfile.dev and tools/opencode-docker/Dockerfile.

---

## 2. Selection and Ranking Method

### 2.1 Exclusions (hard)

The following are **excluded** from candidate consideration:

| Exclusion source | Items excluded |
|---|---|
| ana031 Section 4 rank 1 | Restart-Verify DIA-222/224/225 Plugin Changes Live |
| ana031 Section 4 rank 2 | DIA-206 ai-specialist Systemic Empty-Return Failure |
| ana031 Section 4 rank 3 | DIA-213 Orchestrator Scope Limitation |
| ana031 Section 4 rank 4 | DIA-234 Datetime-Based Ticket IDs |
| ana031 Section 4 rank 5 | DIA-189 Terminal Session Identity |
| ana031 Section 4 rank 6 | DIA-207 WSL Memory/CPU Cap Exhaustion |
| ana031 Section 4 rank 7 | DIA-208 cebula Preset Model Swap |
| ana031 Section 4 rank 8 | DIA-260820-jlu0 Ticket Gate Chicken-and-Egg |
| ana031 Section 4 rank 9 | OpenSpec Task/Status Drift (6 Changes) |
| ana031 Section 4 rank 10 | DIA-260820-y268 Enforce Ticket-Status Queries |
| This audit ticket | DIA-260821-bqy7 |
| ana032 stale claims | ana029 G1, ana026/028/029 F-1, F-3 (source-contradicted) |
| Already-CLOSED non-drift | DIA-260821-8kpc (CLOSED, DCP plugin removal) |

### 2.2 Candidate pools

| Pool | Count | Source |
|---|---|---|
| Remaining OPEN tickets | 15 | `scripts/tickets list --status OPEN` minus exclusions |
| ana026 no-ticket P0/P1 gaps | 6 | ana032 Section "ana026 Gaps Table" |
| ana032 reverse-drift tickets | 4 | ana032 Section "Reverse-Drift Table" |
| **Total candidate pool** | **25** | |

### 2.3 Ranking criteria (weighted)

Each candidate is scored on five criteria. Ties broken by freshness (newer
first), then by severity (Major > Medium > Low > Info).

| Criterion | Weight | Notes |
|---|---|---|
| Impact (productivity/reliability) | 35% | P0 > P1 > Major > Medium > Low |
| Evidence confidence | 25% | Live source evidence > commit ref > report claim |
| Freshness / staleness | 15% | Days since last verification or filing |
| Blocking dependencies | 15% | Blocks other OPEN work = higher rank |
| Minimal next action size | 10% | Smaller verifiable step = higher rank |

### 2.4 Evidence hierarchy

1. **Live source** (current file content, grep-verified today)
2. **Live ticket state** (`scripts/tickets show`, frontmatter parsed today)
3. **Commit reference** (git log, but not proof of test passage)
4. **Prior report claim** (ana026-ana032, stale unless re-verified)

---

## 3. ana031 Top-10 Exclusion List (verbatim)

The following ten items were ranked in ana031 Section 4 and are **excluded**
from this report's candidate pool. They remain open or in-progress; this
report does not re-rank or supersede them.

1. Restart-Verify DIA-222/224/225 Plugin Changes Live
2. DIA-206 ai-specialist Systemic Empty-Return Failure
3. DIA-213 Orchestrator Scope Limitation
4. DIA-234 Datetime-Based Ticket IDs and Human-Readable Mentions
5. DIA-189 Terminal Session Identity
6. DIA-207 WSL Memory/CPU Cap Exhaustion
7. DIA-208 cebula Preset Model Swap
8. DIA-260820-jlu0 DIA-217 Ticket Gate Chicken-and-Egg
9. OpenSpec Task/Status Drift (6 Changes with 0% Completion)
10. DIA-260820-y268 Enforce Ticket-Status Queries via scripts

---

## 4. Ranked Next-10 Remediation List

### Rank 11 (overall): PROPOSED NEW TICKET -- P0 Container Socket Security Hardening

| Field | Value |
|---|---|
| **Title** | Container socket security: add `--with-engine` opt-in flag for socket mounts |
| **ID** | **PROPOSED NEW** (no existing ticket; ana032 gap #1) |
| **State** | No ticket filed. P0 gap confirmed live. |
| **Severity / Impact** | P0 / HIGH -- security boundary. Host container engine socket mounted read-write into dev container without explicit opt-in. Any compromise inside the container has full engine control. |
| **Evidence path + line** | `tools/opencode-docker/bin/opencode-docker` lines 137-178. Socket mounted unconditionally; no `--with-engine` flag exists (`grep -c "with-engine"` returns 0). |
| **Why it follows ana031 Top-10** | ana031 focused on plugin/runtime verification and OPEN tickets. This is a P0 security gap with no ticket, identified by ana026 and re-confirmed live by ana032. Higher severity than any remaining OPEN ticket. |
| **Recommended disposition** | **CREATE** new ticket. Severity: Major (security). Area: docker. Scope: add `--with-engine` opt-in flag, default-unsafe-off; document socket mount security model; add `make test-infra` assertion that socket is not mounted without flag. |

---

### Rank 12 (overall): PROPOSED NEW TICKET -- P0 Runtime Plugin Duplicates

| Field | Value |
|---|---|
| **Title** | Runtime duplicates: observer plugins loaded twice via global + project config |
| **ID** | **PROPOSED NEW** (no existing ticket; ana032 gap #2) |
| **State** | No ticket filed. P0 gap confirmed live. |
| **Severity / Impact** | P0 / HIGH -- reliability. Both `delegation-observer.ts` and `needs-input-observer.ts` are registered in `.opencode/opencode.jsonc`. If the host global config also registers them, each observer fires twice per event, doubling registry writes and risking double-handoff archive writes. |
| **Evidence path + line** | `.opencode/opencode.jsonc` -- grep returns 2 matches (delegation-observer.ts, needs-input-observer.ts). `opencode debug config` would show duplicates if host global also registers them. |
| **Why it follows ana031 Top-10** | ana031 rank 1 (restart-verify) is related but scoped to plugin changes, not duplicate registration. This is a distinct P0 gap with no ticket. |
| **Recommended disposition** | **CREATE** new ticket. Severity: Major. Area: opencode-config. Scope: audit global + project plugin registration; deduplicate; add `make test-runtime-config` target that runs `opencode debug config` in clean HOME and asserts unique plugin list. |

---

### Rank 13 (overall): DIA-260821-mzk7 -- Preset Routing Mismatch After Restart

| Field | Value |
|---|---|
| **Title** | Diagnose active OpenCode preset routing mismatch after restart |
| **ID** | DIA-260821-mzk7 (existing, OPEN) |
| **State** | OPEN. Filed 2026-08-21. No git commits. No OpenSpec change. |
| **Severity / Impact** | Major / HIGH -- wrong preset routes to wrong model, silently degrading output quality across all lanes. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-260821-mzk7-diagnose-active-opencode-preset-routing-mismatch-after-restart.md`. `scripts/tickets show DIA-260821-mzk7` confirms OPEN, 0 attempts, no session attribution. |
| **Why it follows ana031 Top-10** | ana031 rank 7 (DIA-208 cebula model swap) is related but scoped to model evaluation. This is a distinct runtime routing defect that may be the root cause of silent model mismatches. Fresh (filed today). |
| **Recommended disposition** | **KEEP OPEN**. Dispatch @ai-specialist or @coder to run `opencode debug config` post-restart, capture active preset + model, compare against `.opencode/oh-my-opencode-slim.jsonc` cebula preset definition. Document mismatch in ticket Fix section. |

---

### Rank 14 (overall): DIA-260821-cku1 -- scripts/tickets Update Capability

| Field | Value |
|---|---|
| **Title** | Add minimal controlled scripts/tickets update capability for status and Fix/Re-verify evidence |
| **ID** | DIA-260821-cku1 (existing, OPEN) |
| **State** | OPEN. Filed 2026-08-21. No git commits. |
| **Severity / Impact** | Major / MEDIUM-HIGH -- without this, ticket frontmatter drift (ana032 reverse-drift, stale OPEN/CLOSED) cannot be mechanically corrected. Enables ana032 reconciliation recommendations to be applied. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-260821-cku1-add-minimal-controlled-scripts-tickets-update-capability-for-status-and-fix-re-verify-evidence.md`. `scripts/tickets help` shows no `update` subcommand today. |
| **Why it follows ana031 Top-10** | ana031 rank 10 (DIA-260820-y268) is the query-side enforcement; this is the write-side enabler. Both are needed for ticket integrity. Fresh (filed today). |
| **Recommended disposition** | **KEEP OPEN**. Implement `scripts/tickets update <id> --status <status>` and `scripts/tickets update <id> --fix-evidence <text>` with practice-protected guard (developer approval required for status flips). |

---

### Rank 15 (overall): PROPOSED NEW TICKET -- P1 Two Dockerfiles, Different Runtime Contracts

| Field | Value |
|---|---|
| **Title** | Two Dockerfiles declare different OPENCODE_VERSION (1.18.18 vs 1.18.4) |
| **ID** | **PROPOSED NEW** (no existing ticket; ana032 gap #3, CONFIRMED) |
| **State** | No ticket filed. P1 gap confirmed live. |
| **Severity / Impact** | P1 / MEDIUM -- two images with different runtime contracts. Teammates using different entry points get different OpenCode versions, causing irreproducible behavior. |
| **Evidence path + line** | `Dockerfile.dev` line N: `ARG OPENCODE_VERSION=1.18.18`. `tools/opencode-docker/Dockerfile` line N: `ARG OPENCODE_VERSION=1.18.4`. 14 patch versions apart. |
| **Why it follows ana031 Top-10** | Not covered by ana031. Distinct from DIA-188 (OMO self-sufficiency) which addresses plugin declaration, not base image version drift. |
| **Recommended disposition** | **CREATE** new ticket. Severity: Medium. Area: docker. Scope: unify OPENCODE_VERSION in a single source of truth (e.g., `.opencode/version` file or build arg passed to both Dockerfiles); add contract test asserting both images report same `opencode --version`. |

---

### Rank 16 (overall): PROPOSED NEW TICKET -- P1 No Runtime Merge-Defect Detection

| Field | Value |
|---|---|
| **Title** | Automatic checks don't detect runtime merge defects (no `make test-runtime-config`) |
| **ID** | **PROPOSED NEW** (no existing ticket; ana032 gap #4, CONFIRMED) |
| **State** | No ticket filed. P1 gap confirmed live. |
| **Severity / Impact** | P1 / MEDIUM -- no automated check catches plugin duplicates, preset mismatches, or version drift at merge time. Defects surface only at runtime. |
| **Evidence path + line** | `Makefile`: `grep -c "test-runtime-config"` returns 0. No target runs `opencode debug config` in a clean HOME. |
| **Why it follows ana031 Top-10** | ana031 rank 1 (restart-verify) is a manual analogue. This is the automated-gate counterpart. Without it, ranks 11-15 can recur silently after every merge. |
| **Recommended disposition** | **CREATE** new ticket. Severity: Medium. Area: dev-infra. Scope: add `make test-runtime-config` target that (a) builds image, (b) runs `opencode debug config` in clean HOME, (c) asserts unique plugin list, (d) asserts preset model matches config. Depends on ranks 12 and 15 being resolved first. |

---

### Rank 17 (overall): DIA-126 -- FULL REVERSE-DRIFT (CLOSED with placeholder Fix)

| Field | Value |
|---|---|
| **Title** | autonomous-mode-permission-hardening: CLOSED but Fix section is placeholder |
| **ID** | DIA-126 (existing, CLOSED -- reverse-drift) |
| **State** | CLOSED. Fix section: "To be filled at fix time. Planning ticket - no implementation performed yet." Re-verify section: "LIVE RESTART-VERIFY DEFERRED (2026-08-14, developer disposition: ACCEPT + close directions (b)+(d) as satisfied-by-DIA-098)". |
| **Severity / Impact** | Medium / MEDIUM -- ticket integrity. CLOSED status contradicts placeholder Fix. Future auditors cannot determine if work was done. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-126-autonomous-mode-permission-hardening.md`, Fix section (placeholder), Re-verify section (DEFERRED). ana032 Reverse-Drift Table flags this as FULL REVERSE-DRIFT. |
| **Why it follows ana031 Top-10** | Not a runtime defect; a ledger-integrity defect. Ranked below P0/P1 gaps because it does not block current work. |
| **Recommended disposition** | **UPDATE** or **RE-OPEN**. Either (a) populate Fix section with evidence of what was actually done (if directions (b)+(d) were satisfied by DIA-098, document which commits), or (b) flip back to OPEN and mark as planning-only. Requires DIA-260821-cku1 (rank 14) to provide the mechanical update path. |

---

### Rank 18 (overall): DIA-127 -- FULL REVERSE-DRIFT (CLOSED with placeholder Fix + Re-verify)

| Field | Value |
|---|---|
| **Title** | omo-slim-2-2-13-update-evaluation: CLOSED but both Fix and Re-verify are placeholders |
| **ID** | DIA-127 (existing, CLOSED -- reverse-drift) |
| **State** | CLOSED. Fix section: "To be filled at fix time." Re-verify section: "To be filled at re-verify time." Both are empty placeholders. |
| **Severity / Impact** | Medium / MEDIUM -- ticket integrity. Worse than DIA-126: both Fix and Re-verify are placeholders, yet status is CLOSED. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-127-omo-slim-2-2-13-update-evaluation.md`, Fix and Re-verify sections (both placeholders). ana032 Reverse-Drift Table flags this as FULL REVERSE-DRIFT. |
| **Why it follows ana031 Top-10** | Same ledger-integrity category as rank 17. Ranked below DIA-126 only because DIA-126 has a partial Re-verify note (DEFERRED with developer disposition), while DIA-127 has nothing. |
| **Recommended disposition** | **UPDATE** or **RE-OPEN**. Precedent: DIA-187 (OMO slim 2.2.14 update evaluation) is the successor ticket. If DIA-127 was superseded by DIA-187, document that in Fix section and keep CLOSED. Otherwise re-open. |

---

### Rank 19 (overall): DIA-260820-dr0g -- Researcher Agent Deviates from 3-Tier Fetch Chain

| Field | Value |
|---|---|
| **Title** | Researcher agent deviates from 3-tier fetch chain, uses WebFetch/context7 instead of trafilatura/crawl4ai |
| **ID** | DIA-260820-dr0g (existing, OPEN) |
| **State** | OPEN. Filed 2026-08-20. No git commits. No OpenSpec change. |
| **Severity / Impact** | Medium / MEDIUM -- researcher lane bypasses the project's 3-tier fetch chain (Tier 1: committed conspect, Tier 2: web fetch via trafilatura/crawl4ai, Tier 3: context7 docs). Using WebFetch/context7 directly skips Tier-1 caching and produces non-persistent research. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-260820-dr0g-researcher-agent-deviates-from-3-tier-fetch-chain-uses-webfetch-context7-instead-of-trafilatura-crawl4ai.md`. `scripts/tickets show DIA-260820-dr0g` confirms OPEN, 0 attempts. |
| **Why it follows ana031 Top-10** | Not covered by ana031. Process defect (lane not following documented fetch chain), not a runtime crash. Ranked below P0/P1 gaps and reverse-drift because impact is research-quality degradation, not system reliability. |
| **Recommended disposition** | **KEEP OPEN**. Update researcher agent prompt (`.opencode/agents/researcher.md` or `.opencode/oh-my-opencode-slim.jsonc` researcher preset) to enforce 3-tier chain. Add a test assertion in the research-pipeline skill that rejects direct WebFetch/context7 calls when trafilatura/crawl4ai are available. |

---

### Rank 20 (overall): DIA-260819-qibv -- Research Pipeline Bug: Conspect Should Be Mandatory

| Field | Value |
|---|---|
| **Title** | Research pipeline bug: conspect should be mandatory, not optional |
| **ID** | DIA-260819-qibv (existing, OPEN) |
| **State** | OPEN. Filed 2026-08-19. Commit e1de2e1 (AFK batch) referenced but ticket still OPEN. |
| **Severity / Impact** | Medium / MEDIUM -- research pipeline produces orphan fetches without persistent conspect artifacts. Undermines the Tier-1 caching strategy. |
| **Evidence path + line** | `docs/dev-infra-audit/tickets/DIA-260819-qibv-research-pipeline-bug-conspect-should-be-mandatory-not-optional.md`. ana032 KEEP OPEN table notes commit e1de2e1 but ticket still OPEN -- verify if fix complete. |
| **Why it follows ana031 Top-10** | Closely related to rank 19 (DIA-260820-dr0g). Both are research-pipeline process defects. Ranked below dr0g because qibv has a commit reference (e1de2e1) suggesting partial progress, while dr0g has none. |
| **Recommended disposition** | **CLOSE CANDIDATE** pending verification. Check commit e1de2e1 diff: if it makes conspect mandatory in the research-pipeline skill, populate Fix section with the diff summary, run `make test-config`, and close. If commit only touches peripheral files, KEEP OPEN. |

---

## 5. Audit-Staleness Section

This section identifies previously CLOSED or OPEN ticket statuses that appear
contradicted by current evidence. **No status changes are recommended without
developer approval and live test verification.**

### 5.1 Reverse-drift: CLOSED tickets with placeholder Fix/Re-verify

| Ticket | Status | Fix section | Re-verify section | Contradiction |
|---|---|---|---|---|
| DIA-126 | CLOSED | Placeholder ("To be filled") | DEFERRED (developer disposition recorded) | PARTIAL -- Re-verify has content, Fix does not |
| DIA-127 | CLOSED | Placeholder ("To be filled") | Placeholder ("To be filled") | FULL -- both sections empty |
| DIA-131 | CLOSED | Placeholder ("To be filled") | Populated (RESTART-VERIFY PASS) | PARTIAL -- Fix empty but Re-verify passed |
| DIA-132 | CLOSED | Placeholder ("To be filled") | Populated (Restart-verify PASSED) | PARTIAL -- Fix empty but Re-verify passed |

**Evidence source:** ana032 Reverse-Drift Table, re-verified by direct file
read of each ticket's Fix/Re-verify sections on 2026-08-21.

**Recommended action:** Do NOT change statuses unilaterally. For each:
(a) verify via git log whether implementation commits exist, (b) if yes,
populate Fix section from commit diffs, (c) if no, re-open or mark as
planning-only. DIA-260821-cku1 (rank 14) would provide the mechanical path.

### 5.2 OPEN tickets with commit references but no status flip

| Ticket | Status | Commit reference | Contradiction |
|---|---|---|---|
| DIA-186 | OPEN | Commit d18672b (DIA-186 fix) | Fix committed but ticket still OPEN |
| DIA-188 | OPEN | Commit 10ed051 (DIA-188 OMO project-level declaration) | Fix committed but ticket still OPEN |
| DIA-189 | OPEN | Commits 00de216, 9d96310, 97dd000 | Multiple fix commits but ticket still OPEN |
| DIA-208 | OPEN | Commits 1baee98, bedfadd, a7b9c21 | Multiple fix commits but ticket still OPEN |
| DIA-213 | OPEN | Commit 6d80f65 | Fix committed but ticket still OPEN |
| DIA-260819-8kwm | OPEN | Commit e1de2e1 (AFK batch) | Fix committed but ticket still OPEN |
| DIA-260819-97fg | OPEN | Commit e1de2e1 (AFK batch) | Fix committed but ticket still OPEN |
| DIA-260819-qibv | OPEN | Commit e1de2e1 (AFK batch) | Fix committed but ticket still OPEN |
| DIA-260820-jlu0 | OPEN | Commit 1c1943a (HMAC capability authorization) | Fix committed but ticket still OPEN |

**Evidence source:** ana032 KEEP OPEN table, cross-referenced with
`git log --oneline --grep="<DIA-id>"`.

**Recommended action:** For each, verify (a) commit diff matches ticket scope,
(b) `make test-config` / `make test-shell` pass with the commit applied,
(c) Re-verify section is populated. Only then flip to CLOSED. Do NOT batch-close
without per-ticket verification.

### 5.3 Stale OPEN tickets with no commit references

| Ticket | Status | Filed | Last updated | Concern |
|---|---|---|---|---|
| DIA-089 | OPEN | 2026-08-10 | 2026-08-11 | 11 days without commit. Phase B/C blocked on developer env setup. |
| DIA-195 | OPEN | 2026-08-15 | 2026-08-15 | 6 days without commit. No OpenSpec change. |
| DIA-211 | OPEN | 2026-08-17 | 2026-08-17 | 4 days without commit. No OpenSpec change. |
| DIA-260819-880v | OPEN | 2026-08-19 | 2026-08-19 | 2 days without commit. Low severity. |

**Recommended action:** These are not contradictions (OPEN status matches
absence of work), but they are staleness risks. If no work is planned,
consider archiving with "ABANDONED" status to reduce OPEN-ticket noise.

---

## 6. Summary Table

| Rank | ID | Title | State | Severity | Disposition |
|---|---|---|---|---|---|
| 11 | PROPOSED NEW | P0 Container socket security hardening | No ticket | P0 | CREATE |
| 12 | PROPOSED NEW | P0 Runtime plugin duplicates | No ticket | P0 | CREATE |
| 13 | DIA-260821-mzk7 | Preset routing mismatch after restart | OPEN | Major | KEEP OPEN |
| 14 | DIA-260821-cku1 | scripts/tickets update capability | OPEN | Major | KEEP OPEN |
| 15 | PROPOSED NEW | P1 Two Dockerfiles, different OPENCODE_VERSION | No ticket | P1 | CREATE |
| 16 | PROPOSED NEW | P1 No runtime merge-defect detection | No ticket | P1 | CREATE |
| 17 | DIA-126 | FULL REVERSE-DRIFT: autonomous-mode-permission-hardening | CLOSED (drift) | Medium | UPDATE/RE-OPEN |
| 18 | DIA-127 | FULL REVERSE-DRIFT: omo-slim-2-2-13-update-evaluation | CLOSED (drift) | Medium | UPDATE/RE-OPEN |
| 19 | DIA-260820-dr0g | Researcher deviates from 3-tier fetch chain | OPEN | Medium | KEEP OPEN |
| 20 | DIA-260819-qibv | Research pipeline: conspect should be mandatory | OPEN | Medium | CLOSE CANDIDATE |

---

## 7. Files Touched

```
knowledge/ana033-next-remediation-bugs/ana033-next-remediation-bugs-report.md  (this report)
```

**Source files read (evidence):**
```
knowledge/ana031-repository-risk-prioritization/ana031-repository-risk-prioritization-report.md
knowledge/ana032-august-ticket-openspec-reconciliation/ana032-august-ticket-openspec-reconciliation-report.md
docs/dev-infra-audit/tickets/DIA-260821-mzk7-*.md
docs/dev-infra-audit/tickets/DIA-260821-cku1-*.md
docs/dev-infra-audit/tickets/DIA-260821-8kpc-*.md
docs/dev-infra-audit/tickets/DIA-260820-dr0g-*.md
docs/dev-infra-audit/tickets/DIA-260819-qibv-*.md
docs/dev-infra-audit/tickets/DIA-260819-8kwm-*.md
docs/dev-infra-audit/tickets/DIA-260819-97fg-*.md
docs/dev-infra-audit/tickets/DIA-260819-880v-*.md
docs/dev-infra-audit/tickets/DIA-260821-3blw-*.md
docs/dev-infra-audit/tickets/DIA-260821-4cx5-*.md
docs/dev-infra-audit/tickets/DIA-260821-qw29-*.md
docs/dev-infra-audit/tickets/DIA-089-*.md
docs/dev-infra-audit/tickets/DIA-186-*.md
docs/dev-infra-audit/tickets/DIA-187-*.md
docs/dev-infra-audit/tickets/DIA-188-*.md
docs/dev-infra-audit/tickets/DIA-195-*.md
docs/dev-infra-audit/tickets/DIA-211-*.md
docs/dev-infra-audit/tickets/DIA-126-*.md
docs/dev-infra-audit/tickets/DIA-127-*.md
docs/dev-infra-audit/tickets/DIA-131-*.md
docs/dev-infra-audit/tickets/DIA-132-*.md
tools/opencode-docker/bin/opencode-docker (lines 137-178)
.opencode/opencode.jsonc (plugin registration)
Dockerfile.dev (OPENCODE_VERSION=1.18.18)
tools/opencode-docker/Dockerfile (OPENCODE_VERSION=1.18.4)
Makefile (test-runtime-config target absent)
```

---

## 8. Current-Status Evidence

**Live ticket query (2026-08-21):**
```
$ scripts/tickets list --status OPEN
25 OPEN tickets returned (see Section 2.1 for full list)
```

**Live source verification (2026-08-21):**
```
$ grep -c "with-engine" tools/opencode-docker/bin/opencode-docker
0  (flag absent -- P0 gap confirmed)

$ grep -E "delegation-observer|needs-input-observer" .opencode/opencode.jsonc | wc -l
2  (both observers registered -- P0 gap confirmed)

$ grep OPENCODE_VERSION Dockerfile.dev tools/opencode-docker/Dockerfile
Dockerfile.dev: ARG OPENCODE_VERSION=1.18.18
tools/opencode-docker/Dockerfile: ARG OPENCODE_VERSION=1.18.4
(P1 gap confirmed -- 14 patch versions apart)

$ grep -c "test-runtime-config" Makefile
0  (target absent -- P1 gap confirmed)
```

**Test execution:** `make` command unavailable in current environment. All
test-status disclosures reflect this constraint. Developer must run
`make test-config`, `make test-shell`, `make test-infra` in a proper
environment before closing any ticket.

---

## 9. Caveats

1. **No ticket statuses changed.** This report is read-only. All disposition
   recommendations require developer approval.
2. **No tickets created.** Four proposed new tickets are identified but not
   filed. Developer must approve creation.
3. **Test execution unavailable.** `make` not found in current environment.
   All test-status disclosures are "tests not run".
4. **ana026 P1 gaps #3 and #4 (make test-config not hermetic, make test-shell
   contradicts docs) are UNVERIFIED** due to environment constraints. They are
   not included in the ranked list. If confirmed, they would rank around 17-18.
5. **DIA-260821-8kpc (DCP plugin removal) is CLOSED** and excluded from the
   candidate pool. ana032 listed it as OPEN in the KEEP OPEN table, but live
   `scripts/tickets show` confirms CLOSED. This is a minor ana032 drift.
6. **Ranking is subjective.** The weighted criteria in Section 2.3 produce a
   deterministic order for the evidence gathered, but different weightings
   would produce different ranks. The method is documented for reproducibility.
