# ana031 -- Repository Risk Prioritization and Remediation Ranking

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/plugins/delegation-observer.ts, .opencode/plugins/__tests__/, docs/dev-infra-audit/tickets/, openspec/changes/, .opencode/CHANGELOG.yaml, knowledge/ana026-ana030
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## 1. Executive Summary

This analysis reconciles current repository source state against prior analysis
reports (ana026-ana030) to produce a ranked top-10 remediation list. Current
source/runtime evidence takes priority over older report claims. Three stale
claims from ana028/ana029 are explicitly marked and excluded from the ranked
list. The repository has 199 tickets (23 OPEN, 6 Blocker, 15 Critical), 25
OpenSpec changes with significant task/status drift, and no committed
GPT/ChatGPT repository-state report.

**Key reconciliation findings:**

- ana029 G1 (parallel-handoff.test.mjs ARCHIVE_NAME_RE regex) is STALE -- the
  regex has been updated to include UUID suffix (line 172 of
  parallel-handoff.test.mjs).
- ana026/ana028/ana029 F-1/F-3 claims (archive collision, slot identity) are
  FIXED in current plugin source (delegation-observer.ts lines 1483, 4119) and
  covered by regression tests (handoff-archive-collision.test.mjs,
  handoff-slot-identity.test.mjs).
- ana028 G2 (restart-verify DIA-222/224/225) remains OPEN -- no CHANGELOG
  entry or runtime evidence confirms live verification.

---

## 2. Inventory

### 2.1 Open Ticket Themes (23 OPEN tickets)

```
Theme                          Count  Severity distribution
-----------------------------  -----  ---------------------
opencode-config (presets,       14    3 Major, 8 Medium, 2 Low, 1 Info
  permissions, orchestrator)
dev-infra (scripts, validators,  5    2 Major, 3 Medium
  ticket system)
docker (container setup,         2    2 Medium
  Tailscale)
env (WSL resource caps)          1    1 Major
skills (book_rag)                1    1 Medium
```

**Blocker/Critical OPEN tickets (6 Blocker + 15 Critical total, subset OPEN):**

- DIA-213 (High, OPEN): Orchestrator scope limitation
- DIA-208 (Major, OPEN): cebula preset model swap
- DIA-207 (Major, OPEN): WSL memory/CPU cap exhaustion
- DIA-206 (Major, OPEN): ai-specialist systemic empty-return failure
- DIA-189 (Major, OPEN): terminal session identity
- DIA-234 (Major, OPEN): Datetime-based ticket IDs
- DIA-260821-mzk7 (Major, OPEN): preset routing mismatch
- DIA-260820-jlu0 (Major, OPEN): DIA-217 ticket gate chicken-and-egg

### 2.2 OpenSpec Task/Status Drift

```
Change name                    Tasks done/total  Status
-----------------------------  ----------------  --------
batch-d-infra-hardening        0/10              STALE
batch-d-parallel-coders        0/13              STALE
omo-self-sufficiency           0/24              STALE
ssh-agent-forward-opencode     0/12              STALE
test-suite-audit-fixes         0/9               STALE
worktree-branch-cleanup        0/7               STALE
dia-221-harness-testing        0/0               NO TASKS
parallel-handoff-slots         0/0               NO TASKS
context7-docs-pipeline         0/0               NO TASKS
dev-infra-config-validators    0/0               NO TASKS
dev-infra-copilot-fixes        0/0               NO TASKS
dev-infra-copilot-fixes-2      0/0               NO TASKS
dev-infra-jq-probe             0/0               NO TASKS
dev-infra-language-servers     0/0               NO TASKS
dev-infra-pin-sync             0/0               NO TASKS
dev-infra-stack-hardening      0/0               NO TASKS
dia-066-tool-coverage-audit    0/0               NO TASKS
dia-067-docker-trafilatura     0/0               NO TASKS
dia-100-worktree-lifecycle     0/0               NO TASKS
dia-redispatch-cycle           0/0               NO TASKS
pre-commit-autofix             0/0               NO TASKS
test-skills-gate               0/0               NO TASKS
volta-to-mise                  0/0               NO TASKS
```

