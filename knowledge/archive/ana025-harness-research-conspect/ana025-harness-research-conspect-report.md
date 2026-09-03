# Harness System Research Conspect (DIA-221 Foundation)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: session-id ses_fffa0d549ffe0VtK3jOy5kI0Lz
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## 1. System Map

The orchestration harness is a **6-layer stack** that manages AI agent delegation,
session continuity, and verification within the poetry-platform monorepo. Each layer
has distinct ownership, failure modes, and enforcement mechanisms.

```
Layer 6: Process Rules (AGENTS.md, NEXT-RUN.md, practice-protected.md)
    |
Layer 5: Observability (registry.jsonl, messages.jsonl, ticker.json, boot.json)
    |
Layer 4: Verification Gates (test-config, test-shell, pre-commit, pre-push)
    |
Layer 3: Plugins (delegation-observer.ts, needs-input-observer.ts)
    |
Layer 2: Agent Config (opencode.jsonc, oh-my-opencode-slim.jsonc, agents/*.md)
    |
Layer 1: OpenCode Runtime (task(), session lifecycle, compaction, permissions)
```

### 1.1 Component Inventory

```
+------------------------------------------------------------------+
|                    ORCHESTRATION HARNESS MAP                       |
+------------------------------------------------------------------+
|                                                                    |
|  CONFIG LAYER                                                      |
|  +-- opencode.jsonc ........... permissions, agents, plugins       |
|  +-- oh-my-opencode-slim.jsonc  presets, models, prompts           |
|  +-- agents/*.md .............. 7 agent definition files           |
|  +-- practice-protected.md .... 8 protected zones                  |
|  +-- AGENTS.md ................ 11 sections, project standards     |
|                                                                    |
|  PLUGIN LAYER                                                      |
|  +-- delegation-observer.ts ... ~2000 lines, 5 hooks              |
|  |   +-- registry.jsonl ....... delegation lifecycle              |
|  |   +-- messages.jsonl ....... semantic event log                |
|  |   +-- boot.json ............ deterministic boot evidence       |
|  |   +-- handoffs/*.json ...... per-session handoff slots         |
|  |   +-- active.json .......... workflow state pointer            |
|  |   +-- health.json .......... agent health scores               |
|  |   +-- gate-tokens/ ......... section-10 gate tokens            |
|  +-- needs-input-observer.ts .. ~1300 lines, ticker + notify      |
|      +-- ticker.json .......... waiting-session state             |
|                                                                    |
|  OBSERVABILITY LAYER                                               |
|  +-- registry.jsonl ........... ~4K+ rows, append-only            |
|  +-- messages.jsonl ........... canonical event log               |
|  +-- messages.md .............. derived view (rendered)           |
|  +-- ticker.json/ticker.md .... waiting sessions                  |
|  +-- boot.json ................ process-start evidence            |
|  +-- log_decision tool ........ semantic events                   |
|  +-- context_usage tool ....... context window estimation         |
|                                                                    |
|  VERIFICATION LAYER                                                |
|  +-- Makefile (14 targets)                                         |
|  |   +-- test-config (15 sub-checks)                              |
|  |   +-- test-shell (bats, Docker mocked)                         |
|  |   +-- test-infra (Docker smoke + pytest)                       |
|  +-- scripts/ (44 scripts)                                         |
|  |   +-- validate-*.sh (8 validators)                             |
|  |   +-- verify-pre-commit.sh                                     |
|  |   +-- verify-pre-push.sh                                       |
|  +-- .husky/ (pre-commit, pre-push)                               |
|                                                                    |
|  KNOWLEDGE LAYER                                                   |
|  +-- memory-shelf.yaml ........ 33 conspects, 24+ analyses        |
|  +-- memory/ .................. adr, lessons, failures, repo      |
|  +-- knowledge/ ............... 72 artifact directories           |
|  +-- .sdd/ .................... 3 architecture docs               |
|  +-- learnings/ ............... external patterns                 |
|                                                                    |
|  PROCESS LAYER                                                     |
|  +-- NEXT-RUN.md ............. orchestrator operating manual      |
|  +-- openspec/ ................ spec artifacts                     |
|  +-- tickets/ ................. DIA ledger (~220+ tickets)        |
|  +-- CHANGELOG.yaml ........... config change ledger              |
+------------------------------------------------------------------+
```

