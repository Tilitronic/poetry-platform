# Further Harness Hardening Workflows

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: knowledge/ana026-agentic-flow-failures, knowledge/ana027-dia-221-experimental-summary, .opencode/memory/failures.md, .opencode/memory/lessons.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Executive Summary

DIA-221 delivered 6 commits, 12 regression tests, and 1,250 lines of code that fixed 2 CRITICAL bugs and added mechanical enforcement for the two highest-frequency failure classes. However, a critical verification gap remains: **the plugin changes (delegation-observer.ts) were never restart-verified live**. Hermetic tests pass in isolation, but runtime behavior under the actual OpenCode process is unconfirmed. This is the #1 priority for the next session.

Additionally, DIA-222 introduced a UUID suffix to archive filenames (F-1 fix) that **breaks the pre-existing `parallel-handoff.test.mjs` ARCHIVE_NAME_RE regex** -- a regression that will surface the moment `make test-harness` runs with Docker daemon up.

This report provides a prioritized workflow plan across immediate (next session), short-term (7 days), and medium-term (30 days) horizons, plus a failure-pattern analysis of how the restart-verify gap emerged and how to prevent it.

---

## 1. Immediate Priorities (Next Session)

### 1.1 Restart-Verify DIA-222/224/225 Plugin Changes Live

**What:** The delegation-observer.ts changes from DIA-222 (F-1/F-3 fixes), DIA-224 (empty-result detection), and DIA-225 (failure cap) have only been verified via hermetic bun tests. They have NOT been loaded into a live OpenCode process and exercised end-to-end.

**Why this is #1 priority:**

- DIA-070 established that TUI restart does NOT load patched plugin code -- only a hard process restart (kill PID + start fresh) does.
- DIA-126 showed that config can look correct on read but differ at runtime (catch-all ordering trap).
- DIA-128 showed that vendored source semantics can diverge from installed npm runtime.
- 5+ prior incidents (DIA-098, DIA-099, DIA-120, DIA-122, DIA-127) had "restart-verify DEFERRED" and some were never verified.

**Verification checklist:**

| Step | Command | Expected |
|------|---------|----------|
| 1. Hard restart | Kill OpenCode PID, start fresh | New PID, new start timestamp |
| 2. Plugin loaded | Check TUI panel or plugin log | delegation-observer loaded, no errors |
| 3. F-1 fix live | Trigger two same-ms handoff writes | Two distinct archive files (UUID suffix visible) |
| 4. F-3 fix live | Check slot identity for pre-dispatch session | No "unknown" in handoffs/ directory |
| 5. D3 empty-result live | Dispatch a lane that returns empty | SILENT_FAILURE row in registry.jsonl |
| 6. D4 failure cap live | Trigger 3 consecutive empty results | failure_cap_reached warning in messages.jsonl |
| 7. C1-C5 tests pass | `make test-harness` | Exit 0, all 12 tests pass |

**Risk if skipped:** The F-1/F-3 fixes could have subtle runtime issues (e.g., randomUUID import path, sessionID availability in fallback chain) that hermetic tests cannot catch. The D3/D4 detection could fire false positives or miss real failures.

### 1.2 Fix parallel-handoff.test.mjs ARCHIVE_NAME_RE Regex

**What:** DIA-222 changed the archive filename format from `${sessionId}.${iso}.json` to `${sessionId}.${iso}.${randomUUID()}.json` (line 1373 of delegation-observer.ts). The pre-existing test at `parallel-handoff.test.mjs` line 178 still expects the OLD format:

```javascript
// CURRENT (broken by DIA-222):
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.json$/

// REQUIRED (matches DIA-222 UUID suffix):
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/
```

**Impact:** When `make test-harness` runs `bun test` inside the container, `parallel-handoff.test.mjs` will FAIL because the archive filename now includes a UUID suffix that the regex does not match. This blocks the entire test-harness gate.

**Fix:** Update the ARCHIVE_NAME_RE regex to include the UUID suffix pattern. The new C1 test (`handoff-archive-collision.test.mjs` line 160) already has the correct regex -- mirror it.

