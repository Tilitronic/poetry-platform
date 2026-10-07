# Agentic Flow Failures Analysis

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/memory/failures.md, .opencode/memory/lessons.md, docs/dev-infra-audit/tickets/
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Methodology

Sources analyzed:
- `.opencode/memory/failures.md` (374 lines, 25+ failure entries)
- `.opencode/memory/lessons.md` (1601 lines, 80+ lesson entries)
- `docs/dev-infra-audit/tickets/` (174 tickets, 20+ incident-specific tickets read in full)
- `docs/dev-infra-audit/NEXT-RUN.md` (orchestrator operating manual, 468 lines)
- `registry.jsonl` (161,925 rows) and `messages.jsonl` (160,118 rows) metadata

Every incident below is traceable to at least one committed ticket, failure entry, or lesson record.

---

## 1. Incident Catalog

### 1.1 Silent Delegation / Empty Results

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-130/DIA-132** | 2026-08-13 | coder-escalated (kimi-k3) ran 9.5 min, returned EMPTY result, wrote nothing | Transient model/endpoint failure; no timeout or empty-result detection | `steps: 50` cap on escalated lanes; state-inspection-before-re-dispatch rule | Partial: steps cap verified live; empty-result detection is procedural, not mechanical |
| **DIA-206** | 2026-08-17 | ai-specialist returned EMPTY 3x consecutive; 5 total empty returns across coder+researcher+ai-specialist | Systemic provider/endpoint issue, NOT lane-specific | Route to substitute lane after 3x empty; DIA-099 Variant A2 resume | No: systemic cause not diagnosed, workaround only |
| **cod-4 silent-empty** | 2026-08-10 | Coder docs lane returned COMPLETELY EMPTY result, no changes | Silent-empty task result; orchestrator did not verify artifacts before assuming completion | Treat empty as silent failure; verify in-scope artifacts; exact-instance resume | No: procedural rule only |
| **ai--3 fabricated review** | 2026-08-10 | ai-specialist returned stub verdict "APPROVE" with NO findings or evidence | Mis-scoped lane (Phase-6 review is ai-auditor's job); orchestrator accepted stub | Route Phase-6 to ai-auditor; enforce persisted findings before closing | No: procedural |
| **Reviewer empty-result** | 2026-08-06 | Reviewer completed with EMPTY result; re-dispatch lost context | Orchestrator re-dispatched fresh reviewer instead of resuming by task_id | Resume by task_id; persist task_id at dispatch time; 3-failure cap | No: procedural |
| **ai-specialist stub** | 2026-08-08 | ai-specialist returned stub summary without substantive artifact | A4 artifact gate not enforced | Enforce artifact-content; treat stub as non-deliverable | No: procedural |
| **cod-8/cod-9 ambiguous empty** | 2026-08-14 | cod-8 returned EMPTY but work had fully landed (commit present) | Empty result is AMBIGUOUS: can be silent failure OR reporting artifact | Verify-first read-only lane BEFORE deciding re-dispatch | Yes: verified in-session |

### 1.2 Context Estimation Errors

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-191** | 2026-08-15 | context_usage proxy showed 48% vs TUI 23% (~2x overestimate); premature SELF-RERUN | Proxy formula used registry activity signals (message_count * 10000), not real tokens | V1 reweight formula; V2 direct live in-context read (TUI-equivalent) | Yes: 3-depth verification passed (|proxy-tui|/tui < 0.25) |
| **Premature SELF-RERUN** | 2026-08-03 | Handoff fired at 95,627 tokens assuming 64k window | NEXT-RUN.md listed stale V3 window (64k) for V4-Flash (1M actual) | Verify model windows against models.dev; record authoritative source | No: procedural |
| **DIA-080** | 2026-08-11 | context_usage cumulative proxy reading 100% | Cumulative (cross-session) token counting instead of session-scoped | Session-scoped proxy (later superseded by DIA-191 direct read) | Yes: commit 4f5bb46 |

### 1.3 Subagent Result Quality (Truncation, Step-Cap, Stalls)

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-099** | 2026-08-11 | Multiple truncated/partial subagent responses (ai--1, cod-5, cod-7) | Step-budget exhaustion, model truncation, endpoint issues | Detect-preserve-resume-validate protocol (Variant A2); resume-truncated-lane skill | Partial: restart-verify DEFERRED |
| **DIA-098** | 2026-08-11 | Spontaneous session stops; 8 stop-point classes from ~1108 sessions | Permission-ask stalls, silent-empty, tool-error loops, crashes, orphans | R1 error serialization fix; R2 proactive 60s stall timer; R3 permission watchdog (5-min auto-reject) | Partial: restart-verify DEFERRED |
| **MAXIMUM_STEPS cod-2** | 2026-08-08 | Combined probe+test-config lane hit step-cap mid-protocol | Lane too broad; recon+verification consumed budget | Split into single-responsibility lanes; conservative step budgets | No: procedural |
| **Session-3 step exhaustion** | 2026-08-10 | All 5 code-executor lanes hit MAXIMUM STEPS | Step-budget too small for multi-part config/docs tasks | Narrow lane scope; front-load state; multiple small lanes > one combined | No: procedural |
| **cod-12 merge-lane error** | 2026-08-16 | Merge-lane subagent errored; session not reusable | Session error; job board marks errored as non-reusable | Verify-first fresh dispatch (NOT resume of errored session) | Yes: verified in-session |
| **Snip-wrapper loop** | 2026-08-08 to 08-10 | coders repeatedly ran `snip make test-config` producing identical output 7+ times | opencode-snip plugin rewrote ALL bash to `snip <cmd>`; prompt guardrails ineffective | DIA-092: plugin removal; dormant deny rules retained | Yes: DIA-092 Phase 5 verified 9/9 |

### 1.4 Coordination Failures (Race Conditions, Ordering)

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-085 clobber** | 2026-08-15 | Two parallel orchestrator sessions wrote same handoff within 65s; prognosis lost | Single-slot current-handoff.json; no per-session isolation | Per-session slots + active.json pointer + archive-on-overwrite + .reconciled sidecar | Yes: 6-scenario smoke suite + 9 bun tests + bats |
| **DIA-085 F-1** | 2026-08-15 | Archive collision: same-millisecond same-session writes produce identical archiveName; POSIX rename replaces first | Millisecond-resolution timestamp not unique under same-ms double-fire | NOT YET FIXED (noted in review, not yet in ticket) | No |
| **DIA-085 F-3** | 2026-08-15 | Slot identity `parentSessionId ?? lane_id ?? "unknown"` collapses pre-dispatch sessions to "unknown" | Fallback chain collapses distinct sessions to shared key | NOT YET FIXED | No |
| **DIA-120** | 2026-08-12 | Handoff-writer plugin fired on in-flight log_decision, overwriting valid handoff with fallback wrapper | No terminal-status filter; any `event_type='handoff'` + non-empty prognosis triggered write | Terminal-status filter (done/escalated/pending-owner only); boot-gate re-read at comparison time | Yes: restart-verify PASS 2026-08-13 |
| **DIA-124** | 2026-08-13 | Orchestrator presented session-end prompt BEFORE writing handoff | No hard rule enforcing handoff-before-presentation ordering | HARD RULE: handoff via log_decision BEFORE final summary; 3-step sequence (write, confirm, present) | No: procedural + comment-only plugin gate |
| **DIA-061** | 2026-08-07 | Orchestrator completed work and declared "Complete" without writing handoff | Handoff treated as optional; no hard trigger | Checksum discipline; boot-gate hard refusal on missing/unverifiable handoff | Yes: post-restart verified |
| **Dispatched-but-not-executed** | 2026-08-04 | task() calls batched with edit tool calls silently dropped | Batching task() with edits in same message caused runtime to drop task() | Avoid batching edit+task in same message; single-responsibility messages | No: procedural |
| **Resume loop** | 2026-08-03 | ~10 resume dispatches spawned fresh sessions instead of resuming; lost reviewer report | Orchestrator omitted task_id parameter; completed sessions not context-reusable by alias | Always pass task_id for resume; 3-failure cap before escalation | No: procedural |

### 1.5 Protocol Violations (Handoff, Checksum, Serialization)

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-075** | 2026-08-09 | Boot-gate checksum mismatch: `snip jq` truncated output, producing wrong hash | opencode-snip plugin's built-in jq filter truncated output above threshold | DIA-092: plugin removal; canonical `bash -c` jq passthrough | Yes: structurally eliminated |
| **DIA-078** | 2026-08-10 | Coder lanes executed `snip make test-config` in identical loop 7+ times | Same snip plugin; prompt guardrails scoped to jq only, not all commands | Broaden guardrail to ALL commands; anti-loop detection; plugin removal | Yes: plugin removal |
| **DIA-161/DIA-165** | 2026-08-12 | Recursion fork-bomb: verify-pre-push.sh -> make test-shell -> bats -> same script -> infinite | No re-entrancy guard; test-side hostname shim insufficient for manual/husky invocations | Env-flag propagation (VERIFY_PRE_PUSH_RUNNING); top-of-script guard | Yes: 212/212 bats + hook-exact verification |
| **DIA-166** | 2026-08-12 | Hook-context flag inheritance broke 8 bats tests | DIA-165 fix exported flag; tests inherited it; no test-side unset | `unset VERIFY_PRE_PUSH_RUNNING` in test setup(); hook-exact verification | Yes: 212/212 both modes |
| **DIA-126** | 2026-08-13 | Agents had NO bash tool despite config allow grants; stalled for hours | Trailing `"*": "deny"` catch-all AFTER specific allows; findLast landed on deny | Move catch-all to FIRST position; verify runtime tool manifest | Yes: restart-verify manifest check |
| **DIA-186** | 2026-08-15 | overnight.bats assertion broke on additive permission payload change | Test asserted exact-string equality with full payload | Switch to subset-presence contract arrays (invariant assertions) | Yes: commit d18672b |
| **S18 stale-comparison** | 2026-08-12 | Boot-gate compared against memorized checksum, not re-read file | Stale-comparison flaw + DIA-120 plugin trigger bug | Re-read at comparison time; report stored= vs computed= | Yes: restart-verify |
| **Hallucinated model ID** | 2026-08-04 | Post-restart observer failed: "Model not found: github-copilot/gemini-3.6-flash" | Learnings file asserted model as GA without verification; stale ID in ACTIVE preset | Verify model IDs against live catalog; post-restart smoke step | No: procedural |

### 1.6 Crash/Interrupt Recovery

| ID | Date | What happened | Root cause | Fix/rule implemented | Tested? |
|---|---|---|---|---|---|
| **DIA-177** | 2026-08-14 | GREEN coder session lost mid-dispatch on user opencode crash | Mid-dispatch crash; on-disk state indeterminate | Recon-first read-only lane before re-dispatch; never blindly re-run writer | Yes: verified in-session |
| **Aborted commit-lane** | 2026-08-13 | Aborted dispatch left partial ticket-status edits | No idempotent re-dispatch pattern | Verify current state; apply only missing delta; verify idempotently | No: procedural |
| **DIA-070** | 2026-08-08 | TUI restart did not load patched plugin code | Plugin resolution caches at process startup; TUI restart reused process | Hard process restart (kill PID); post-restart checksum verification | Yes: verified |

---

## 2. Failure Mode Taxonomy

### 2.1 Silent Delegation (False-Delegation Incidents)

**Pattern:** A subagent is dispatched, starts (session spawns, files are read), but returns an EMPTY or stub result. The orchestrator may or may not detect the emptiness.

**Occurrences:** 7+ documented incidents across 2026-08-03 to 2026-08-17.

**Sub-variants:**
- **Silent-empty (no work landed):** DIA-130, cod-4, ai--3 stub, reviewer empty-result
- **Ambiguous-empty (work actually landed):** cod-8/cod-9
- **Systemic cross-lane:** DIA-206 (5x across ai-specialist, coder, researcher)
- **Endpoint-dead:** L20260816-006 (3x ai-specialist endpoint unavailable)

**Detection signals (DIA-099):**
- D1: session_complete + no task_success + no file edits (~80% SILENT_FAILURE)
- D2: session_failed with MAXIMUM STEPS (~95% CRASH/STEP_CAP)
- D5: stall_detected with no terminal (~90% STALLED)

**Key insight:** Empty result is AMBIGUOUS. The same recovery path (verify-first read-only) handles both variants correctly.

### 2.2 Context Estimation Errors

**Pattern:** The context_usage tool's proxy estimate diverges from actual token usage, causing premature or missed SELF-RERUN triggers.

**Occurrences:** 3 documented (DIA-080, DIA-191, premature SELF-RERUN 2026-08-03)

**Evolution:**
1. DIA-080: cumulative proxy -> session-scoped proxy
2. DIA-191 V1: reweight formula (removed session*10000 term)
3. DIA-191 V2: direct live in-context read (TUI-equivalent)

**Current state:** V2 direct read is primary (within 7% of TUI); V1 proxy retained as fallback.

### 2.3 Subagent Result Quality

**Pattern:** Subagent returns truncated, step-capped, or stalled output.

**Occurrences:** 6+ documented (DIA-099, DIA-098, MAXIMUM_STEPS cod-2, session-3 exhaustion, cod-12 error, snip-wrapper loop)

**Root causes:**
- Step-budget too small for task scope
- Snip plugin rewriting commands (structurally eliminated by DIA-092)
- Permission-ask stalls (addressed by DIA-098 R3)
- Model/endpoint failures (transient, no fix)

### 2.4 Coordination Failures

**Pattern:** Multiple sessions or lanes interfere with each other's state.

**Occurrences:** 8+ documented (DIA-085 clobber, DIA-120 plugin clobber, DIA-124 ordering, DIA-061 missing handoff, dispatched-but-not-executed, resume loop, batch task() dropping, S18 stale-comparison)

**Root causes:**
- Single-writer contract violations (multiple sessions writing same file)
- Plugin trigger firing when it should not (DIA-120)
- Missing ordering constraints (DIA-124)
- Batching incompatible operations in same message

### 2.5 Protocol Violations

**Pattern:** Established protocols (checksum, handoff, permission ordering) are violated.

**Occurrences:** 8+ documented (DIA-075, DIA-078, DIA-161/165, DIA-166, DIA-126, DIA-186, S18 stale-comparison, hallucinated model ID)

**Root causes:**
- Plugin/tool intercepting commands unexpectedly (snip)
- Missing re-entrancy guards (fork-bomb)
- Permission map ordering trap (catch-all position)
- Test assertions coupled to additive payload (exact-string equality)
- Stale data in lookup tables (model windows, checksums)

---

## 3. Unfixed / Untested Gaps

### 3.1 Rules with NO Regression Tests

| Rule/fix | Status | Risk |
|---|---|---|
| **DIA-099 resume-truncated-lane protocol** | Procedural only; restart-verify DEFERRED | High: no mechanical enforcement that empty results trigger the protocol |
| **DIA-098 stall timer + permission watchdog** | Implemented in plugin; restart-verify DEFERRED | High: cannot confirm the 60s sweep or 5-min auto-reject work live |
| **DIA-124 handoff-before-presentation** | Procedural HARD RULE + comment-only plugin gate | Medium: no mechanical enforcement; relies on orchestrator compliance |
| **3-failure cap (DIA-099)** | Procedural | Medium: no mechanical enforcement; orchestrator could loop |
| **Verify-first before re-dispatch** | Procedural | Medium: no mechanical enforcement |
| **Exact-instance resume (task_id)** | Procedural | Medium: orchestrator could still omit task_id |
| **Single-responsibility messages (no batch edit+task)** | Procedural | Low: batching is a runtime behavior, hard to test |
| **Model ID verification against live catalog** | Procedural | Low: occurs rarely |
| **DIA-085 F-1 archive collision (same-ms)** | NOT FIXED | High: design claim "both prognoses survive" is falsified |
| **DIA-085 F-3 "unknown" slot identity** | NOT FIXED | High: pre-dispatch parallel sessions collide on "unknown" |
| **DIA-206 systemic empty-return diagnosis** | OPEN ticket, no fix | High: root cause unknown, workaround only |

### 3.2 DIA-085 Review Falsifications (Not Yet in Tickets)

Two CRITICAL findings from the DIA-085 implementation review are recorded ONLY in failures.md and lessons.md, not in any ticket or commit:

1. **F-1 CRITICAL:** Archive file name derivation keys on sessionId + millisecond timestamp. Same-ms double-fire produces identical archiveName; POSIX rename silently replaces the first archived prognosis. Design claim "both prognoses survive" is FALSIFIED.

2. **F-3 CRITICAL:** Slot identity `parentSessionId ?? lane_id ?? "unknown"` collapses parallel resumed-orchestrator sessions (pre-first-dispatch) into the same `handoffs/unknown.json`. Last-writer-wins clobber -- the exact class DIA-085 claims to eliminate.

Both are NOT yet live (handoffs/ directory absent at time of discovery) but represent unfixed design falsifications.

---

## 4. Recurring Patterns

### 4.1 Empty-Result Loop (5+ occurrences)

**Pattern:** Subagent returns empty -> orchestrator re-dispatches fresh instance -> fresh instance also returns empty or loses context -> loop continues.

**Occurrences:**
1. 2026-08-03: resume loop (~10 fresh sessions)
2. 2026-08-06: reviewer empty-result
3. 2026-08-10: cod-4 silent-empty
4. 2026-08-13: DIA-130 coder-escalated silent failure
5. 2026-08-17: DIA-206 ai-specialist 3x empty + coder + researcher

**Root cause:** Orchestrator does not distinguish "silent failure" from "work already landed" and defaults to re-dispatch instead of verify-first.

**Fix status:** DIA-099 Variant A2 protocol (verify-first, resume same session) is the correct recovery but is PROCEDURAL, not mechanical. No automated enforcement.

### 4.2 Snip-Wrapper Interception (3 occurrences before removal)

**Pattern:** opencode-snip plugin rewrites bash commands to `snip <cmd>`, which truncates output for certain commands (jq, make), producing wrong results or infinite loops.

**Occurrences:**
1. 2026-08-08: cod-6 snip-wrapper loop (jq)
2. 2026-08-09: DIA-075 boot-gate checksum mismatch (jq)
3. 2026-08-10: DIA-078 coder snip-wrapper loop (make)

**Root cause:** Plugin's `tool.execute.before` hook mechanically rewrote ALL commands; prompt guardrails were structurally ineffective (3 consecutive lanes violated them).

**Fix status:** STRUCTURALLY ELIMINATED by DIA-092 (plugin removal). Dormant deny rules retained.

### 4.3 Handoff Clobber / Missing Handoff (4 occurrences)

**Pattern:** Handoff file is overwritten, not written, or written with stale data.

**Occurrences:**
1. 2026-08-07: DIA-061 orchestrator fails to produce handoff
2. 2026-08-12: DIA-120 plugin overwrites valid handoff on in-flight log
3. 2026-08-13: DIA-124 orchestrator presents session-end before writing handoff
4. 2026-08-15: DIA-085 two parallel sessions clobber same handoff

**Root cause:** Single-writer contract violations at multiple levels (orchestrator omission, plugin trigger, parallel sessions).

**Fix status:** DIA-120 fixed (terminal-status filter). DIA-085 fixed (per-session slots). DIA-124 procedural. DIA-061 fixed (checksum gate). But DIA-085 F-1 and F-3 remain unfixed.

### 4.4 Config-Runtime Divergence (3 occurrences)

**Pattern:** Config file looks correct on read, but runtime behavior differs.

**Occurrences:**
1. 2026-08-04: hallucinated model ID in ACTIVE preset
2. 2026-08-13: DIA-126 catch-all ordering hides bash tool
3. 2026-08-13: DIA-128 local-vendored vs installed-npm semantic split

**Root cause:** OpenCode's config resolution has non-obvious ordering rules (findLast for permissions, inline-wins vs file-wins precedence divergence).

**Fix status:** All three required restart-verify manifest checks. No mechanical prevention.

---

## 5. Hardening Recommendations

Priority-ordered by: (a) frequency of occurrence, (b) severity of impact, (c) whether the fix is tested.

### P0 -- Critical, Unfixed

| # | Recommendation | Rationale |
|---|---|---|
| 1 | **Fix DIA-085 F-1 (archive collision):** disambiguate archiveName with monotonic counter or UUID suffix, or use O_EXCL semantics | Design claim falsified; silent prognosis loss when fixed |
| 2 | **Fix DIA-085 F-3 ("unknown" slot identity):** use actual sessionId as last resort, never "unknown" | Design claim falsified; last-writer-wins clobber for pre-dispatch sessions |
| 3 | **Diagnose DIA-206 systemic empty-return:** root cause unknown across 5 incidents in one day; current workaround only | Blocks entire section-2.5 workflow when ai-specialist is the gate |

### P1 -- High, Untested Fixes

| # | Recommendation | Rationale |
|---|---|---|
| 4 | **Mechanical enforcement for DIA-099 empty-result protocol:** plugin-level detection of empty task results + automatic verify-first dispatch | 7+ occurrences; procedural rule not reliably followed |
| 5 | **Complete DIA-098 restart-verify:** confirm stall timer + permission watchdog work live | Core detection infrastructure; currently unverified |
| 6 | **Mechanical 3-failure cap:** plugin-level counter that blocks re-dispatch after 3 consecutive empty results from same lane | Prevents denial-of-service loop pattern |
| 7 | **Mechanical handoff-before-presentation (DIA-124):** plugin hook on session.idle that checks handoff freshness before allowing session-end flow | 4 handoff incidents; procedural rule insufficient |

### P2 -- Medium, Procedural Only

| # | Recommendation | Rationale |
|---|---|---|
| 8 | **Automated config-runtime verification:** after any permission-map edit, automatically verify the target agent's runtime tool manifest | 3 config-runtime divergence incidents; all caught by manual restart-verify |
| 9 | **Test the hook-exact verification mode for ALL gate scripts:** DIA-166 lesson (hook-context flag inheritance) should be a standard test pattern | Standalone-only verification missed hook-context behavior |
| 10 | **Subset-presence contract for ALL additive config tests:** DIA-186 lesson (exact-string assertion breaks on additive growth) should be standard | Any additive config change breaks exact-string tests |

### P3 -- Low, Already Mitigated

| # | Recommendation | Rationale |
|---|---|---|
| 11 | **Model-window verify-on-use:** integrate models.dev check into context_usage tool | Stale model window caused premature SELF-RERUN; now mitigated by direct read |
| 12 | **Document the verify-first-before-re-dispatch pattern as a skill:** currently scattered across failures.md, lessons.md, and DIA-099 | Makes the pattern discoverable and enforceable |

---

## 6. Summary Statistics

| Category | Incident count | Fixed + tested | Fixed, untested | Unfixed |
|---|---|---|---|---|
| Silent delegation / empty results | 7+ | 0 | 3 (procedural) | 2 (DIA-206, DIA-085 F-1/F-3) |
| Context estimation errors | 3 | 2 (DIA-191 V2, DIA-080) | 0 | 0 |
| Subagent result quality | 6+ | 1 (snip removal) | 3 (DIA-098/099 restart-verify deferred) | 0 |
| Coordination failures | 8+ | 3 (DIA-120, DIA-085 slots, DIA-061 gate) | 2 (DIA-124, resume protocol) | 2 (DIA-085 F-1/F-3) |
| Protocol violations | 8+ | 5 (DIA-075/078/092, DIA-165, DIA-126) | 2 (DIA-166, DIA-186) | 0 |
| Crash/interrupt recovery | 3 | 0 | 1 (DIA-177 verified in-session) | 0 |

**Total documented incidents:** 35+
**Structurally fixed (root cause eliminated):** 8
**Procedurally fixed (rule added, no mechanical enforcement):** 15+
**Unfixed:** 3 (DIA-085 F-1, F-3, DIA-206)
**Fixes without live verification:** 5+ (DIA-098, DIA-099 restart-verify deferred)

---

## 7. Key Observations for Council Review

1. **The orchestration layer has no mechanical enforcement for its most critical protocols.** Handoff writing, empty-result detection, failure caps, and verify-first ordering are all PROCEDURAL rules that depend on the orchestrator model following instructions. When the model fails to follow them (which is exactly what causes these incidents), there is no safety net.

2. **The plugin layer is the only reliable enforcement mechanism.** Every structurally fixed incident (DIA-092 snip removal, DIA-120 terminal-status filter, DIA-085 per-session slots, DIA-061 checksum gate) was fixed at the plugin level. Procedural fixes in orchestrator prompts have a high recurrence rate.

3. **Empty-result ambiguity is the single most costly failure class.** It has caused the most wasted lane time (34+ minutes per incident), the most confusion (is it a failure or a reporting artifact?), and the most incorrect recovery actions (blind re-dispatch causing double-apply). The verify-first pattern works but is not enforced.

4. **Restart-verify is systematically deferred.** DIA-098, DIA-099, and several other tickets have "restart-verify DEFERRED to next session" -- meaning the plugin-level fixes have never been confirmed live. This is a verification gap that could hide regressions.

5. **The DIA-085 parallel-handoff implementation has two known design falsifications that are NOT yet tracked in any ticket.** These are recorded only in failures.md and lessons.md. They represent silent-data-loss risks when parallel sessions are activated.