### 1.2 Agent Topology

```
                    +-----------------+
                    |  ORCHESTRATOR   |
                    | (delegation-only|
                    |  read-restricted)|
                    +--------+--------+
                             |
            +----------------+----------------+
            |                |                |
    +-------v------+  +------v-------+  +-----v--------+
    | READ-ONLY    |  | ARTIFACT     |  | EXECUTOR     |
    | LANES        |  | PRODUCERS    |  | LANES        |
    +--------------+  +--------------+  +--------------+
    | architector  |  | analyzer     |  | coder        |
    | ai-specialist|  | conspecter   |  | coder-esc.   |
    | ai-auditor   |  | researcher   |  | designer     |
    | code-navigator| | openspec-plan|  | code-executor|
    | observer     |  | memory-mgr   |  |              |
    | reviewer     |  | resource-mgr |  |              |
    +--------------+  +--------------+  +--------------+
    
    ESCALATED (hidden, orchestrator-only, one-shot):
    +-----------------+  +---------------------+
    | coder-escalated |  | analyzer-escalated  |
    | (Kimi K3)       |  | (GPT-5.6 Luna)      |
    +-----------------+  +---------------------+
```

### 1.3 Data Flow: Dispatch Lifecycle

```
Orchestrator                 Plugin                    Subagent
    |                          |                          |
    |-- task(agent, prompt) -->|                          |
    |                          |-- registry: INVOKED ---->|
    |                          |-- session.created ------>|
    |                          |-- registry: RUNNING ---->|
    |                          |                          |-- work...
    |                          |<-- session.idle ---------|
    |                          |-- registry: COMPLETED ---|
    |<-- task result ----------|                          |
    |                          |                          |
    |-- log_decision --------->|                          |
    |   (handoff/decision)     |-- messages.jsonl row     |
    |                          |                          |
```

---

## 2. Contracts

### 2.1 Permission Contracts (3 Tiers)