**Additional check:** The test at line 299 (`expect(archiveFiles).toHaveLength(1)`) may also need updating. With the F-1 fix, two same-ms writes now produce TWO archive files (distinct UUIDs), not one. The test scenario writes two terminal handoffs for the same session -- under the OLD code, the second archive replaced the first (collision); under the NEW code, both survive. The test assertion must be updated to expect 2 archive files, not 1.

### 1.3 Run make test-harness with Docker Daemon Up

**What:** `make test-harness` (line 295-297 of Makefile) runs two components:
1. `bash scripts/__tests__/bats-wrapper.sh --filter harness-scenario-replay` (C5 bats tests)
2. `docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'` (C1-C4 bun tests)

**Prerequisites:**
- Docker daemon running (`make up`)
- Dev container running (`poetry-dev` service Up)
- All test files present (5 new test files from DIA-221)

**Expected outcome:** Exit 0, 12 tests pass (2+2+2+3 from C1-C4 bun tests, 3 from C5 bats tests).

**If tests fail:** The parallel-handoff.test.mjs regex fix (1.2) must be applied first. Other failures indicate runtime issues that need investigation.

---

## 2. Short-Term Priorities (Next 7 Days)

### 2.1 Complete Section 10 Validation

**What:** DIA-227 verification evidence mentions "config-compatible" but does not confirm the full section 10 workflow:
- Phase 1: @ai-specialist research (gate consult)
- Phase 6: @ai-auditor independent review
- CHANGELOG.yaml entry

**Why:** AGENTS.md section 2.5 requires the full workflow for any `.opencode/` change. DIA-222/224/225 modified delegation-observer.ts (a plugin under `.opencode/plugins/`), which is within section 10 scope.

**Actions:**
1. Dispatch @ai-auditor for post-implementation review of DIA-222/224/225 plugin changes
2. Append CHANGELOG.yaml entry for DIA-221 (YAML ledger is source of truth per AGENTS.md section 2.5)
3. Validate with `scripts/validate-changelog.sh`
4. Regenerate derived MD with `scripts/changelog-render`

### 2.2 Documentation Updates

**What:** Update AGENTS.md and NEXT-RUN.md to reflect DIA-221 changes.

**AGENTS.md updates:**
- Section 6 (Project Ops Quick Reference): add `make test-harness` to the gates table
- Section 2.3 (Implementation): note that `make test-infra` now includes `test-harness`

**NEXT-RUN.md updates:**
- Add DIA-221 to the implemented tickets list
- Note the new mechanical enforcement (D3 empty-result detection, D4 failure cap)
- Update the test matrix to include `make test-harness`

### 2.3 Monitor D3/D4 in Production

**What:** Observe registry.jsonl and messages.jsonl for SILENT_FAILURE and failure_cap_reached events over the next 7 days.

**Why:** The D3/D4 mechanical enforcement is new. False positives (legitimate empty results flagged as failures) or false negatives (real failures not detected) need to be identified and tuned.

**Tuning parameters:**
- D3: empty-result detection threshold (currently: zero file edits + empty output)
- D4: failure cap cooldown window (currently: 10 minutes, 3 consecutive failures)

**If false positives are frequent:** Relax D3 detection (e.g., require additional signals beyond zero file edits).
**If false negatives occur:** Tighten D3 detection (e.g., add session duration check).

### 2.4 Expand C5 Scenario Replay

**What:** The C5 bats file (67 lines) implements 3 scenarios from the ana026 incident corpus. The design.md estimate was ~150 lines. The implementation may be simplified.

**Why:** More scenarios provide better coverage of the failure classes documented in ana026.

**Candidate scenarios to add:**
1. DIA-206 class: systemic empty returns across multiple lanes (ai-specialist, coder, researcher)
2. DIA-191 class: context estimation overestimate (proxy vs TUI divergence)
3. DIA-130 class: coder-escalated silent failure (empty result after long runtime)

**Verification:** Ensure C5 scenarios exercise the full plugin hook chain (not just file output). The current scenarios may only check file existence, not the registry/messages sidecar emissions.