**Drift assessment:** 6 changes have non-zero task counts but 0% completion.
17 changes have empty tasks.md files (0/0). This indicates either:
(a) tasks.md was never populated, (b) work was done outside OpenSpec flow,
or (c) changes were abandoned. No archive/ entries for these changes.

### 2.3 GPT/ChatGPT Repository-State Report

**ABSENT.** No committed GPT or ChatGPT repository-state report exists in the
repository. The only GPT-related artifacts are model evaluation sources under
`knowledge/res021-opencode-agent-presets/sources/openai-gpt-5-6.md` and
`openai-gpt-5-6-luna.md` (OpenAI announcement archives, not repository-state
analysis).

### 2.4 Report Limitations

- **Runtime verification gap:** Plugin changes (DIA-222/224/225) have hermetic
  tests but no confirmed live restart-verification in CHANGELOG.
- **OpenSpec drift:** Cannot determine if 0/0 changes are abandoned or
  completed outside OpenSpec flow without manual investigation.
- **Ticket ledger drift:** DIA-260820-y268 (enforce ticket-status queries via
  scripts) is OPEN, indicating README rollup may still drift from actual state.
- **Session-scoped evidence:** Some failure modes (DIA-206 empty returns,
  DIA-207 WSL stalls) are runtime observations not fully captured in commits.

---

## 3. Stale Claims (Excluded from Ranked List)

The following claims from prior reports are contradicted by current source
evidence and are EXCLUDED from the ranked remediation list:

### 3.1 ana029 G1: parallel-handoff.test.mjs ARCHIVE_NAME_RE Regex

**Claim (ana029, 2026-08-18):** "DIA-222 changed the archive filename format...
The pre-existing test at parallel-handoff.test.mjs line 178 still expects the
OLD format... blocks make test-harness entirely."

**Current source (2026-08-21):** Line 172 of parallel-handoff.test.mjs shows:
```
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/
```
The regex includes the UUID suffix. The test expects the NEW format.

**Verdict:** STALE. Fix was applied. Evidence: parallel-handoff.test.mjs:172.

### 3.2 ana026/ana028/ana029 F-1: Archive Collision (Same-Millisecond Writes)

**Claim (ana026 2026-08-17, ana028 2026-08-18, ana029 2026-08-18):**
"DIA-085 F-1 CRITICAL: same-millisecond same-session archive collision...
NOT YET FIXED... two successive writes produce identical archiveName."

**Current source (2026-08-21):** delegation-observer.ts line 1483:
```
const archiveName = `${sessionId}.${iso}.${randomUUID()}.json`
```
The UUID suffix ensures distinct filenames even when ISO timestamp is identical.

**Regression test:** handoff-archive-collision.test.mjs (DIA-223 C1) verifies
F-1 fix. Test comment: "Verifies F-1 fix from DIA-222: same-millisecond archive
writes produce distinct archive names (UUID suffix)."

**Verdict:** STALE. Fix applied and tested. Evidence: delegation-observer.ts:1483,
handoff-archive-collision.test.mjs.

### 3.3 ana026/ana028/ana029 F-3: Slot Identity Collapse to "unknown"

**Claim (ana026 2026-08-17, ana028 2026-08-18, ana029 2026-08-18):**
"DIA-085 F-3 CRITICAL: slot identity parentSessionId ?? lane_id ?? 'unknown'
collapses pre-dispatch sessions to 'unknown'... NOT YET FIXED."

**Current source (2026-08-21):** delegation-observer.ts line 4119:
```
const handoffSessionId = parentSessionId ?? args.lane_id ?? context?.sessionID ?? "unidentified-session"
```
The literal "unknown" is never used. Fallback chain ends with "unidentified-session".

**Regression test:** handoff-slot-identity.test.mjs (DIA-223 C2) verifies F-3
fix. Test comment: "DIA-223 C2 regression test: slot identity never falls back
to 'unknown'."

**Verdict:** STALE. Fix applied and tested. Evidence: delegation-observer.ts:4119,
handoff-slot-identity.test.mjs.

---

## 4. Ranked Top-10 Remediation List

Ranking criteria: impact (productivity/reliability), confidence (evidence
strength), freshness (time since last verification), dependencies (blocking
relationships), and minimal next action (smallest verifiable step).

