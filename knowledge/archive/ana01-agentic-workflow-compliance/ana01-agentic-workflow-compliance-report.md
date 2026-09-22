# Agentic Workflow Compliance Analysis

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/session/registry.jsonl, .opencode/session/messages.jsonl
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Executive Summary

Analysis of session logs from 2026-08-04 through 2026-08-19 reveals systematic workflow violations across multiple categories. The most prevalent issues are routing violations (config work without ai-specialist gate), empty result handling (DIA-099 protocol not followed), and ticket-ID compliance gaps. Evidence drawn from 205,651 registry entries and 203,685 message events.

**Data Quality Note:** Logs are complete and well-structured. Sampling focused on most recent 1,000 entries per event type for pattern identification. No corrupted entries detected.

---

## 1. Routing Violations

### [ROUTING] — Systematic config-work without ai-specialist gate (DIA-230)

- **Evidence:** messages.jsonl rows 148885-171763 (20+ routing_violation events)
- **Sessions:** ses_fe9391802ffeZxwqH8yjm3cBwa, ses_fe746ee9ffeaU0tN49mFMQ61q, ses_fe67742d8ffeYgpgHAdE2c97xW
- **What happened:** @coder dispatched on config-work (opencode.jsonc, .opencode/plugins/, .opencode/agents/, AGENTS.md) without prior @ai-specialist gate review. Plugin detected 20+ violations across 3 sessions on 2026-08-18 and 2026-08-19.
- **Root cause:** Orchestrator prompt does not enforce DIA-230 routing hook. Plugin emits WARNING but does not block dispatch. No hard gate in delegation-observer.ts to prevent config-work lanes from bypassing ai-specialist.
- **Related DIA:** DIA-230 (routing hook blocking gate)
- **Fix proposal:** Add hard block in delegation-observer.ts: if subagent_type=coder AND detected_paths match config patterns (opencode.jsonc, .opencode/*, AGENTS.md), block dispatch unless prior ai-specialist session exists in registry for same ticket_id. Emit BLOCKED status, not WARNING.

### [ROUTING] — Plugin diagnostic logs rendered inline in UI

- **Evidence:** messages.jsonl row 164664 (DIA-233 decision)
- **Session:** ses_fe746ee9ffeaU0tN49mFMQ61q
- **What happened:** ROUTING_VIOLATION warnings from delegation-observer plugin rendered inline in UI chat stream between orchestrator messages, cluttering user-facing conversation.
- **Root cause:** Plugin emission path writes to both messages.jsonl (correct) and UI stream (incorrect). No separation of internal observability vs user-facing output.
- **Related DIA:** DIA-233 (plugin diagnostic log routing)
- **Fix proposal:** Route all plugin diagnostic events to messages.jsonl only. UI stream should only show orchestrator decisions and delegation summaries. Add emission filter in delegation-observer.ts to suppress ROUTING_VIOLATION from UI render path.

---

## 2. Gating Violations

### [GATING] — Interview-first gate bypassed for DIA-234

- **Evidence:** messages.jsonl rows 165417-165473 (DIA-234 decision + coder dispatch)
- **Session:** ses_fe746ee9ffeaU0tN49mFMQ61q
- **What happened:** DIA-234 (datetime-based ticket IDs) dispatched directly to coder for implementation without openspec-plan interview-first spec authoring. Developer approved grandfather-only migration in decision row 165417, but no interview transcript exists. Coder dispatch at row 165467 preceded by decision, not interview.
- **Root cause:** Fast-path auto-classification without developer opt-in. Orchestrator classified DIA-234 as "simple change" (single-file ticket format reform) and skipped interview gate. No hard checkpoint in orchestrator prompt to require developer confirmation before fast-path classification.
- **Related DIA:** DIA-104 (mandatory developer grilling gate), DIA-214 (missing ticket-ID + DIA-id in text)
- **Fix proposal:** Add hard checkpoint: if ticket_id present in dispatch AND change scope > 20 lines OR touches multiple files, require openspec-plan interview OR explicit developer fast-path approval (logged in messages.jsonl with event_type=decision, content_ref=fast-path-approved).

### [GATING] — Researcher Phase A hard checkpoint bypassed

- **Evidence:** messages.jsonl row 164024 (DIA-190 crisis)
- **Session:** ses_fe746ee9ffeaU0tN49mFMQ61q
- **What happened:** Researcher returned PERSISTENCE_RECOMMENDED: false without creating sources/ artifacts. Research pipeline Phase A (source capture) bypassed. Developer ruling: research MUST always create sources, then conspect, then decisions/analysis.
- **Root cause:** No hard gate in researcher prompt to block return without sources/ directory creation. Plugin detects empty result (DIA-224) but does not enforce Phase A completion.
- **Related DIA:** DIA-232 (researcher Phase A hard checkpoint), DIA-099 (truncated/empty subagent result protocol)
- **Fix proposal:** Add pre-return checkpoint in researcher agent: if sources/ directory empty OR no .md files created, block return with error "Phase A incomplete: sources/ directory must contain at least one source artifact." Plugin should detect and escalate as crisis, not just empty_result.

---

## 3. Verification Gaps

### [VERIFICATION] — Missing verification evidence from coder handoffs

- **Evidence:** messages.jsonl rows 2190-3064 (15+ handoff checksum verify delegations)
- **Sessions:** ses_00af5661affep622RQQ0HBWoso, ses_00a75dc18ffe7wxnmRJzyKAAke, ses_00a0b8782ffeU2yh5tGHn8Iaz1, ses_009f950f8ffepCqzJYUTTfSequ, ses_0089666b4ffeJPQLi2lwTD2CRU, ses_0083e3e5affe8QO0Y5IVczF1K3, ses_007e31c2bffeAHCPbiIzUekK59, ses_007cff505ffeksrQCplcgOHVlO, ses_007c69e8dffefyQ5XFHnFDZRN0, ses_005ca139bffeutW2JGhX3yMg1F, ses_004f04297ffesTgEVd5h58Zinb, ses_0046d86f6ffeVAgOzA53U4NOMh, ses_0043d6ad7ffeScZBDVjt1sgLjh, ses_ffd5187b4ffe7WkIjPHKN5qYUY, ses_ffbabfd54ffezUdRJM3bzrrsiY, ses_ffb7b043affe220G0Af50l7v8W
- **What happened:** Repeated coder dispatches for "Lane-0 handoff checksum verify" and "Verify handoff file written" across multiple sessions on 2026-08-12 through 2026-08-15. Indicates coder handoffs lack mandatory verification evidence (test/lint/typecheck exit codes + summary lines).
- **Root cause:** Coder agent prompt does not enforce verification evidence template. Handoff contract (DIA-124) requires verification but no plugin hook validates presence of exit codes in coder output.
- **Related DIA:** DIA-124 (session-end handoff), DIA-174 (batch-D hardening)
- **Fix proposal:** Add post-dispatch validation in delegation-observer: if subagent_type=coder AND event=complete, scan output for verification evidence pattern (exit code regex: "exit \d+" OR "test-shell \d+/\d+" OR "make test-\w+ exit \d+"). If missing, emit gate_warn and block handoff until coder provides evidence.

### [VERIFICATION] — Reviewer not re-dispatched after fixes

- **Evidence:** messages.jsonl rows 428-431 (DIA-045 review cycle)
- **Session:** ses_02dd90b40ffetMH0Idgs3Fl4iZ (rev-1), ses_02dbc36a9ffeEk0EopoRvOjg5a (rev-2)
- **What happened:** Reviewer rev-1 returned findings-need-fix with 1 Major + Minors. Coder cod-14 applied fixes. Reviewer rev-2 re-review cycle 1/2 verified all closed. However, no evidence of cycle 2/2 or final verification before persist. Workflow jumped to cod-15 final wrap-up without explicit re-review completion.
- **Root cause:** Re-review loop (AGENTS.md §2.3.1) caps at 2 cycles but no plugin hook enforces cycle counter or blocks persist until all findings verified-closed.
- **Related DIA:** DIA-174 (batch-D hardening), DIA-063 (ticket-creation gate)
- **Fix proposal:** Add re-review cycle tracker in delegation-observer: maintain counter per ticket_id, block persist dispatch unless cycle_count >= 2 OR all findings verified-closed. Emit gate_warn if persist attempted before re-review complete.

---

## 4. Handoff Issues

### [HANDOFF] — Checksum mismatch false negatives

- **Evidence:** messages.jsonl rows 981-1191 (DIA-061 checksum events)
- **Sessions:** ses_0208821e1ffeLgk6NHheB2K0aD, ses_01d871affffenJ3qpHHQZcamwP, ses_01d75a3b7ffeXj4UYR4qAaZIer
- **What happened:** Multiple checksum-mismatch escalations on 2026-08-08 and 2026-08-09. Row 981: boot-gate checksum-mismatch escalated. Row 1043: batch-approval-gate checksum-mismatch escalated. Row 1157: DIA-069-phase5-resume checksum-mismatch escalated. Row 1174: same ticket checksum-mismatch again. Row 1176: checksum-resolved-executor-false-negative cleared.
- **Root cause:** Checksum computation method inconsistency between write-time and verify-time. Executor plugin computes checksum differently than orchestrator. No canonical checksum algorithm enforced.
- **Related DIA:** DIA-061 (orchestrator handoff files failure), DIA-075 (checksum mismatch snip jq loop)
- **Fix proposal:** Standardize checksum algorithm: SHA256 of jq canonical JSON (sorted keys, no whitespace). Document in DIA-061 spec. Add checksum-computation helper script (scripts/compute-handoff-checksum.sh) that both orchestrator and executor call. Plugin validates checksum using same script.

### [HANDOFF] — Stale handoff pointers

- **Evidence:** messages.jsonl rows 362-391 (DIA-045 ticket ledger reconciliation)
- **Session:** ses_02f415341ffeVVBdbv7pa4eGj9
- **What happened:** Code-navigator cod-4 discovered HANDOFF backlog STALE: DIA-042/043/044/048/049 all archived CLOSED/VERIFIED in commit f40af9a but still listed in HANDOFF.md. Only DIA-045 remained OPEN.
- **Root cause:** Handoff file not pruned after ticket closure. No plugin hook scans HANDOFF.md for stale ticket references and removes them.
- **Related DIA:** DIA-077 (job board stale objective), DIA-085 (handoff parallel orchestrator sessions)
- **Fix proposal:** Add handoff-prune hook in delegation-observer: on session idle, scan HANDOFF.md for ticket_id references, cross-check with docs/dev-infra-audit/tickets/README.md (OPEN only), remove stale references. Emit decision event with pruned list.

---

## 5. Truncation Handling

### [TRUNCATION] — Empty results accepted silently (DIA-099 protocol not followed)

- **Evidence:** registry.jsonl seq 194571-204945 (20+ empty_result_detected events)
- **Sessions:** ses_fe7194118ffe85hkFjGqae4mjy, ses_fe709deb5ffeXTO5PZtJuCzPyp, ses_fe708644fffeIKlljxXZbE0OZk, ses_fe6f6e7bbffeo1fwUsiLT7Lgpj, ses_fe6f2daf0ffeQROwDJ73bmuiXx, ses_fe6c8db0affeGd2gKYhnz4GLA6, ses_fe6e259aaffeilpcWfI01B61pQ, ses_fe69b1f14ffeED2L6adpe3h6bT, ses_fe6959f97ffeJ0kL5OmTo57dFw, ses_fe675db01ffe78UkSiSyAXxC97, ses_fe675386dffeBqDUg98W9D8Noj, ses_fe673c442ffeO8VHkZ1LKpIsgH, ses_fe66c8f7cffeewc3UQ0vRDr2vF, ses_fe66bcd0cffeLSuJOwlzCSYEtP, ses_fe6694ea1ffeOZzNXeDAOUsllx, ses_fe66460c6ffesjeaQgXSIHaeSO, ses_fe6476fa3ffeeKfY2zfqRScswW, ses_fe63e23d0ffe13c26JCYGvOoRH, ses_fe627bf83ffexpjBMiXwNPQHTB
- **What happened:** 20+ child sessions completed with zero file edits on 2026-08-19. Plugin detected empty_result and logged to registry.jsonl with dispatch_state=SILENT_FAILURE. However, no crisis event emitted, no re-dispatch triggered. Orchestrator continued to next task without addressing empty results.
- **Root cause:** DIA-099 protocol (truncated/empty subagent result) not enforced. Plugin detects but does not escalate. No orchestrator prompt instruction to handle SILENT_FAILURE states.
- **Related DIA:** DIA-099 (truncated/empty subagent result protocol), DIA-224 (empty-result detection)
- **Fix proposal:** Add escalation logic in delegation-observer: if empty_result_detected AND agent != researcher (researcher has Phase A gate), emit crisis event with resolution_status=escalated, content_ref=empty-result-requires-redispatch. Orchestrator prompt must include instruction: "If crisis event with empty-result-requires-redispatch, re-dispatch to fresh session OR resume same session with explicit recall instruction."

### [TRUNCATION] — Coder empty result on config-work

- **Evidence:** registry.jsonl seq 200336 (empty_result_detected for coder ses_fe6e259aaffeilpcWfI01B61pQ)
- **Session:** ses_fe6e259aaffeilpcWfI01B61pQ
- **What happened:** Coder session completed with zero file edits on DIA-234 implementation. This is particularly concerning because config-work should have ai-specialist gate first (DIA-230), and empty result indicates coder either blocked or returned without attempting work.
- **Root cause:** Combination of routing violation (no ai-specialist gate) and truncation handling failure (empty result not escalated).
- **Related DIA:** DIA-230 (routing hook), DIA-099 (empty result protocol), DIA-234 (ticket ID reforms)
- **Fix proposal:** Same as routing violation fix + truncation handling fix. Additionally, add coder-specific checkpoint: if detected_paths match config patterns AND file_edit_count=0, emit gate_warn with detail="coder returned empty on config-work, possible routing block."

---

## 6. Instance Separation

### [INSTANCE] — RED/GREEN separation compliant (DIA-175)

- **Evidence:** messages.jsonl rows 27268-27330 (DIA-189 RED/GREEN split)
- **Sessions:** ses_ffb70df9affe2Smnok23Jn67kZ (RED), ses_ffb6909ceffepqaWeZCOpbFZEL (GREEN)
- **What happened:** DIA-189 correctly split RED tests (ses_ffb70df9affe2Smnok23Jn67kZ) and GREEN implementation (ses_ffb6909ceffepqaWeZCOpbFZEL) into separate coder sessions. Orchestrator decision at row 27299 explicitly routed GREEN implementer to different session.
- **Root cause:** N/A — this is a positive example of DIA-175 compliance.
- **Related DIA:** DIA-175 (instance separation)
- **Fix proposal:** No fix needed. Document as positive example in DIA-175 ticket.

### [INSTANCE] — Same-session fix-loop compliance (DIA-175)

- **Evidence:** messages.jsonl rows 27304-28864 (DIA-189 fix loops)
- **Sessions:** ses_ffb70df9affe2Smnok23Jn67kZ (RED harness fix), ses_ffb6909ceffepqaWeZCOpbFZEL (GREEN pty rename)
- **What happened:** Fix-loop delegations resumed SAME coder sessions that wrote the code. Row 27330: RED harness constant reconciliation routed back to ses_ffb70df9affe2Smnok23Jn67kZ (original RED author). Row 28864: GREEN pty rename routed back to ses_ffb6909ceffepqaWeZCOpbFZEL (original GREEN author).
- **Root cause:** N/A — this is a positive example of DIA-175 same-session fix-loop compliance.
- **Related DIA:** DIA-175 (instance separation, same-session fixes)
- **Fix proposal:** No fix needed. Document as positive example in DIA-175 ticket.

---

## 7. Ticket-ID Compliance

### [TICKET-ID] — gate_warn for non-existent ticket IDs

- **Evidence:** registry.jsonl seq 166701-205627 (6 gate_warn events)
- **Sessions:** ses_fea8ef24effeSv424xFhv1Ezlm (DIA-228), ses_fe746ee9ffeaU0tN49mFMQ61q (DIA-234), ses_fe67742d8ffeYgpgHAdE2c97xW (DIA-233), ses_fe628d0f4ffeRRcYsF1pN74uAO (DIA-235, DIA-260819-mh6p)
- **What happened:** Plugin emitted gate_warn for ticket_id not found in tickets directory. DIA-228, DIA-234, DIA-233, DIA-235, DIA-260819-mh6p all triggered warnings. DIA-260819-mh6p is the current analysis ticket (allocated but not yet written to disk at dispatch time).
- **Root cause:** Ticket creation gate (DIA-063) requires ticket to exist before dispatch, but plugin only warns, does not block. Orchestrator dispatches with ticket_id before ticket file created.
- **Related DIA:** DIA-063 (ticket-creation gate), DIA-217 (universal gate blocking task() without ticket_id arg), DIA-214 (missing ticket-ID + DIA-id in text)
- **Fix proposal:** Upgrade gate_warn to gate_block for ticket_id not found. Plugin should block dispatch unless ticket file exists in docs/dev-infra-audit/tickets/. Exception: if ticket_id matches datetime format DIA-YYMMDD-XXXX (DIA-234), allow dispatch but emit warning that ticket file creation is pending.

### [TICKET-ID] — Missing DIA-id in dispatch text

- **Evidence:** messages.jsonl rows 165467-171771 (DIA-234 dispatches)
- **Session:** ses_fe746ee9ffeaU0tN49mFMQ61q
- **What happened:** Coder dispatch at row 165467: task_ref="Create DIA-234 ticket (meta-task)" — DIA-id present in task_ref. However, row 167174: task_ref="Implement DIA-234 ticket reforms" — DIA-id present. Row 168749: task_ref="Fix DIA-234 review findings" — DIA-id present. Row 171771: task_ref="DIA-233 scenario fix + commit" — DIA-id present. All dispatches include DIA-id in task_ref, but not all include it in dispatch prompt text (the actual prompt content is not logged, only task_ref).
- **Root cause:** DIA-214 requires DIA-id in dispatch prompt text, but plugin only validates ticket_id arg presence, not prompt text content. No way to validate prompt text from logs.
- **Related DIA:** DIA-214 (missing ticket-ID + DIA-id in text), DIA-174 (batch-D hardening)
- **Fix proposal:** Add prompt-text validation in delegation-observer: if subagent_type=coder OR reviewer OR openspec-plan, scan dispatch prompt for DIA-\d+ pattern. If missing, emit gate_warn with detail="DIA-id missing from dispatch prompt text." Log prompt text (first 200 chars) in registry.jsonl for audit.

---

## Priority Matrix

| Priority | Finding | Impact | Effort | Recommendation |
|----------|---------|--------|--------|----------------|
| P0 | Routing violations (config-work without ai-specialist) | High — violates §10 AI Devtools Modernization Workflow, risks unreviewed config changes | Medium — requires plugin hook + prompt update | Implement hard block in delegation-observer.ts, add orchestrator prompt instruction |
| P0 | Empty result handling (DIA-099 not followed) | High — silent failures mask real issues, wastes session tokens | Low — plugin escalation logic only | Add crisis emission for empty_result_detected, orchestrator re-dispatch instruction |
| P1 | Interview-first gate bypassed | Medium — practice-protected zone violated, reduces spec quality | Medium — requires fast-path classification gate | Add developer opt-in checkpoint for fast-path, log decision in messages.jsonl |
| P1 | Missing verification evidence from coder | Medium — reduces confidence in handoffs, increases review cycles | Low — post-dispatch validation pattern match | Add verification evidence regex check in delegation-observer, block handoff if missing |
| P1 | Checksum mismatch false negatives | Medium — blocks handoff flow, requires manual intervention | Medium — standardize algorithm + helper script | Document canonical checksum algorithm, add helper script, plugin uses same script |
| P2 | Researcher Phase A bypassed | Medium — research pipeline incomplete, downstream conspect quality degraded | Low — pre-return checkpoint in researcher prompt | Add sources/ directory check before researcher return, plugin enforces |
| P2 | Ticket-ID gate_warn not blocking | Low — warnings ignored, tickets created after dispatch | Low — upgrade warn to block | Change gate_warn to gate_block for ticket_id not found, exception for datetime format |
| P2 | Stale handoff pointers | Low — handoff file bloat, confusion about open tickets | Low — idle-session prune hook | Add handoff-prune hook in delegation-observer, scan for stale ticket refs |
| P3 | Plugin diagnostic logs in UI | Low — UI clutter, breaks observability separation | Low — emission path filter | Route plugin diagnostics to messages.jsonl only, suppress from UI stream |
| P3 | Missing DIA-id in dispatch prompt text | Low — audit trail incomplete, cannot validate from logs | Medium — prompt text logging + validation | Add prompt-text DIA-id validation, log first 200 chars in registry.jsonl |

---

## Recommendations

### Immediate Actions (P0)

1. **Routing violation hard block:** Implement hard gate in delegation-observer.ts to block coder dispatch on config-work without prior ai-specialist session. This is the most frequent violation (20+ instances in 2 days) and violates the core §10 workflow.

2. **Empty result escalation:** Add crisis emission logic for empty_result_detected events. Current SILENT_FAILURE state is logged but not acted upon. Orchestrator must re-dispatch or resume with explicit recall instruction.

### Short-Term Actions (P1)

3. **Interview-first gate enforcement:** Add fast-path classification checkpoint requiring explicit developer approval (logged in messages.jsonl) before skipping openspec-plan interview.

4. **Verification evidence template:** Enforce coder handoff contract requiring test/lint/typecheck exit codes. Add post-dispatch validation in delegation-observer.

5. **Checksum algorithm standardization:** Document canonical SHA256-of-jq-canonical-JSON algorithm, add helper script, ensure orchestrator and executor use same method.

### Medium-Term Actions (P2)

6. **Researcher Phase A checkpoint:** Add pre-return validation in researcher agent to block return without sources/ directory creation.

7. **Ticket-ID gate upgrade:** Change gate_warn to gate_block for ticket_id not found. Allow exception for datetime-format ticket IDs (DIA-234).

8. **Handoff pruning:** Add idle-session hook to scan HANDOFF.md for stale ticket references and remove them.

### Long-Term Actions (P3)

9. **Plugin diagnostic routing:** Separate internal observability (messages.jsonl) from user-facing output (UI stream).

10. **Prompt-text validation:** Add DIA-id validation in dispatch prompt text, log prompt content for audit.

---

## Conclusion

Workflow violations are systematic but addressable. The most critical issues (routing violations, empty result handling) require plugin-level enforcement, not just prompt instructions. The delegation-observer plugin is the right place for hard gates because it operates at dispatch time, before the violation occurs. Prompt instructions are necessary but insufficient — they rely on orchestrator compliance, which has proven unreliable across 200+ sessions.

Positive examples (DIA-175 RED/GREEN separation, same-session fix-loops) show that when the workflow is clear and the plugin enforces it, compliance is achievable. The key is moving from WARNING to BLOCK for critical violations, and from detection to escalation for quality gates.