---

## 3. Medium-Term Priorities (Next 30 Days)

### 3.1 Investigate DIA-206 Root Cause

**What:** DIA-206 (systemic empty returns across ai-specialist, coder, researcher) root cause was not diagnosed. The D3 empty-result detection provides a mechanical safety net, but the provider-level root cause remains unknown.

**Why:** DIA-206 caused 5 empty returns in one day (2026-08-17), blocking the entire section 2.5 workflow when ai-specialist is the gate. The current workaround (route to substitute lane) is reactive, not preventive.

**Investigation approach:**
1. Use `scripts/session-analytics.sh` to analyze DIA-206 sessions
2. Query registry.jsonl for `session_complete` + no `task_success` + no file edits (D1 signal from DIA-099)
3. Check messages.jsonl for endpoint errors or model failures
4. Correlate with provider status pages (if available)

**Outcome:** Either identify the root cause (provider outage, model bug, endpoint issue) and document it, or confirm it's a transient provider issue and establish monitoring for recurrence.

### 3.2 Metrics Dashboard (Deferred by Council)

**What:** A metrics dashboard for harness reliability was excluded by the DIA-221 council consensus. After 30 days of DIA-221 hardening in production, revisit whether the dashboard is needed.

**Metrics to track (if dashboard is built):**
- False-delegation rate (D3 SILENT_FAILURE events per day)
- Failure cap triggers (D4 failure_cap_reached events per day)
- Context estimation accuracy (DIA-191 proxy vs TUI divergence)
- Handoff archive collisions (F-1 fix effectiveness)
- Slot identity "unidentified-session" sentinel hits (F-3 fix effectiveness)

**Decision criteria:** If D3/D4 mechanical enforcement is working well (low false-positive rate, catching real failures), the dashboard becomes lower priority. If incidents continue, the dashboard provides observability for tuning.

### 3.3 Incident Ledger (Deferred by Council)

**What:** A dedicated incident ledger (harness-incidents.md) for tracking harness incidents was excluded by the DIA-221 council consensus. The existing `.opencode/memory/failures.md` and `docs/dev-infra-audit/tickets/` provide ad-hoc incident tracking.

**Decision criteria:** If new harness incidents occur in the next 30 days, create a dedicated ledger. If DIA-221 hardening is effective and incidents decline, the existing ad-hoc tracking is sufficient.

### 3.4 Evolution Cycle Formalization (Deferred by Council)

**What:** A formal evolution cycle (incident -> root cause -> hardening rule -> test -> regression prevention) was not established. The DIA-221 pipeline itself is an informal evolution cycle.

**Recommendation:** Document the DIA-221 pipeline as a reference implementation of the evolution cycle. Use it as a template for future harness hardening.

**DIA-221 pipeline as evolution cycle template:**
1. Research (ana025 + ana026): map the system, catalog incidents
2. Council review: scope to highest-leverage items
3. Spec authoring (openspec-plan): proposal, design, tasks
4. Ticket emission (to-tickets): dependency graph, verification gates
5. Implementation (@coder): incremental verification, commit-level evidence
6. Testing (C1-C5): 3-layer regression suite (S1 bats, S2 bun, S3 scenario replay)
7. Gate wiring (make test-harness -> test-infra): close the testing gap

### 3.5 Context Calibration (Deferred by Council)

**What:** Context estimation accuracy (DIA-191) was not calibrated against real token counts. DIA-191 V2 direct live read (TUI-equivalent) is the best available estimate, but calibration against actual token counts would validate accuracy.

**Decision criteria:** If premature self-rerun incidents occur in the next 30 days, calibrate the context_usage proxy. If DIA-191 V2 is accurate (within 7% of TUI per ana026 section 2.2), calibration is lower priority.

### 3.6 Batch-Dispatch Enforcement Upgrade (Deferred by Council)

**What:** Batch-dispatch enforcement (A1 rule) was not upgraded from advisory (console.warn) to mechanical (error throw). Batch-dispatch violations are lower frequency than empty-result or infinite-retry failures.