| Tier | Edit | Bash | Task | Examples |
|------|------|------|------|----------|
| **pure-analyst** | deny | deny | deny | architector, reviewer, ai-specialist, ai-auditor |
| **artifact-producer** | knowledge/* | allow (scoped) | deny | analyzer, conspecter, researcher, openspec-plan |
| **executor** | allow | allow | allow | coder, designer |

**Enforcement:** OpenCode permission system (opencode.jsonc `agent.*.permission`).
Plugin-level enforcement: delegation-observer A1 batch check (advisory, not blocking).

### 2.2 Output Contracts (M1/M2)

Every analyzer report MUST carry:
```html
<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: <finding|recommendation|risk>
evidence-source: <path|session-id>
confidence: High|Medium|Low
-->
```

Every conspect MUST carry:
```html
<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: N
phase-a-failures: N
-->
```

**Enforcement:** `scripts/validate-output-contracts.sh` (wired into `make test-config`).

### 2.3 Handoff Protocol Contract

```
Producer Session                    Successor Session
     |                                    |
     |-- log_decision(handoff) -->        |
     |   plugin writes slot               |
     |   + checksum                       |
     |   + archive prior                  |
     |                                    |
     |   Session ends                     |-- read active.json
     |                                    |-- resolve slot
     |                                    |-- present prognosis
     |                                    |-- developer approves
     |                                    |-- lane-0 checksum verify
     |                                    |-- begin work
```

**Invariants:**
- Handoff written BEFORE final summary (DIA-124)
- Checksum is SHA256 of canonical JSON prognosis (DIA-061)
- Plugin is SOLE writer of handoff files (DIA-120)
- Re-read checksum at comparison time, never memorize (DIA-120)

### 2.4 Ticket Gate Contract (DIA-063)

Every dispatch MUST correlate to an open ticket via:
1. **Path 1:** Explicit DIA-id in dispatch text -> OPEN ticket with that id (STRICT tri-state, DIA-076)
2. **Path 2:** Session-owned open ticket (any recency)
3. **Path 3:** Recent (<=24h) open ticket with keyword correlation

**Enforcement:** delegation-observer.ts `evaluateTicketCorrelation()` in `tool.execute.before`.

### 2.5 Batch-Dispatch Contract (A1, DIA-144/DIA-172)

Approved parallel batches:
- **(A)** Read-only fan-out (all agents in READ_ONLY_LANES)
- **(B)** Single-writer + readers (at most 1 WRITER_LANES agent)
- **(C)** Post-fix review (reviewer + ai-auditor pair)
- **(D)** Parallel coders (each with distinct WORKTREE assertion)

**Enforcement:** delegation-observer.ts `isSafeTaskBatch()` (advisory warning, not blocking).

---

## 3. Invariants

### 3.1 Structural Invariants

| ID | Invariant | Enforcement | Verified By |
|----|-----------|-------------|-------------|
| I1 | Orchestrator never edits code | opencode.jsonc permission | audit-agent-tool-coverage.sh |
| I2 | Memory-shelf has single writer (memory-manager) | opencode.jsonc edit scope | DIA-143 |
| I3 | Registry is append-only | Plugin design (appendFileSync) | jsonl-stats.sh |
| I4 | Messages.jsonl is sole canonical log | Plugin sole-writer | jsonl-cross-check.sh |
| I5 | Agent names are in lockstep across 4 sources | validate-agent-names.sh | make test-config |
| I6 | Config changes route through section 10 | Gate token mechanism | delegation-observer.ts |
| I7 | Pre-commit blocks commits without Docker | verify-pre-commit.sh | husky hook |
| I8 | Handoff checksum is plugin-computed | DIA-120 | validate-handoff.sh |

### 3.2 Behavioral Invariants

| ID | Invariant | Risk on Violation |
|----|-----------|-------------------|
| B1 | Pure-dispatch: task() is sole tool call | False-delegation (ana005) |
| B2 | RED/GREEN instance separation (DIA-175) | No independent verification |
| B3 | Same-session fix loops (DIA-175) | Context loss, drift |
| B4 | Escalated lanes are one-shot no-retry | Quota exhaustion (Kimi K3 490/mo) |
| B5 | Verify-before-re-dispatch on empty results | Double-apply / clobber |
| B6 | Re-read handoff checksum at comparison time | False mismatch escalation |
| B7 | Catch-all deny FIRST in permission maps | Tool hidden from agent (DIA-126) |

### 3.3 Status Transition Invariant (C3/S2)

```
PENDING -> INVOKED -> RUNNING -> COMPLETED | FAILED
```

Backward transitions (COMPLETED -> RUNNING) are logged as anomalies.
Forward-only enforced by delegation-observer.ts.

---

## 4. Known Gaps

### 4.1 Critical Gaps (Harness Self-Testing)

| Gap | Impact | Current State |
|-----|--------|---------------|
| **G1: No harness regression tests** | Harness bugs caught only retrospectively | Zero automated tests for orchestrator workflows |
| **G2: No incident ledger** | Repeated failure patterns not tracked systematically | failures.md is ad-hoc, not structured |
| **G3: Context estimation is proxy-based** | Premature self-rerun or delayed rerun | context_usage uses registry activity signals, not token-accurate |
| **G4: Batch-dispatch check is advisory** | Unsafe batches can execute | Warning only, no blocking |
| **G5: No empty-result detection at plugin level** | Silent failures require manual discovery | A3 retroactive check only on session.idle |

### 4.2 Major Gaps

| Gap | Impact | Current State |
|-----|--------|---------------|
| **G6: Handoff archive collision** (same-ms) | Silent prognosis loss | DIA-085 F-1 CRITICAL finding, not yet fixed |
| **G7: Slot identity "unknown" fallback** | Parallel session clobber | DIA-085 F-3 CRITICAL finding, not yet fixed |
| **G8: No formal contract for dispatch payload** | Agents interpret prompts inconsistently | Prompt text is the contract, no schema |
| **G9: Escalation trigger detection is manual** | Orchestrator must recognize failure patterns | No automated crisis detection (C1-C5 are prompt rules) |
| **G10: Model fallback is OMO-only** | Native OpenCode has no fallback | Model-array fallback is OMO runtime extension (res029) |

### 4.3 Minor Gaps

| Gap | Impact | Current State |
|-----|--------|---------------|
| **G11: validate-handoff.sh uses GNU find** | Broken on BSD/macOS hosts | DIA-085 F-2 MAJOR |
| **G12: No quota monitoring automation** | Quota exhaustion discovered after failure | model-registry.yaml exists but no automated guard |
| **G13: messages.jsonl grows unbounded** | Performance degradation at scale | Deferred to ~10K row threshold (not yet reached) |
| **G14: No circuit breaker for tool errors** | Repeated tool failures waste context | DIA-218 circuit breaker exists in plugin but untested |

---

## 5. Failure Modes (Catalogued)

### 5.1 Silent Failures (Most Dangerous)

| ID | Failure Mode | Detection | Recovery |
|----|-------------|-----------|----------|
| F1 | False delegation (task() dropped when batched with edit()) | ana005: 25.6% gap rate | Pure-dispatch rule (A1) |
| F2 | Empty task result (silent failure) | A3 retroactive check | Verify-first, then resume or re-dispatch |
| F3 | Snip-wrapper loop (identical command repeated) | doom_loop deny + anti-loop | Plugin removal (DIA-092) + deny rules |
| F4 | Config permission looks correct but runtime differs | Runtime tool manifest check | verify-first after permission changes |
| F5 | Stale handoff checksum comparison | Lane-0 checksum delegation | Re-read at comparison time (DIA-120) |
| F6 | Plugin trigger bug (non-terminal handoff overwrites) | Manual discovery | Use event_type='decision' for non-terminal |

### 5.2 Context/Resource Failures

| ID | Failure Mode | Detection | Recovery |
|----|-------------|-----------|----------|
| F7 | Premature self-rerun (stale model window) | context_usage tool | Verify model windows against models.dev |
| F8 | Step-cap exhaustion mid-protocol | MAXIMUM STEPS message | Split lanes, narrow scope |
| F9 | Quota exhaustion (Kimi K3 490/mo) | model-registry.yaml check | Fallback chain, wait_for_user |
| F10 | Context compaction loses campaign state | Manual recognition | Handoff file + 15% threshold |

### 5.3 Coordination Failures

| ID | Failure Mode | Detection | Recovery |
|----|-------------|-----------|----------|
| F11 | Resume without task_id (fresh session, no context) | Empty result from "resumed" session | Always pass task_id for resume |
| F12 | Parallel handoff clobber (same-ms archive) | DIA-085 F-1 review finding | Fix pending (UUID disambiguation) |
| F13 | Container-created files root:root on host | Write-denied error | Copy-replace to dev user |
| F14 | Recursion fork-bomb (gate scripts) | /proc inspection | Re-entrancy guard (env-flag) |

---

## 6. Verification Surface

### 6.1 Current Gate Matrix

```
+---------------------------+----------+----------+---------+
| Gate                      | Host     | Container| CI      |
+---------------------------+----------+----------+---------+
| test-config (15 checks)   | YES      | -        | -       |
| test-shell (bats)         | YES      | -        | -       |
| test-infra (Docker)       | -        | YES      | -       |
| test-python (pytest)      | -        | YES      | -       |
| verify-pre-commit         | -        | YES      | -       |
| verify-pre-push           | -        | YES      | -       |
| audit-python (pip-audit)  | YES      | -        | -       |
| eval-lite (20-task sweep) | YES      | YES*     | -       |
+---------------------------+----------+----------+---------+
* Tasks requiring container skipped with WARN when down
```

### 6.2 What Is NOT Tested

| Missing Test | Risk | Effort |
|-------------|------|--------|
| Handoff protocol end-to-end | Silent state loss | Medium |
| Batch-dispatch rule enforcement | Unsafe parallel writes | Low |
| Empty-result detection | Silent failures | Low |
| Ticket gate correlation | Untracked work | Medium |
| Context estimation accuracy | Premature/late rerun | High |
| Agent permission enforcement | Tool leakage | Low |
| Checksum tampering detection | Handoff integrity | Medium |
| Crisis detection (C1-C5) | Unbounded failure loops | High |

---

## 7. Recommendations (Priority-Ordered)

### P0: Establish Harness Regression Test Suite

**What:** Create `scripts/__tests__/harness-contracts.bats` (or `.test.mjs`) testing:
1. Batch-dispatch classification (isSafeTaskBatch) with known inputs
2. Ticket correlation (evaluateTicketCorrelation) with edge cases
3. Status transition guard (forward-only enforcement)
4. Output contract validation (ANALYZER/CONSPECTER headers)
5. Handoff checksum computation (canonical JSON + SHA256)

**Why:** The harness has zero automated self-tests. Every failure is caught
retrospectively, often by the developer. This is the single highest-leverage
improvement.

**Effort:** 2-3 days for initial suite.

### P1: Structured Incident Ledger

**What:** Replace ad-hoc failures.md with a structured ledger:
```yaml
- id: HINC-NNN
  date: YYYY-MM-DD
  failure_mode: F1|F2|...
  detection_method: manual|automated|gate
  root_cause: ...
  fix: ...
  regression_test: scripts/__tests__/...
  status: open|closed
```

**Why:** failures.md has 374 lines of valuable data but no structure for
pattern detection, metrics, or regression tracking.

**Effort:** 1 day for schema + migration of existing entries.

### P2: Empty-Result Detection at Plugin Level

**What:** Add to delegation-observer.ts `session.idle` handler:
- If task result is empty/whitespace AND no files were touched -> SILENT_FAILURE
- Log to registry.jsonl with dispatch_state: SILENT_FAILURE
- Alert via ticker.json (needs-input-observer)

**Why:** Empty results are the most common silent failure (F2, F6, DIA-130).
Current detection is manual (orchestrator must notice).

**Effort:** 0.5 day.

### P3: Context Estimation Calibration

**What:** Use DIA-191's context_usage tool data to build a calibration table:
- Map delegation count + avg tokens/delegation to actual context usage
- Validate against model's real context window (models.dev, not in-repo table)
- Adjust 15%/25% thresholds based on empirical data

**Why:** ana025-context-usage-calibration already exists; this operationalizes it.

**Effort:** 1 day.

### P4: Handoff Archive Collision Fix

**What:** Fix DIA-085 F-1 and F-3:
- F-1: Add UUID suffix to archiveName (or monotonic counter)
- F-3: Use actual sessionId as last-resort slot identity (not "unknown")

**Why:** CRITICAL findings that silently destroy handoff prognoses.

**Effort:** 0.5 day.

### P5: Batch-Dispatch Enforcement Upgrade

**What:** Change A1 batch-dispatch check from advisory (console.warn) to
blocking (throw error preventing the batch).

**Why:** Advisory warnings are easily missed. Unsafe batches cause
false-delegation incidents (ana005).

**Effort:** 0.5 day. Risk: may block legitimate workflows during transition.

### P6: Harness Metrics Dashboard

**What:** Extend `scripts/session-analytics.sh` with harness-specific views:
- False-delegation rate (registry rows with dispatch_state: SILENT_FAILURE)
- Empty-result rate (task completions with empty output)
- Handoff checksum match rate
- Ticket gate block/pass ratio
- Context estimation accuracy (predicted vs actual rerun triggers)

**Why:** "You can't improve what you can't measure." Current observability
covers agent costs/tokens but not harness reliability.

**Effort:** 2 days.

### P7: Evolution Cycle Formalization

**What:** Establish the incident -> root cause -> hardening -> test -> prevention
cycle:
1. Incident logged in structured ledger (P1)
2. Root cause analysis (5-Whys in analysis report)
3. Hardening rule (config change via section 10 or plugin patch)
4. Regression test added to harness suite (P0)
5. Metrics updated (P6)

**Why:** This is the "evolutional improvement loop" DIA-221 calls for.

**Effort:** Ongoing process, not a one-time implementation.

---

## 8. Architecture Decision Records (Proposed)

### ADR-1: Harness Tests Live Alongside Plugin Tests

- **Status:** Proposed
- **Context:** Harness testing could live in scripts/__tests__/ (bats), in
  plugin __tests__/ (vitest), or in a new directory.
- **Decision:** Harness contract tests live in `scripts/__tests__/` alongside
  existing infrastructure tests. Plugin unit tests stay in
  `.opencode/plugins/__tests__/`. Integration tests (requiring running OpenCode)
  live in `scripts/__tests__/integration/`.
- **Consequences:** Consistent with existing test infrastructure (bats wrapper,
  Makefile targets). No new test framework needed.
- **Alternatives Considered:** New `tests/harness/` directory (rejected: splits
  test infrastructure); plugin-internal only (rejected: misses cross-plugin
  interactions).

### ADR-2: Incident Ledger is YAML, Not Markdown

- **Status:** Proposed
- **Context:** failures.md is 374 lines of unstructured markdown. A structured
  ledger enables pattern detection and metrics.
- **Decision:** New ledger at `.opencode/memory/harness-incidents.yaml` with
  schema validated by `scripts/validate-harness-incidents.sh`.
- **Consequences:** Machine-parseable for metrics (P6). Existing failures.md
  preserved as historical record.
- **Alternatives Considered:** JSON (rejected: less human-readable); SQLite
  (rejected: violates plain-text source-of-truth constraint DIA-136).

---

## 9. Dependency Graph

```
DIA-221 (harness testing)
    |
    +-- depends on --> DIA-182 (session-analytics.sh) [DONE]
    +-- depends on --> DIA-191 (context_usage estimator) [DONE]
    |
    +-- enables ----> P0 (regression tests)
    +-- enables ----> P1 (incident ledger)
    +-- enables ----> P6 (metrics dashboard)
    +-- enables ----> P7 (evolution cycle)
    
P0 (regression tests)
    |
    +-- tests ------> I1-I8 (structural invariants)
    +-- tests ------> B1-B7 (behavioral invariants)
    +-- prevents ----> F1-F14 (failure modes)

P4 (handoff fix)
    |
    +-- resolves ----> DIA-085 F-1, F-3 (CRITICAL)
    +-- requires ----> section 10 workflow (plugin change)
```

---

## 10. Summary Statistics

| Metric | Value |
|--------|-------|
| Total agent definitions | 22 (7 .md files + 15 opencode.jsonc blocks) |
| Plugin lines of code | ~3,300 (delegation-observer ~2,000 + needs-input-observer ~1,300) |
| Registry rows (approx) | 4,000+ |
| Validation scripts | 8 (validate-*.sh) |
| Makefile test targets | 14 |
| Known failure modes | 14 (catalogued in Section 5) |
| Known gaps | 14 (catalogued in Section 4) |
| Conspects in shelf | 33 |
| Analyses in shelf | 24+ |
| DIA tickets (total) | 220+ |
| Practice-protected zones | 8 |

---

## 11. Conclusion

The harness is a sophisticated, organically-grown system with strong individual
components (permission enforcement, plugin observability, verification gates)
but **zero self-testing capability**. The highest-leverage improvement is
establishing a regression test suite (P0) that codifies the contracts documented
in this report. Combined with a structured incident ledger (P1) and metrics
dashboard (P6), this creates the foundation for the evolutional improvement
loop DIA-221 calls for.

The system's greatest strength is its layered defense-in-depth (4-source agent
name lockstep, multi-path ticket correlation, dual-write handoff with checksum).
Its greatest weakness is that these defenses are verified by human attention,
not automated tests. The recommendations in this report shift verification from
human to mechanical where possible.