### Rank 1: Restart-Verify DIA-222/224/225 Plugin Changes Live

**Risk:** Plugin changes (F-1 archive collision fix, F-3 slot identity fix,
D3 empty-result detection, D4 failure cap) have hermetic tests but no confirmed
live restart-verification. Runtime behavior under actual OpenCode process is
unconfirmed.

**Evidence paths/citations:**
- .opencode/plugins/delegation-observer.ts:1483 (F-1 UUID suffix)
- .opencode/plugins/delegation-observer.ts:4119 (F-3 slot identity)
- .opencode/plugins/__tests__/handoff-archive-collision.test.mjs (C1 test)
- .opencode/plugins/__tests__/handoff-slot-identity.test.mjs (C2 test)
- .opencode/CHANGELOG.yaml: last entry 2026-08-20, no restart-verify entry
- ana028 section 1.1: "restart-verify DEFERRED"
- ana029 section 1.1: "#1 priority is restart-verify"

**Impact:** HIGH. If runtime issues exist (e.g., randomUUID import path,
sessionID availability in fallback chain), they will surface as silent handoff
failures or false-positive empty-result detection at session boundaries.

**Confidence:** HIGH. Hermetic tests pass, but runtime verification is a
distinct gate (DIA-070 established TUI restart does NOT load patched plugin
code; only hard process restart does).

**Freshness:** STALE. ana028 (2026-08-18) and ana029 (2026-08-18) flagged this
as #1 priority. No CHANGELOG entry confirms completion. 3+ days without
verification.

**Dependencies:** None. Can be done immediately.

**Minimal next action:** Hard restart OpenCode (kill PID + start fresh), verify
plugin loaded without errors, trigger two same-ms handoff writes and confirm
two distinct archive files (UUID suffix visible in handoffs/archive/), check
handoffs/ directory for any "unknown.json" or "unidentified-session.json" files.

---

### Rank 2: DIA-206 ai-specialist Systemic Empty-Return Failure

**Risk:** ai-specialist lane returns EMPTY results 3+ consecutive times,
blocking research and config-analysis workflows. Root cause not diagnosed.

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-206-ai-specialist-lane-systemic-empty-return-failure.md
- .opencode/memory/failures.md: "DIA-206 (2026-08-17): ai-specialist lane
  returned EMPTY 3x consecutive... systemic provider/endpoint issue, NOT
  lane-specific"
- ana026 section 1.1: "DIA-206... No: systemic cause not diagnosed, workaround
  only"

**Impact:** HIGH. Blocks DIA-187 (OMO 2.2.14 update evaluation), DIA-191
(context-usage calibration), and other research tasks that route to ai-specialist.

**Confidence:** HIGH. Multiple incidents documented (DIA-206, DIA-191 Phase-1,
ai--3 fabricated review). Workaround (route to @coder) succeeds, confirming
the issue is lane-specific, not content-specific.

**Freshness:** FRESH. DIA-206 filed 2026-08-17, still OPEN. Most recent
ai-specialist empty-return incident.

**Dependencies:** DIA-213 (orchestrator scope limitation) may provide
architectural context for lane-routing decisions.

**Minimal next action:** Dispatch @ai-specialist with a minimal read-only task
(e.g., "read .opencode/opencode.jsonc and report the model for orchestrator").
If EMPTY, dispatch @coder with same task to confirm lane-specific failure.
Capture provider/endpoint error logs from registry.jsonl.

---

### Rank 3: DIA-213 Orchestrator Scope Limitation

**Risk:** Orchestrator makes content decisions (code analysis, config analysis)
instead of delegating to specialized agents. Violates AGENTS.md section 2
(architecture-first workflow) and DIA-097 (orchestrator role = delegation +
workflow decisions only).

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-213-orchestrator-scope-limitation.md
- AGENTS.md section 2.2: "Pre-flight: Read relevant .sdd/ documents"
- .opencode/oh-my-opencode-slim/orchestrator_append.md: orchestrator prompt
  instructs delegation-only

**Impact:** HIGH. Orchestrator context window fills with content analysis,
triggering premature SELF-RERUN (DIA-191) and losing campaign-critical context
(handoff prognosis, cycle state). Token waste and reliability degradation.