**Decision criteria:** If batch-dispatch violations occur in the next 30 days, upgrade A1 to mechanical enforcement. If no violations occur, the advisory level is sufficient.

### 3.7 Handoff Simplification (Deferred by Council)

**What:** Handoff simplification (reducing the complexity of the handoff protocol) was not attempted. The handoff protocol is complex but stable.

**Decision criteria:** If handoff-related incidents occur in the next 30 days, simplify the protocol. If DIA-221 F-1/F-3 fixes stabilize the handoff system, simplification is lower priority.

---

## 4. Failure Pattern Analysis

### 4.1 What Mistake Patterns Led to the Restart-Verify Gap?

**Pattern 1: Hermetic-test-complacency.** DIA-221 produced 12 passing tests (C1-C5), which created a false sense of completeness. The tests validate the plugin logic in isolation (mock `@opencode-ai/plugin`, dynamic import, fresh mkdtemp workspace), but they do NOT validate that the plugin loads correctly into a live OpenCode process, that the runtime event hooks fire as expected, or that the sidecar emissions (registry.jsonl, messages.jsonl) are correct.

**Root cause:** The test suite is hermetic by design (deterministic, isolated, fast), but hermetic tests cannot catch runtime integration issues (plugin loading, event hook wiring, sidecar schema compliance). The DIA-221 spec and implementation focused on test coverage, not runtime verification.

**Pattern 2: Restart-verify deferral habit.** The failures.md and lessons.md documents show a recurring pattern of "restart-verify DEFERRED to next session" across multiple tickets (DIA-098, DIA-099, DIA-120, DIA-122, DIA-127). This deferral is a habit, not a deliberate decision. The orchestrator completes the implementation, sees the hermetic tests pass, and moves to the next task without performing the live verification.

**Root cause:** Restart-verify is not enforced by any mechanical gate. It's a procedural step in the verification checklist, but there's no automated check that blocks completion until restart-verify is done. The orchestrator can skip it without consequence (in the short term), so it gets skipped.

**Pattern 3: Section 10 workflow incompleteness.** DIA-227 verification evidence mentions "config-compatible" but does not confirm the full section 10 workflow (ai-specialist research, ai-auditor review, CHANGELOG.yaml entry). The section 10 workflow is designed to catch exactly this kind of gap (runtime verification, independent review), but it was not fully executed.

**Root cause:** The section 10 workflow is complex (6 phases), and the orchestrator may not be aware of all the required steps. The workflow is documented in AGENTS.md section 2.5, but the documentation is long and easy to miss steps.

### 4.2 What Process Changes Would Prevent This in the Future?

**Recommendation 1: Make restart-verify a HARD GATE in the section 10 workflow.**

**Current state:** Restart-verify is a procedural step in the verification checklist (Phase 5 of section 10 workflow). It can be skipped without blocking completion.

**Proposed change:** Add a mechanical gate that blocks ticket completion until restart-verify is confirmed. The gate could be:
- A plugin hook that checks for a "restart-verify-complete" marker in registry.jsonl before allowing ticket status to flip to DONE
- A script that validates the plugin is loaded and the runtime event hooks are firing (e.g., check TUI panel version, check registry.jsonl for recent plugin emissions)
- A checklist item in the ticket template that requires explicit confirmation (e.g., "restart-verify: [ ] done, [ ] skipped with reason")

**Recommendation 2: Add a "runtime-verification" test layer (S4).**

**Current state:** The test suite has 3 layers: S1 (bats, hermetic shell tests), S2 (bun, hermetic plugin tests), S3 (bats, scenario replay inside container). All 3 layers are hermetic or semi-hermetic.

**Proposed change:** Add an S4 layer that runs inside a live OpenCode process and validates the plugin is loaded and the event hooks are firing. This could be:
- A smoke test that dispatches a minimal lane and checks registry.jsonl for the expected plugin emissions
- A TUI panel check that validates the plugin version matches the expected version
- A sidecar schema validation that checks registry.jsonl and messages.jsonl for correct plugin emissions

**Recommendation 3: Enforce DIA-175 instance separation via ticket metadata.**