**Confidence:** MEDIUM. Prompt-level enforcement exists (orchestrator_append.md),
but runtime compliance is procedural, not mechanical. No plugin-level gate
prevents orchestrator from reading repo files.

**Freshness:** FRESH. DIA-213 filed 2026-08-17, still OPEN. High severity.

**Dependencies:** None. Can be addressed via prompt refinement or plugin-level
read-restriction enforcement.

**Minimal next action:** Review orchestrator_append.md for explicit read-
restriction language. If absent, add: "You are FORBIDDEN from reading repo
files except .opencode/session/*, docs/dev-infra-audit/NEXT-RUN.md, AGENTS.md,
.opencode/practice-protected.md. All codebase knowledge comes from delegated
agents."

---

### Rank 4: DIA-234 Datetime-Based Ticket IDs and Human-Readable Mentions

**Risk:** Sequential ticket IDs (DIA-001 through DIA-234) create merge
conflicts when parallel sessions file tickets. Human-readable mentions
(DIA-NNN 'slug') are documented in AGENTS.md but not mechanically enforced.

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-234-datetime-based-ticket-ids-and-human-readable-mentions.md
- AGENTS.md section 2.3: "Ticket reference format: always quote ID +
  human-readable slug"
- scripts/tickets: current implementation uses sequential IDs

**Impact:** MEDIUM. Parallel sessions filing tickets simultaneously can produce
ID collisions. Human-readable mentions improve ticket navigation but drift is
possible without mechanical enforcement.

**Confidence:** HIGH. Problem is well-understood (sequential ID collision under
parallelism). Solution is defined (datetime-based IDs DIA-YYMMDD-XXXX).

**Freshness:** FRESH. DIA-234 filed 2026-08-18, still OPEN. Major severity.

**Dependencies:** DIA-260820-y268 (enforce ticket-status queries via scripts)
may interact if ticket ID format changes affect scripts/tickets parsing.

**Minimal next action:** Update scripts/tickets to generate datetime-based IDs
(DIA-YYMMDD-XXXX format) for new tickets. Preserve sequential ID parsing for
backward compatibility with existing DIA-001 through DIA-234 files.

---

### Rank 5: DIA-189 Terminal Session Identity (Unique Names + Cyrillic Visibility)

**Risk:** Terminal sessions have default names ("New session - <ISO>",
"Terminal N") that are not unique, do not support notification attribution,
and have Cyrillic visibility issues. Guard predicate mismatch: isDefaultLabel
checks "opencode " prefix but runtime defaults are "New session - <ISO>".

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-189-terminal-session-identity.md
- .opencode/CHANGELOG.yaml: 2026-08-17 entry notes "guard predicate mismatch"
- ana023 section "Phase 0 - Handoff completion items": DIA-189 runtime failure
  ROOT-CAUSED

**Impact:** MEDIUM. Non-unique session names make parallel-session debugging
difficult. Cyrillic visibility issues affect developer experience on non-ASCII
terminals.

**Confidence:** HIGH. Root cause identified (guard predicate mismatch). Three
fix-direction options exist (broaden predicate / rename-if-not-suffixed / fix
harness DEFAULT_TITLE).

**Freshness:** FRESH. DIA-189 filed 2026-08-15, still OPEN. Major severity.
Root cause documented in CHANGELOG 2026-08-17.

**Dependencies:** Developer disposition required (choose fix direction from
3 options).

**Minimal next action:** Present 3 fix-direction options to developer for
disposition: (a) broaden isDefaultLabel predicate to match runtime defaults,
(b) rename-if-not-suffixed (only rename if session name matches default
pattern), (c) fix harness DEFAULT_TITLE to match runtime defaults.

---

### Rank 6: DIA-207 WSL Memory/CPU Cap Exhaustion

**Risk:** WSL memory/CPU cap exhaustion causes vsock relay stalls and remote
disconnects. Blocks long-running OpenCode sessions and parallel-lane workflows.

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-207-wsl-memory-cpu-cap-exhaustion.md
- .opencode/memory/failures.md: WSL resource exhaustion incidents

**Impact:** MEDIUM. Session disconnects lose campaign context, force handoff
reconciliation, and waste tokens on session restart.

**Confidence:** MEDIUM. Symptom is clear (vsock stalls, disconnects). Root
cause (WSL resource caps) is inferred from environment, not confirmed via
resource monitoring.

**Freshness:** FRESH. DIA-207 filed 2026-08-17, still OPEN. Major severity.

**Dependencies:** None. Can be addressed via WSL configuration (.wslconfig)
or Docker resource limits.

**Minimal next action:** Check WSL resource usage during a typical OpenCode
session (htop inside WSL, docker stats). If memory > 80% of .wslconfig limit,
increase limit or add swap. Document baseline resource usage in DIA-207 ticket.

---

### Rank 7: DIA-208 cebula Preset Model Swap (deepseek-v4-flash -> mimo-v2.5)

**Risk:** cebula preset uses deepseek-v4-flash, but mimo-v2.5 may offer better
cost/performance. Model swap requires evaluation and restart-verification.

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-208-cebula-preset-model-swap.md
- knowledge/res021-opencode-agent-presets/sources/ (model evaluation sources)
- .opencode/oh-my-opencode-slim.jsonc: cebula preset configuration

**Impact:** MEDIUM. Suboptimal model choice increases token cost or reduces
output quality.

**Confidence:** MEDIUM. Model evaluation sources exist (res021), but no
head-to-head benchmark on project-specific tasks.

**Freshness:** FRESH. DIA-208 filed 2026-08-17, still OPEN. Major severity.

**Dependencies:** DIA-260821-qw29 (Verify opencode-go Hy3 x8 promo) may
provide additional model options.

**Minimal next action:** Run a minimal benchmark task (e.g., "analyze this
config file and produce a 3-line summary") on both deepseek-v4-flash and
mimo-v2.5. Compare token cost, latency, and output quality. Document results
in DIA-208 ticket.

---

### Rank 8: DIA-260820-jlu0 DIA-217 Ticket Gate Chicken-and-Egg

**Risk:** DIA-217 ticket gate (no engineering work without a DIA ticket) creates
chicken-and-egg for meta-tasks (filing a ticket about the ticket system) and
procedural authorizations (capability tokens, memory-manager shelf registration).

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-260820-jlu0-dia-217-ticket-gate-creates-chicken-and-egg.md
- docs/dev-infra-audit/tickets/DIA-217-juxtacrine-ticket-gate-hardening.md
- .opencode/plugins/delegation-observer.ts: ticket gate enforcement logic

**Impact:** MEDIUM. Meta-tasks (ticket system improvements, procedural
authorizations) are blocked by the ticket gate they seek to modify.

**Confidence:** HIGH. Problem is well-understood (self-referential gate).
Solution is defined (capability tokens for bootstrap operations).

**Freshness:** FRESH. DIA-260820-jlu0 filed 2026-08-20, still OPEN. Major
severity.

**Dependencies:** None. Can be addressed via capability token expansion or
gate exemption list.

**Minimal next action:** Review capability token scope (mint_capability tool).
If "ticket-creation" scope exists, document its use for meta-tasks. If absent,
add it. Update DIA-217 ticket gate logic to exempt capability-token-bearing
dispatches.

---

### Rank 9: OpenSpec Task/Status Drift (6 Changes with 0% Completion)

**Risk:** 6 OpenSpec changes have non-zero task counts but 0% completion
(batch-d-infra-hardening 0/10, batch-d-parallel-coders 0/13, omo-self-sufficiency
0/24, ssh-agent-forward-opencode 0/12, test-suite-audit-fixes 0/9,
worktree-branch-cleanup 0/7). This indicates either abandoned work, work done
outside OpenSpec flow, or tasks.md never populated.

**Evidence paths/citations:**
- openspec/changes/*/tasks.md: 6 files with 0/N completion
- openspec/changes/archive/: only 2 archived changes (2026-08-06, 2026-08-11)
- No archive/ entries for the 6 stale changes