**Current state:** DIA-175 requires RED test-writing and GREEN implementation to be dispatched to DIFFERENT coder instances. The DIA-221 implementation did not enforce this (T2 tests and T1 fixes were implemented in the same session).

**Proposed change:** Add session_id and lane_id fields to ticket frontmatter. Add a validation script that checks RED/GREEN separation for each ticket. This makes the separation enforceable, not just procedural.

**Recommendation 4: Automate verification evidence capture.**

**Current state:** Verification evidence (test results, grep checks, exit codes) is manually entered into ticket frontmatter. This is error-prone and easy to skip.

**Proposed change:** Add a `verification-evidence` field to ticket frontmatter that captures test results, grep checks, and exit codes automatically. This could be:
- A script that runs the tests and captures the output
- A plugin hook that captures the verification evidence at commit time
- A CI check that validates the verification evidence is present and correct

### 4.3 Should Restart-Verify Be a HARD GATE in the Section 10 Workflow?

**Recommendation: YES.**

**Rationale:**

1. **Restart-verify has caught real bugs.** DIA-070 (TUI restart did not load patched plugin code), DIA-126 (config looked correct but runtime differed), DIA-127 (OMO panel showed stale version), DIA-128 (vendored source semantics diverged from installed npm runtime). All of these were caught by restart-verify, not by hermetic tests.

2. **Hermetic tests cannot catch runtime integration issues.** Hermetic tests validate the plugin logic in isolation, but they cannot validate that the plugin loads correctly into a live OpenCode process, that the runtime event hooks fire as expected, or that the sidecar emissions are correct. Runtime verification is a different validation layer.

3. **Restart-verify deferral is a recurring pattern.** The failures.md and lessons.md documents show 5+ incidents where restart-verify was deferred and the gap persisted. This is a habit, not a deliberate decision. A mechanical gate would break the habit.

4. **The cost of restart-verify is low.** A hard process restart (kill PID + start fresh) takes ~30 seconds. The verification checklist (check TUI panel, check registry.jsonl, check messages.jsonl) takes ~2 minutes. Total cost: ~3 minutes per change. This is a small price to pay for catching runtime integration issues before they cause incidents.

5. **The cost of skipping restart-verify is high.** DIA-127 was CLOSED with an inference-based restart-verify PASS, yet the developer reported the OMO panel STILL showed the stale version the next day. DIA-126 agents had NO bash tool despite config allow grants, stalling for hours. These incidents cost 30+ minutes of wasted lane time and required emergency recovery.

**Implementation:**

Add a "restart-verify" gate to the section 10 workflow (AGENTS.md section 2.5, Phase 5 validation):

```markdown
### Phase 5 -- Validate

After implementation:

1. **Review the full diff** of all changed files before restarting. Check for YAML/JSON syntax errors, missing commas, and unintended changes.
2. **Restart OpenCode** (config changes take effect on next run).
3. **HARD GATE: Restart-verify.** Perform a hard process restart (kill PID + start fresh) and verify:
   - [ ] New PID, new start timestamp (confirm hard restart, not TUI restart)
   - [ ] Plugin loaded (check TUI panel or plugin log, no errors)
   - [ ] Runtime event hooks firing (check registry.jsonl for recent plugin emissions)
   - [ ] Sidecar schema compliance (check registry.jsonl and messages.jsonl for correct plugin emissions)
   - [ ] Test suite passes (`make test-harness` or `make test-config` as appropriate)
4. **Verify the change works as intended** -- test the specific behavior it was meant to affect:
   - For model changes: run a representative task with the new model
   - For permission changes: test that the deny/ask/allow behavior works correctly
   - For skill changes: invoke the skill and verify it activates as expected
   - For agent definition changes: dispatch the agent on a minimal test task
   - For config changes: verify the expected config values are loaded
   - For plugin changes: verify the plugin loads and the event hooks fire (check TUI panel, registry.jsonl, messages.jsonl)
   - Document the test and its result.
5. **Check for side effects** -- did the change break anything else? Test adjacent functionality that could be affected.
6. **Rollback if needed** -- revert using `git diff` (for tracked files) or manual restore (for untracked config). Return to Phase 2.
```