**Impact:** LOW-MEDIUM. Drift does not block current work, but indicates
process breakdown (OpenSpec not used, or used inconsistently).

**Confidence:** MEDIUM. Cannot determine if changes are abandoned or completed
outside OpenSpec without manual investigation.

**Freshness:** STALE. Changes date from 2026-08-06 to 2026-08-18. No recent
activity.

**Dependencies:** None. Can be addressed via change archival or tasks.md update.

**Minimal next action:** For each of the 6 stale changes, determine status:
(a) if work was completed outside OpenSpec, archive the change with a note,
(b) if work was abandoned, archive with "ABANDONED" status, (c) if work is
pending, update tasks.md to reflect actual completion state.

---

### Rank 10: DIA-260820-y268 Enforce Ticket-Status Queries via scripts

**Risk:** README rollup in docs/dev-infra-audit/tickets/README.md is a static
snapshot that can drift from actual ticket state. DIA-260820-y268 seeks to
enforce ticket-status queries via scripts/tickets and deprecate README rollup.

**Evidence paths/citations:**
- docs/dev-infra-audit/tickets/DIA-260820-y268-enforce-ticket-status-queries-via-scripts.md
- AGENTS.md section 6: "Ticket queries via scripts (DIA-260820-y268)"
- scripts/tickets: CLI implementation