**Enforcement:** The restart-verify gate is enforced by the ticket validation script (`scripts/validate-tickets.sh`), which checks for a "restart-verify: done" marker in the ticket frontmatter before allowing the ticket status to flip to DONE. If the marker is absent, the script fails with an error message pointing to the restart-verify checklist.

---

## 5. Summary and Recommendations

### 5.1 Immediate (Next Session)

1. **Restart-verify DIA-222/224/225 plugin changes live** (hard process restart, check TUI panel, check registry.jsonl, check messages.jsonl, verify F-1/F-3/D3/D4 behavior)
2. **Fix parallel-handoff.test.mjs ARCHIVE_NAME_RE regex** (update to match UUID suffix, update archive count assertion from 1 to 2)
3. **Run `make test-harness` with Docker daemon up** (verify C1-C5 tests pass in-container)

### 5.2 Short-Term (Next 7 Days)

4. **Complete section 10 validation** (dispatch @ai-auditor, append CHANGELOG.yaml entry, validate with scripts)
5. **Update AGENTS.md and NEXT-RUN.md** (add `make test-harness` to gates table, note DIA-221 implementation)
6. **Monitor D3/D4 in production** (observe registry.jsonl and messages.jsonl for SILENT_FAILURE and failure_cap_reached events, tune if needed)
7. **Expand C5 scenario replay** (add DIA-206, DIA-191, DIA-130 scenarios, verify full plugin hook chain)

### 5.3 Medium-Term (Next 30 Days)

8. **Investigate DIA-206 root cause** (use session-analytics.sh, query registry.jsonl, correlate with provider status)
9. **Revisit excluded items** (metrics dashboard, incident ledger, evolution cycle, context calibration, batch-dispatch enforcement, handoff simplification)
10. **Make restart-verify a HARD GATE** (add mechanical enforcement to section 10 workflow, add ticket validation script check)

### 5.4 Process Changes to Prevent Restart-Verify Gap

11. **Add a "runtime-verification" test layer (S4)** (smoke test inside live OpenCode process)
12. **Enforce DIA-175 instance separation via ticket metadata** (session_id, lane_id fields, validation script)
13. **Automate verification evidence capture** (script that runs tests and captures output, plugin hook that captures evidence at commit time)

---

## 6. Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| R1: Plugin changes have runtime issues not caught by hermetic tests | High | Medium | Restart-verify (immediate priority) |
| R2: parallel-handoff.test.mjs blocks make test-harness | High | Certain | Fix ARCHIVE_NAME_RE regex (immediate priority) |
| R3: D3/D4 false positives cause noise | Medium | Possible | Monitor and tune (short-term priority) |
| R4: D3/D4 false negatives miss real failures | Medium | Possible | Monitor and tune (short-term priority) |
| R5: DIA-206 root cause remains unknown, workaround only | Medium | Certain | Investigate root cause (medium-term priority) |
| R6: Restart-verify gap recurs in future changes | High | Likely | Make restart-verify a HARD GATE (medium-term priority) |

---

## 7. Conclusion

DIA-221 was a successful experimental pipeline that delivered significant harness hardening. However, the restart-verify gap is a critical verification defect that must be addressed immediately. The parallel-handoff.test.mjs regex break is a known regression that will block `make test-harness` until fixed.

The failure pattern analysis reveals that restart-verify deferral is a recurring habit, not a deliberate decision. Making restart-verify a HARD GATE in the section 10 workflow would break the habit and prevent future gaps.

The recommended workflow (immediate, short-term, medium-term) provides a clear roadmap for completing the DIA-221 hardening effort and preventing similar gaps in the future. The immediate priorities are restart-verify, regex fix, and test-harness validation. The short-term priorities are section 10 completion, documentation updates, and D3/D4 monitoring. The medium-term priorities are DIA-206 root cause investigation, excluded item revisitation, and restart-verify gate enforcement.

The system that manages the system is now tested -- but it is not yet live-verified. That is the next step.

---

**End of report.**