**Impact:** LOW. README drift is a documentation issue, not a runtime issue.
Scripts/tickets provides live, filtered, structured output on demand.

**Confidence:** HIGH. Problem is well-understood (static snapshot drift).
Solution is defined (enforce scripts/tickets usage).

**Freshness:** FRESH. DIA-260820-y268 filed 2026-08-20, still OPEN. Medium
severity.

**Dependencies:** None. Can be addressed via AGENTS.md enforcement or
scripts/tickets README regeneration.

**Minimal next action:** Update AGENTS.md section 6 to explicitly state: "When
querying ticket status, use scripts/tickets subcommands. Do NOT read the
docs/dev-infra-audit/tickets/ directory directly. Do NOT rely on README.md for
status." Add a scripts/tickets rollup subcommand to regenerate README.md on
demand.

---

## 5. Evidence and Freshness Caveats

### 5.1 Runtime Verification Gap

Plugin changes (DIA-222/224/225) have hermetic tests but no confirmed live
restart-verification. CHANGELOG.yaml last entry is 2026-08-20 (DIA-260819-97fg),
which does not mention restart-verification of F-1/F-3/D3/D4. This is the #1
priority (Rank 1) because runtime issues will surface as silent failures at
session boundaries.

### 5.2 OpenSpec Drift Uncertainty

Cannot determine if 0/0 OpenSpec changes are abandoned or completed outside
OpenSpec flow without manual investigation. The 6 changes with 0/N completion
are likely abandoned (no archive/ entries, no recent activity), but this is
inferred, not confirmed.

### 5.3 Ticket Ledger Drift

DIA-260820-y268 (enforce ticket-status queries via scripts) is OPEN, indicating
README rollup may still drift from actual state. This analysis used
scripts/tickets for live queries, but the README may show stale counts.

### 5.4 Session-Scoped Evidence

Some failure modes (DIA-206 empty returns, DIA-207 WSL stalls) are runtime
observations not fully captured in commits. Failure logs in registry.jsonl and
messages.jsonl are gitignored and session-scoped, so they are not recoverable
from git history.

### 5.5 Stale Report Claims

Three claims from ana026/ana028/ana029 are contradicted by current source
evidence and excluded from the ranked list (section 3). These claims were
valid at the time of writing (2026-08-17 to 2026-08-18) but have since been
fixed (2026-08-18 to 2026-08-19 per CHANGELOG entries).

---

## 6. Tracking Ticket

DIA-260821-bqy7 'audit repository risks and prioritize unresolved remediation'

---

## 7. Methodology

Sources analyzed:
- .opencode/plugins/delegation-observer.ts (4656 lines, current plugin source)
- .opencode/plugins/__tests__/ (11 test files, including handoff-archive-collision,
  handoff-slot-identity, parallel-handoff)
- docs/dev-infra-audit/tickets/ (199 tickets, 23 OPEN)
- openspec/changes/ (25 changes, 6 with 0/N completion)
- .opencode/CHANGELOG.yaml (last entry 2026-08-20)
- knowledge/ana026-ana030 (prior analysis reports)
- .opencode/memory/failures.md (failure catalog)
- scripts/tickets (live ticket queries)

Reconciliation method: current source/runtime evidence takes priority over
older report claims. Stale claims are explicitly marked and excluded from the
ranked list.
