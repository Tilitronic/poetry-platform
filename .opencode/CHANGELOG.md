# OpenCode Config Changelog

## 2026-08-07 — DIA-059 apply_patch §10 gate hardening + DIA-061 handoff checksum enforcement

- **Change:** (1) `.opencode/plugins/delegation-observer.ts` apply_patch branch hardened — first-line-only `Index:`/`diff --git` parse replaced with a multi-marker, multi-file scan (`Index:`, `diff --git`, `+++ b/`, omo `*** Add/Update/Delete File:` markers) that stops at the first `isProtectedPath()` match. Closes two fail-open triggers: leading-blank/format-patch/MIME-header patches, and omo rewritePatch output (codec.ts `formatPatch`) that matched neither git-style regex. (2) `scripts/validate-handoff.sh` — new checksum block (DIA-061): rejects missing/empty/non-64-hex/placeholder checksums and verifies integrity against the canonical serialization `jq -c '.prognosis | to_entries | sort_by(.key) | from_entries'`; non-JSON inputs (markdown template via `make test-config`) skip the block. (3) `orchestrator_append.md` boot gate — SHA256 verify upgraded to HARD GATE: mismatch/missing/non-64-hex → REFUSE TO RESUME + `log_decision` ('handoff','escalated','checksum-mismatch', computed= vs stored=) + escalate; match → `log_decision` ('handoff','acknowledged','checksum-verified'). (4) current-handoff.json checksum recomputed to canonical (0eee533e…) — stored 25646ee… was written with a non-canonical serialization. NEW learnings entry `external-patterns/2026-08-07-plugin-hook-order-and-gate-gaps.md` + index pointer; DIA-061 status OPEN → IMPLEMENTED.
- **Reason:** the §10 gate's apply_patch branch silently fail-opened for any patch whose first line was not `Index:`/`diff --git` — including every omo-rewritten patch (omo loads before this plugin per opencode.jsonc plugin array order). DIA-061: handoff continuity required a deterministic integrity gate — placeholder or stale checksums (this handoff's stored checksum did not match the canonical serialization) must refuse resume, not silently proceed.
- **Files:** .opencode/plugins/delegation-observer.ts · scripts/validate-handoff.sh · .opencode/oh-my-opencode-slim/orchestrator_append.md · .opencode/session/current-handoff.json (checksum recomputed; gitignored) · .opencode/learnings/external-patterns/2026-08-07-plugin-hook-order-and-gate-gaps.md (NEW) · .opencode/learnings/index.md (pointer) · .opencode/CHANGELOG.md · docs/dev-infra-audit/tickets/DIA-059.md · docs/dev-infra-audit/tickets/DIA-061.md · docs/dev-infra-audit/tickets/README.md.
- **Verification:** `npx tsc --noEmit --strict --skipLibCheck --target ESNext --module preserve --moduleResolution bundler .opencode/plugins/delegation-observer.ts` exit 0; `make test-config` exit 0; validate-handoff.sh checksum block negative tests (placeholder / mismatch / missing checksum) each FAIL as expected against /tmp copies of current-handoff.json.
- Pending user: restart OpenCode → runtime smoke of the apply_patch branch (session with the apply_patch tool + plugin restart) and tampered-handoff boot refusal (DIA-061 Re-verify).
- **Phase 6 audit fixes (re-review cycle 1/2 on 8672917):** (F1) writer-side canonical checksum — `delegation-observer.ts` `computeChecksum` now hashes top-level-key-sorted compact JSON (byte-identical with the validator's `jq -c … | printf '%s'` no-trailing-newline method; writer simulation reproduces 0eee533e… on the current handoff); (F2) apply_patch marker chain adds omo's `*** Move to:` rename-destination marker (codec.ts `formatPatch`), closing the move-into-`.opencode/**` blind spot; (F3) `orchestrator_append.md` boot-gate command made byte-identical (`| tr -d '\n'`) + no-trailing-newline caveat sentence; (F4) `validate-handoff.sh` placeholder regex broadened to any repeated char `^(.)\1{63}$`; (F5) DIA-061 narrative reconciled to the canonical 0eee533e… path (45a8404… noted as the non-canonical raw-pipe intermediate). learnings `2026-08-07-plugin-hook-order-and-gate-gaps.md` updated with the writer-contract + Move-to coverage notes.

## 2026-08-07 — DIA-059 §10 gate plugin fix: before-hook args contract corrected (output.args)

- **Change:** `.opencode/plugins/delegation-observer.ts` `tool.execute.before` hook args contract fixed — L482 `async (input, _output)` → `async (input, output)`; L514 `(input as unknown as { args }).args` → `(output as unknown as { args }).args`. Tool arguments live in **`output.args`**, NOT `input.args` (input is read-only `{ tool, sessionID?, callID?, directory? }`). The gate was **fail-open**: reading args from `input.args` yielded `undefined` at runtime, so `filePath` guards silently never fired and `.opencode/` edits bypassed the §10 gate. NEW learnings entry `external-patterns/2026-08-07-plugin-hook-args-contract.md` + index pointer; DIA-059 status OPEN → IMPLEMENTED.
- **Reason:** post-restart re-verify (2026-08-07) showed the plugin binary live (event hooks fire) but the gate did not block edit/write on `.opencode/**` — root cause was the before-hook args contract, not hook dispatch.
- **Files:** .opencode/plugins/delegation-observer.ts · .opencode/learnings/external-patterns/2026-08-07-plugin-hook-args-contract.md (NEW) · .opencode/learnings/index.md (pointer) · docs/dev-infra-audit/tickets/DIA-059.md · docs/dev-infra-audit/tickets/README.md · CHANGELOG.md.
- **Verification:** `npx tsc --noEmit --strict --skipLibCheck --target ESNext --module preserve --moduleResolution bundler .opencode/plugins/delegation-observer.ts` exit 0; `make test-config` exit 0; Phase 6 audit APPROVE-WITH-NOTES (ai-auditor ses_0247422b5ffe7hA6yrWqmJXUk5).
- Pending user: restart OpenCode → gate smoke verification (blocked → gate-token → allowed → cleared → blocked) + apply_patch edge case + CI regression grep.

## 2026-08-07 — cebula preset: reverted 7 agents to pre-commit all-flash model assignments (DIA-064)

- **Change:** Reverted 7 agent model assignments in the `cebula` preset to their pre-commit (2e0c4f3e) all-flash state: orchestrator (`["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), coder (`["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), conspecter (`["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), resource-manager (`["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), memory-manager (`["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), code-navigator (`["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`), researcher (`["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]`). 5 agents also restored their `github-copilot/gpt-5-mini` primary/fallback entries.
- **Reason:** Commit 2e0c4f3e6cacb3d3120f6c5db44ea21f18e724da changed all 7 cebula agents from flash→pro — a cost-critical leak. DIA-062 later reverted only the orchestrator (single-string). Developer approved Option A: full revert to pre-commit all-flash state (cost ~5-10x reduction). Lesson: preset model changes in config commits need explicit review before merge.
- **Files:** .opencode/oh-my-opencode-slim.jsonc (cebula preset — 7 agent model keys) · docs/dev-infra-audit/tickets/DIA-064.md (NEW) · .opencode/learnings/external-patterns/2026-08-07-cebula-preset-revert.md (NEW) · CHANGELOG.md.
- **Scope:** Only cebula preset touched — opencode-go, free presets, and council entries unchanged.
- Pending user: restart OpenCode (config takes effect on next run) + post-restart smoke.

## 2026-08-07 — Research-to-persistence pipeline (researcher → conspecter handoff)

- **Change:** NEW skill `.opencode/skills/research-pipeline/SKILL.md` (4-phase orchestrator workflow: research → persistence decision → conspecter dispatch → memory shelf verification); NEW agent file `.opencode/agents/researcher.md` (output contract with `PERSISTENCE_RECOMMENDED` flag); `orchestratorPrompt` added to researcher in all 3 presets (opencode-go, cebula, free); NEW learning entry `external-patterns/2026-08-07-research-persistence-pipeline.md`; `learnings/index.md` pointer added.
- **Reason:** Close gap where @researcher returned conversation-only findings with no path to @conspecter persistence. Two confirmed missing knowledge artifacts (2026-08-06).
- **Files:** .opencode/skills/research-pipeline/SKILL.md (NEW) · .opencode/agents/researcher.md (NEW) · .opencode/oh-my-opencode-slim.jsonc (orchestratorPrompt ×3 presets) · .opencode/learnings/external-patterns/2026-08-07-research-persistence-pipeline.md (NEW) · .opencode/learnings/index.md (pointer).
- **Review:** independent review — 2 Major (CHANGELOG + skill reference in orchestratorPrompt), 4 Minor.

## 2026-08-06 — Silent session logging (silent-session-logging, Option E)

- **Change:** delegation-observer plugin now writes canonical session JSONL silently to `.opencode/session/messages.jsonl` + `registry.jsonl` (writer:"plugin", row_id, event_uuid); new `log_decision` tool (permission "allow" on orchestrator only in `.opencode/opencode.jsonc`); `messages.md` is now a DERIVED VIEW regenerated by `scripts/session-log render` (never hand-edited); P5 gate tool `.opencode/scripts/jsonl-cross-check.sh` (`--since` default 2026-08-06T19:30:00Z, ≥99% completeness, ±5s tolerance, exit 0/1/2) verifies registry↔messages completeness.
- **Reason:** eliminate orchestrator manual dual-write discipline (hand-editing messages.md + messages.jsonl after every delegation); plugin-authored audit trail; fail-soft writers + gate cannot mask a dead plugin.
- **Files:** .opencode/plugins/delegation-observer.ts · .opencode/opencode.jsonc (log_decision allow) · .opencode/session/messages.jsonl · .opencode/session/registry.jsonl · .opencode/scripts/jsonl-cross-check.sh · docs/dev-infra-audit/NEXT-RUN.md · .opencode/oh-my-opencode-slim/orchestrator_append.md (JSONL Sidecar removal) · .opencode/oh-my-opencode-slim.jsonc (orchestrator prompt one-liners ×3) · docs/dev-infra-audit/tickets/DIA-051.md (resolved-by-implementation) · NEW .opencode/learnings/external-patterns/2026-08-06-silent-session-logging.md.
- **Review:** independent review — 2 Critical findings closed (F1 changelog registration, F2 learnings registration); DIA-051 closed resolved-by-implementation; P5 smoke 100% (in-universe 8/8), `make jsonl-cross-check` exit 0 (registry 213 task_success = 205 legacy + 8 in-universe).
- Pending user: commit decision (nothing staged/committed by the executor lane).

## 2026-08-05 — Copilot PR #2 review fixes (dev-infra-copilot-fixes, Commit A + Commit B)

- **Change:** 8 owner-confirmed Copilot review fixes on PR #2, split across two commits along the AGENTS.md routing boundary. **Commit A (dev-infra, §2.4 → @reviewer):** #1 `scripts/dev-stack.sh` output corrected (names only `author-studio` as turbo-managed; drops fabricated URLs; `api-server`/`publishing` noted as started separately); #4 `tools/opencode-docker/Dockerfile` four `*)` fail-fast branches added (`NODE_ARCH`/`MISE_ARCH`/`SNIP_ARCH`/`UV_ARCH` — unsupported TARGETARCH now errors instead of silent build corruption); #6 `dev-entrypoint.sh` zero-byte secret skip (`[ ! -s "$file" ]` → `[skip]` + degraded boot, never crash); #7 `scripts/dev-secrets-profile.sh` same parity skip; companion `secrets/README.md` sync note + 2 new bats tests (Dockerfile arch-failfast static grep, empty-secret skip). **Commit B (AI-tooling config, §10 → @ai-specialist):** #2 `telemetry-report.md` + #3 `telemetry-inspect.md` hardcoded `/home/qualt` paths → `${HOME:?HOME must be set}` POSIX fail-fast guards (0 `/home/qualt` literals); #5 `.config/opencode/skills/book-rag/knowledge-bases.yaml` committed runtime cache deleted + path-scoped root `.gitignore` entry; #8 `.opencode/memory/failures.md` duplicated MCP bullet deduped (1 bullet + Resolution). Plus executor lane: failures.md Resolution indent 3→2 spaces (1-char Minor).
- **Reason:** Copilot review flagged misleading dev-stack output, missing fail-fast defaults in arch dispatch (silent malformed-URL builds), zero-byte secrets exported as empty env vars (masks developer-provided values, contradicts secrets/README.md), machine-specific paths in committed commands (portability), committed runtime cache churn (generated artifacts out of version control, matches `knowledge/*/sources/` pattern), and duplicated memory entry (hygiene).
- **Files:** scripts/dev-stack.sh · tools/opencode-docker/Dockerfile · dev-entrypoint.sh · scripts/dev-secrets-profile.sh · secrets/README.md · scripts/__tests__/opencode-docker.bats · scripts/__tests__/dev-entrypoint.bats · .opencode/commands/telemetry-report.md · .opencode/commands/telemetry-inspect.md · .gitignore · .opencode/memory/failures.md · NEW .opencode/learnings/external-patterns/2026-08-05-copilot-pr2-config-fixes.md · learnings/index.md (pointer row) · CHANGELOG.md.
- **Design decisions / review:** two-chain review matrix per tasks.md — Commit A → @reviewer (two-axis: Standards + Spec fidelity; `make test-shell` + `make test-infra`); Commit B → @ai-specialist (§10.5 independent review; `make test-config`). §10 Phase 1 gate findings registered 2026-08-05 (ai--1, row 371, session ses_02f7d3527ffe7vY9c5406DJ6Lb) — incl. CORRECTED rationale: `query_rag.py` at `.opencode/scripts/query_rag.py` (1328 lines) is NOT orphaned; cache regenerated on demand (`get_kb_list` :292 → `_load_kb_cache` :314 → `_save_kb_cache` atomic write :236-263). Query_rag.py itself untouched (book-rag refactor out of scope). No `.sdd/` governs the touched paths; secrets-loader `.sdd/` gap flagged in proposal, not invented here.
- Pending user: restart OpenCode (config changes take effect on next start) + commit decision (commit lane separate — nothing staged/committed by the executor lane).

## 2026-08-04 — Copilot legacy-annual pricing: observer fallback ≤6x (gpt-5-mini)

- **Change:** cebula preset observer fallback `github-copilot/gemini-3.5-flash` (14x credit multiplier) → `github-copilot/gpt-5-mini` (0.33x) — GitHub's #1 recommended vision model on the legacy annual plan; knowledge update (NEW learnings `2026-08-04-copilot-legacy-annual-pricing.md` + index pointer row) and ai-assist-sources.yaml role_mapping observer label.
- **Reason:** legacy ANNUAL GitHub Copilot Pro plan uses credit-multiplier (premium-request) billing — the credit multiplier governs cost. gemini-3.5-flash = 14x worst deal (~21 premium interactions/month); gpt-5-mini = 0.33x cheapest (~909/month); owner policy: models ≤6x multiplier. 42x cheaper per interaction.
- **Files:** oh-my-opencode-slim.jsonc (cebula observer array fallback) · ai-assist-sources.yaml (role_mapping observer label) · learnings/external-patterns/2026-08-04-copilot-legacy-annual-pricing.md (NEW) · learnings/index.md (pointer row + Last updated) · CHANGELOG.md.
- **Design decisions / review:** ai--3 authoritative research (fetched 2026-08-04, docs.github.com model-multipliers-for-annual-plans); §10 Phase 2 owner approval — observer fallback ≤6x (gpt-5-mini) + full knowledge update; primary opencode-go/kimi-k2.7-code [0] and last-resort opencode/big-pickle unchanged; opencode-go/free preset observers, council/councillor, coder/reviewer/designer models untouched.
- Pending user: dcp.jsonc `gemini-3.5-flash` cleanup — RESOLVED (both occurrences removed in ebbe17c).

## 2026-08-04 — DIA-045 observer model fix: cebula preset kimi-k2.7-code primary

- **Change:** cebula preset observer primary model corrected to opencode-go/kimi-k2.7-code (multimodal); stale nonexistent github-copilot/gemini-3.6-flash replaced with github-copilot/gemini-3.5-flash fallback across 3 files (oh-my-opencode-slim.jsonc cebula observer array, dcp.jsonc model limits ×2, ai-assist-sources.yaml role_mapping label).
- **Reason:** post-restart Smoke-1 dispatch error "Model not found: github-copilot/gemini-3.6-flash"; §10 Phase 1 root-cause — F7 incomplete (only opencode-go preset updated, cebula missed); Phase 4 cod-3 3 edits; Phase 5 ai--3 APPROVE-WITH-FINDINGS (F1..F4 dispositioned); Smoke-1 re-run (obs-2) PASS.
- **Files:** oh-my-opencode-slim.jsonc (cebula observer array) · dcp.jsonc (modelMaxLimits/modelMinLimits) · ai-assist-sources.yaml (role_mapping label).
- **Design decisions / review:** opencode-go/kimi-k2.7-code promoted to cebula observer primary (multimodal) with github-copilot/gemini-3.5-flash fallback; superseded gemini-3.6-flash GA claim annotated in learnings (2026-08-03-cebula-copilot-rebalance.md); §10 Phase 5 ai--3 APPROVE-WITH-FINDINGS (0 Blocker/Critical/Major — F1 ACCEPTED, F2 deferred, F3 closed, F4 no-action).
- Pending user: 3-edit change set remains uncommitted — owner commit decision pending.

## 2026-08-04 — DIA-045 config-drift cleanup: stale aliases, observer model, HANDOFF template

- **Change:** §10 lane fixed the DIA-045 config-drift backlog fix-now set — stale "boss"→"orchestrator" aliases (coder ×3 prompts, architector/analyzer orchestratorPrompts, practice-protected.md), underscore→hyphen agent names (ai-specialist, resource-manager) across ai-assist-sources.yaml + prompts, opencode-go observer → kimi-k2.7-code (multimodal) + role_mapping update, HANDOFF.md template restructured (## Prognosis for next cycle wrapper + 5 ### subsections matching the batch-approval gate).
- **Reason:** DIA-045 (config drift from ai--1 22-finding audit, 2026-08-04); owner-approved fix-now set + 2 anomaly dispositions.
- **Files:** oh-my-opencode-slim.jsonc · ai-assist-sources.yaml · practice-protected.md · openspec/templates/HANDOFF.md.
- **Design decisions / review:** §10 two-sided audit — ai--1 Phase 1 gate → ai--2 Phase 5 APPROVE → cod-7 independent re-confirm; HANDOFF template option A (template carries the wrapper, gate check stays `## Prognosis for next cycle`).
- Pending user: restart OpenCode + 4 post-restart smoke items (observer dispatch kimi, HANDOFF gate on template-produced HANDOFF, @ai-specialist/@resource-manager name resolution, coder escalation "orchestrator"); deferred items F18/F21/F15/F19/F20/F22 remain OPEN; commit pending owner decision.

## 2026-08-04 — Tickets System 2.0: Session-Attributed Delegation & Grounded Dispatch

- **Change:** Tickets System 2.0 — session-attributed delegation & grounded dispatch (fixes false delegation + enables exact subagent-session recall).
- **Reason:** 3 confirmed false-delegation incidents in 2026-08-04 dev-audit (task() silently dropped when batched with edit()); tickets lacked session_id/lane_id/files_touched/artifacts linkage (ana005 report).
- **Files:** delegation-observer.ts (NEW plugin), get-my-session-id.ts (NEW tool), opencode.jsonc, jsonl-stats.sh (F17 fix + dangling/orphan/telemetry), oh-my-opencode-slim.jsonc (PURE-DISPATCH ×3), orchestrator_append.md, NEXT-RUN.md §2, _TEMPLATE.md, to-tickets SKILL.md, session/README.md, registry.jsonl (gitignored, plugin-created).
- **Design decisions:** plugin-as-hooks (OpenCode native hooks closed not-planned); task_id success-path-only (PR #13958 unmerged) + session.children fallback + session.prompt recall; registry.jsonl = business cross-ref index (gitignored) + native session APIs = lifecycle; gen_ai.agent.id + ticket_id = labeled Project Extensions (semconv v1.42.0); dispatch_state lifecycle invoked|running|completed|failed (+SILENT_FAILURE status); __task_no_id__ group_key exclusion; gatedSessions Set O(1); alert_note column.
- **Review:** §10 two-sided audit — Phase 1 ai--1 APPROVE-WITH-CHANGES, recheck ai--2 UPDATES-REQUIRED, Phase 5 ai--3 APPROVE (95%); @reviewer rev-1 (BLOCKERS) → cod-3 → rev-2 (17/17 closed) → cod-4 (RR fixes) → rev-3 (5/5 closed, 0 regressions).
- Pending user: restart OpenCode + post-restart smoke (V5/V6/V10–V13 + S1/S2) + commit decision.

## 2026-08-04 — F1–F5 opencode-config stale-reference cleanup (from ai--1 critical review)

- **Change:** ai-specialist prompt global knowledge paths → project-relative (.opencode/oh-my-opencode-slim/knowledge/); ai-assist-sources.yaml role_mapping → AGENTS.md §9 current names; tier3_local_references cross-project visualPoetryResearch entries removed, memory_shelf repointed to this repo; opencode_best_practices → project-relative; NEXT-RUN.md @code-executor → @coder (×2, deduped).
- **Reason:** 22-finding critical review (1 Blocker + 4 Critical); owner disposed Blocker+Critical now, rest → DIA-045.
- **Verification:** make test-config exit 0; ai--2 Phase 5 APPROVE. Uncommitted.

## 2026-08-03 — Handoff protocol modernization (G1–G9)

- **Change:** §10-approved modernization of the orchestrator handoff protocol per the handoff-protocol audit (learnings 2026-08-03-handoff-protocol-audit.md). 9 files modified, 1 script created, 0 deleted. Uncommitted.
- **Reason:** Audit found 3 correctness defects (G1 Critical batch-approval boot never executed; G2 Major HANDOFF.md staleness; G3 Major messages.md non-monotonic numbering) + modernization of continuity mechanics (G4 compaction/SELF-RERUN split, 30% primary / 50% safety-net; G5 prompt-enforced pre-handoff verification gate; G6 verification_result section) + tooling (G7 adr.md 64k→1M; G8 verified no-op; G9 jsonl-stats consumer).
- **Files:** docs/dev-infra-audit/NEXT-RUN.md · .opencode/oh-my-opencode-slim.jsonc · .opencode/oh-my-opencode-slim/orchestrator_append.md · .opencode/skills/review-re-verify/SKILL.md · openspec/templates/HANDOFF.md · openspec/changes/dia-redispatch-cycle/design.md · .opencode/memory/adr.md · .opencode/session/README.md · NEW .opencode/scripts/jsonl-stats.sh · Makefile
- **Design decisions:** batch-approval ENFORCED not deprecated (G1); HANDOFF-REFRESH milestone-based rewrite (G2); JSONL-canonical + strictly monotonic numbering (G3); native compaction handles raw pressure, SELF-RERUN = campaign-state transfer with 30% primary/50% hard-cap (G4); plugin-free prompt gate (G5, research: no native OpenCode hooks//goal — Option B); verifier-only Verification Result (G6).
- **Review:** ai-specialist ai--14 APPROVE-WITH-CHANGES (confidence 90%; C1 jsonl-stats execution resolved by coder evidence; M1 cosmetic not applied; M2 no-action); owner approved as-is (row 187).
- Pending user: restart OpenCode → post-restart smoke → commit decision.

## 2026-08-03 — Reviewer context-fork alignment (Options A+C)

- **Change:** Removed `teaching`, `playwright-browser`, `reflect` from reviewer skills array (×3 presets) — reviewer now loads `[book-rag, code-review-fowler, review-re-verify]`; appended `## FRESH-CONTEXT EVALUATION` section to reviewer orchestratorPrompt ("You receive only the diff, criteria, and coder's verification evidence — NOT the coder's reasoning, chain-of-thought, or self-justifications...").
- **Reason:** Anthropic fresh-context verification principle — a verifier must evaluate the code on its own terms with clean criteria, not be anchored to the builder's reasoning/narrative ("the agent doing the work isn't the one grading it"; "sees only the diff and the criteria you give it, not the reasoning that produced the change").
- **Files:** oh-my-opencode-slim.jsonc (reviewer skills ×3 presets; reviewer orchestratorPrompt).
- **Design decisions:** Option A+C from context-fork gap analysis (ai--1 audit): teaching → mentoring posture assumes coder intent; reflect → self-referential anchoring in re-review; playwright-browser → irrelevant context bloat. Option B (structured fixes-applied summary) deferred; O3/O4 remain deferred.
- **Review:** §10 ai-specialist APPROVE (6/6 PASS, coherence teaching-mode vs fresh-context = orthogonal, no tension).
- Pending user: restart OpenCode + functional smoke test.

## 2026-08-03 — Reviewing stage verification loop (Phase 1: O1/O2/O5/O6)

- **Change:** Added fix→re-verify→re-review loop to the reviewing stage. O1: orchestrator re-dispatches @reviewer after coder fixes (targeted re-review, max 2 cycles, escalation to owner). O2: coder must include verification evidence in handoff; reviewer demands it. O5: coder pre-handoff verification checklist. O6: reviewer findings-resolution table with evidence column.
- **Reason:** Anthropic engineering best practices — verification loop (worker ≠ judge), evidence-over-assertion, bounded iteration. §10 Phase 1 gate findings registered 2026-08-03.
- **Files:** AGENTS.md (§2.3 renumbered + §2.3.1 new), oh-my-opencode-slim.jsonc (coder prompt ×3 presets, reviewer orchestratorPrompt, reviewer skills ×3 presets), .opencode/skills/review-re-verify/SKILL.md (NEW), orchestrator_append.md (review gate row updated).
- **Design decisions:** O1/O6 reviewer protocol extracted to skill (code-review-fowler precedent — budget relief); O1 orchestrator behavior in AGENTS.md (canonical source); O2/O5 in coder prompt (headroom available).
- **Review:** §10 Phase 5 ai-specialist APPROVE-WITH-CHANGES (1 Minor tool-limitation, 1 Suggestion — coder prompt 1068ch documented); Phase 6 registration 2026-08-03.
- Pending user: restart OpenCode + functional smoke test.

## 2026-08-03 — OTel GenAI JSONL sidecar + ticket format standardization

Change: orchestrator now dual-writes .opencode/session/messages.jsonl (OTel GenAI
semconv-genai v1.42.0 attribute names, forward-only) alongside messages.md; ticket
ledger standardized to YAML frontmatter + harmonized enums (severity +Medium; status
+DEFERRED/MONITOR/IMPLEMENTED) + archive/ policy.
Reason: owner request — align orchestrator logging with OTel GenAI JSON convention;
standardize ticket formats (markdown+YAML frontmatter, kanban-ready, archive instead
of delete).
Files: .opencode/session/README.md + messages.jsonl (gitignored);
orchestrator_append.md; oh-my-opencode-slim.jsonc (3 preset prompts);
docs/dev-infra-audit/tickets/_TEMPLATE.md + DIA-003/006/030/034/037.md + README.md +
archive/README.md; .opencode/skills/to-tickets/SKILL.md.
Pending: restart OpenCode (prompts + skill take effect); post-restart smoke (JSONL
dual-write emits lines; to-tickets emits YAML frontmatter); commit decision after
smoke.

## 2026-08-03 — mattpocock/skills fork+adapt: 5 skills for OpenCode workflows

Change: Forked and adapted 5 skills from mattpocock/skills (MIT, 200k★) into
our workflows — domain-grilling (merged grill-with-docs+domain-modeling+grilling,
3-phase Socratic interview w/ CONTEXT.md glossary + .sdd ADR capture), to-tickets
(tracer-bullet vertical slices + blocking edges + expand-contract, published to
DIA ticket ledger), code-review-fowler (12-smell baseline for @reviewer),
resolving-merge-conflicts (never --abort discipline), diagnosing-bugs discipline
merged into debugging-workflow (global + project copies). Root CONTEXT.md created;
AGENTS.md §3/§2.3 + .sdd/README updated; DIA-037 filed for make test-skills gap.
Reason: gaps surfaced by §10 Phase 1 gate — persistent domain glossary (ana004
remediation), wide-refactor playbook, review smell descriptions, bug-diagnosis
discipline, merge-conflict process. Owner approved all 5 (row 99); design arc-1
(row 100-101); independent review approve-with-changes (row 103-104); fixes applied
(row 105).
Files: .opencode/skills/{domain-grilling,to-tickets,code-review-fowler,resolving-merge-conflicts}/SKILL.md,
CONTEXT.md, ~/.config/opencode/skills/debugging-workflow/SKILL.md,
.opencode/skills/debugging-workflow/SKILL.md, .opencode/oh-my-opencode-slim.jsonc
(12 skill-array edits across 3 presets + reviewer prompt ref), AGENTS.md, .sdd/README.md,
docs/dev-infra-audit/tickets/{_TEMPLATE.md,DIA-037.md,README.md}
Pending: owner restart OpenCode → smoke tests (skill activation ×5) → commit.

## 2026-08-03 — cebula preset rebalance: Copilot Pro utilization (observer → gemini-3.6-flash; conspecter/code-navigator/resource-manager → gpt-5-mini)
- **Change:** cebula preset rebalance — `observer` → `github-copilot/gemini-3.6-flash` (multimodal, replaces gpt-5-mini which is NOT multimodal — observer does visual/media analysis), `conspecter` → `github-copilot/gpt-5-mini`, `code-navigator` → `github-copilot/gpt-5-mini`, `resource-manager` → `github-copilot/gpt-5-mini`. All 4 moved agents keep their Go → free fallback chains (observer: kimi-k2.7-code → big-pickle; conspecter/code-navigator/resource-manager: deepseek-v4-flash ×2). dcp.jsonc: `github-copilot/gemini-3.6-flash` added to both `modelMaxLimits` ("50%") and `modelMinLimits` ("25%"), mirroring the `github-copilot/gemini-3.1-pro-preview` entry.
- **Reason:** shift subscription quota drain from OpenCode Go ($60/mo cap) toward Copilot Pro (1,500 credits/$15) targeting ~70% Copilot utilization; per §10 GATE research 2026-08-03.
- **Files:** `.opencode/oh-my-opencode-slim.jsonc` (cebula preset models), `.opencode/dcp.jsonc` (max/min limits), `.opencode/learnings/external-patterns/2026-08-03-cebula-copilot-rebalance.md`
- Pending user: restart OpenCode + monitor Copilot utilization via `token_stats` (2-week plan in learnings entry; flip conspecter back to Go if Copilot >80% by mid-month).

## 2026-08-03 — Split ai-specialist into resource-manager + ai-specialist (DIA-007)
- **Change:** split ai-specialist into `resource-manager` (NEW artifact-producer curation agent: model opencode-go/deepseek-v4-flash, edit scoped to `.opencode/oh-my-opencode-slim/knowledge/*` only, bash curl/wget/trafilatura, task: allow → @researcher/@conspecter, mcps [websearch]; owns ai-assist-sources.yaml curation, Tier-1 caching, Tier-2 re-fetch, awesome-opencode star-count eval) + `ai-specialist` (RETAINED name/roles: pure-analyst qwen3.7-plus, §10 gate + independent review + telemetry receiver; prompt + step-10 source-referral; orchestratorPrompt trimmed to ~2-line routing summary)
- **Reason:** owner approved full split (Alternative D) 2026-08-03 — all 6 design decision points approved; fixes pre-existing stale WINDOWS paths in ai-assist-sources.yaml (6 paths → Linux)
- **Files:** the 11-file change set (opencode.jsonc, oh-my-opencode-slim.jsonc, practice-protected.md, global AGENTS.md naming row, orchestrator_append.md, boss_append.md, onboarding.md, NEXT-RUN.md, ai-assist-sources.yaml, opencode-best-practices.md, DIA-007.md)
- Pending user: restart OpenCode + functional smoke test, then commit.

## 2026-08-02 — Orchestrator operating model: read-restriction + session continuity + NEXT-RUN manual
- **Permission change (DIA-036):** `.opencode/opencode.jsonc` orchestrator permission block rewritten — BEFORE: flat `read/glob/grep: allow` + `write: deny` + `edit/apply_patch/ast_grep_replace/bash/webfetch/envsitter*: deny`; AFTER: `read` path-scoped to `.opencode/session/*`, `docs/dev-infra-audit/NEXT-RUN.md`, `AGENTS.md`, `.opencode/practice-protected.md` (everything else denied), `edit` path-scoped to `.opencode/session/*` (covers write+apply_patch per OpenCode docs — flat `write` key removed), `glob` path-scoped to `.opencode/session/*`, `grep` denied. Orchestration tools unchanged: task/cancel_task/list/lsp/question/wait_for_user/todowrite/skill/websearch allow. No other agent block touched.
- **Session continuity protocol:** orchestrator appends one row to `.opencode/session/messages.md` after EVERY delegation result and user decision (`# | timestamp | from | to | lane/ticket | result | next-action`); writes `.opencode/session/current-handoff.json` on self-rerun.
- **Self-rerun at >= 50% context:** orchestrator detects via `token_stats`, computes (input+output)/model_context_window (lookup table: qwen3.7-max 1M, qwen3.7-plus 131K, deepseek-v4-flash 64K, big-pickle 200K, else 131K), writes HANDOFF.md + final log row, then tells the user to start a fresh session.
- **`docs/dev-infra-audit/NEXT-RUN.md`:** new operating manual — boot sequence (HANDOFF → messages.md → NEXT-RUN → practice-protected), orchestrator operating rules (read/write restrictions, messages-log discipline, self-rerun, delegation map, strict workflow), audit rerun flow (7 gates in order), open tickets to close (DIA-003/006/007/030/034 with dispositions), clean-cycle definition, session continuity.
- **OMO prompt additions:** `oh-my-opencode-slim.jsonc` — all 3 presets (opencode-go, cebula, free) orchestrator blocks got a compact "Orchestrator Operating Rules" `prompt` (same text each): delegation-only + forbidden repo reads (path-scoped permission), messages.md after every delegation, self-rerun handoff at >=50%, strict workflow adherence (interview gate, §10, review gates).
- **Gitignore:** `.opencode/session/` added — transient orchestrator session state is never committed.
- Validation: `make test-config` PASS (4/4 JSONC). `git check-ignore .opencode/session/messages.md` → ignored. Diff confirms only the orchestrator permission block changed in opencode.jsonc.
- **Follow-up (same day):** reordered the three path-scoped orchestrator permission objects (`read`/`edit`/`glob`) so the catch-all `"*": "deny"` rule comes FIRST and specific `allow` paths follow — per OpenCode permission docs, "last matching rule wins" and the common pattern puts `"*"` first; valid under both order-based and specificity-based matcher semantics. No allow/deny values lost or added.
- Pending user: restart OpenCode + functional smoke tests (orchestrator must delegate, read-restriction enforced, messages.md logging works).

## 2026-08-02 — Dev-infra config audit fixes (DIA-001/003/016/017/019/020, F3 lane)
- DIA-001 (Minor): `opencode.jsonc` `references.shelf.path` `".opencode"` → `".opencode/memory-shelf.yaml"` — the shelf key pointed at a directory instead of the actual shelf index file (the description already named memory-shelf.yaml as the entry point).
- DIA-019 (Major): `skills/book-rag/SKILL.md` (8 refs) + `commands/rag.md` — replaced `~/.config/opencode/scripts/query_rag.py` with `.opencode/scripts/query_rag.py` (repo-relative). The repo's canonical script lives at `.opencode/scripts/query_rag.py`; `~/.config/opencode/scripts/` is a machine-local copy and must not be referenced from the repo. Verified `grep -rn "~/.config/opencode/scripts" .opencode/` → clean.
- DIA-017 (Minor): `oh-my-opencode-slim.jsonc` ai-specialist prompt — knowledge-source path `~/.config/opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` → `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` (the global path does not exist; the project file does — verified).
- DIA-020 (Minor, global OUTSIDE repo): `~/.config/opencode/oh-my-opencode-slim.jsonc` — added `"!openspec-propose"` to orchestrator `skills` in all 3 presets (`opencode-go`, `cebula`, `free`) so global matches project `["*", "!openspec-propose"]`. Backup: `~/.config/opencode/oh-my-opencode-slim.jsonc.bak-20260802`. No other global keys touched.
- DIA-003 (evaluate → DEFER): skills-lock.json pinning of the 15 project skills — NOT done. Evidence: (1) lock format is remote-github-skill only (`source`/`sourceType: "github"`/`skillPath`/`computedHash`) — local `.opencode/skills/*` don't fit; (2) zero consumers in the vendored fork (`rg skills-lock` in fork source/docs → nothing; fork is REFERENCE-ONLY per REFERENCE-ONLY.md, not the running npm 2.2.8 plugin); (3) local skills are already pinned by git. Ticket stays OPEN for the reconcile lane.
- DIA-016 (evaluate → intentional): global `~/.config/opencode/dcp.jsonc` left as the sparse `maxContextLimit: "50%"` fallback; project `.opencode/dcp.jsonc` (14 models, max/min limits) is project-scoped and takes precedence inside this repo. Evidence: global file is a generic default for all projects; the 14 model IDs are this repo's lineup; aligning global would leak repo-specific tuning into the user's machine-wide config. Divergence documented, no change.
- Validation: `make test-config` PASS (4/4 JSONC). `pytest .opencode/scripts/test_query_rag.py .opencode/scripts/test_query_web.py` in dev container (`uv run --with pytest`): 68 passed, 3 failed — the 3 failures (`test_unknown_hashtag`, `test_hashtag_with_digits`, `test_hashtag_with_underscore`) are pre-existing hashtag fuzzy-match bugs in untouched `query_rag.py`, reproduced identically at baseline 6ba7200; out of scope for this config lane.
- Pending user: restart OpenCode — config changes take effect on next start (DIA-001/017/019/020 are loaded at startup).

## 2026-08-02 — Fix context7 remote MCP registration
- Change: Fix context7 remote MCP registration (canonical Authorization Bearer header, oauth:false, timeout 15000) in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json.
- Reason: Context7 MCP tools (resolve-library-id / query-docs) not exposed: non-canonical auth header + OAuth auto-detect interference + tight 5s timeout; per ai-specialist research of upstash/context7 server source.

## 2026-08-02 — Config audit fixes (P1–P9 + N1–N5)
- P1: `.opencode/tui.json` plugin key dropped (dead `file:///workspace/` Docker path + unpinned `dcp@latest`) → `{}`; plugin ownership is `opencode.jsonc`.
- P5: removed dead `github:raisbecka/opencode-subagent-output` from project plugin array (repo has no `package.json`; never loaded; global uses local `~/.config/opencode/plugins/subagent-reporter.ts`).
- P4/N6: removed `agent.orchestrator.model` from `opencode.jsonc` — a user-agent model string overrides the preset array and disables its fallback chain (verified dist:40228-40241); OMO cebula preset owns model routing.
- P7: council block indentation fixed (cosmetic).
- P3: project `disabled_agents` `[]` → `["oracle","fixer","explorer","librarian"]` — project `[]` was overriding the global disable list (deepMerge replaces arrays), re-enabling native agents contrary to AGENTS.md §9. Now aligned.
- P6: `dcp.jsonc` pruned 6 stale model entries (`github-models/*` ×3, `github-copilot/gemini-3-flash-preview`, `opencode-go/deepseek-v4-pro`, `opencode-go/kimi-k2.6`) from both max/min limits; 14 valid entries kept.
- N4: `validate-opencode-config.sh` now covers `opencode.jsonc` + `oh-my-opencode-slim.jsonc` + `dcp.jsonc` + `tui.json`.
- P8: `.opencode/oh-my-opencode-slim/REFERENCE-ONLY.md` — vendored fork checkout documented as reference-only (not the running plugin; npm 2.2.8 is live).
- P9: `.env.example` got `CONTEXT7_API_KEY=` placeholder (real key goes in `.env` — user step).
- N1–N3 (global `~/.config/opencode/`): `cebula.designer` model fixed (invalid `github-copilot/gemini-3-flash-preview` → `[claude-sonnet-4.5, kimi-k2.7-code, big-pickle]`); council `github-models` seats (`gemini-3-flash`, `gemini-2.5-pro`) consolidated into one `github-copilot/gemini-3.1-pro-preview` seat (5→4); `github-models` provider block removed from global `opencode.jsonc` (auth-broken).
- Review: independent @ai-specialist review PASS (14/14, no scope creep, no dangling references). Validation: `validate-opencode-config.sh` exit 0 on all 4 files; `opencode models` cross-check (residual: `opencode/deepseek-v4-flash` not in model list — pre-existing, kept).
- Pending user: add `CONTEXT7_API_KEY` to `.env`; restart OpenCode.

## 2026-08-02 — Boss delegation enforcement: orchestrator-first default (Phase 2)
- **Root cause:** `default_agent: "boss"` resolved to a bare config agent (model+color only, no prompt, no permission restrictions) while the plugin's real delegating agent is registered as `orchestrator`. The npm 2.2.8 config hook only overrides `default_agent` when unset/subagent, so `boss` (truthy primary) won — sessions ran a plain coder that did engineering work itself → context overflow + session restarts.
- Changed `default_agent` → `"orchestrator"` so sessions start in the plugin's delegating agent.
- Replaced bare `agent.boss` block with `agent.orchestrator` (model `opencode-go/deepseek-v4-flash`, color `#6366F1`) with mechanical enforcement: `edit/write/apply_patch/ast_grep_replace/bash` deny + `envsitter_set/add/delete/unset/annotate/format/reorder/copy` deny + `webfetch` deny (save_binary disk-write risk). Orchestration tools remain allow: `task/cancel_task/read/glob/grep/list/lsp/question/wait_for_user/todowrite/skill/websearch`.
- Created `.opencode/oh-my-opencode-slim/orchestrator_append.md` — the strict delegation workflow loaded by 2.2.8 (`loadAgentPrompt("orchestrator", ...)` → `orchestrator_append.md`): HARD RULE no-self-engineering, Interview-First Gate (@openspec-plan → spec → vertical slices → @coder), Fast-Path Opt-In, Context Budgets, Change Routing, **new Verification Discipline** (orchestrator never runs verification — it reviews results from specialists, communicates to user, or restarts cycle for rework/bugfix), Mandatory Final Step via @memory-manager.
- `boss_append.md` kept in place as dead historical reference (2.2.8 never loads it); `orchestrator_append.md` is the live prompt file.
- Independent review (ai-specialist): initial BLOCKER was a false positive (reviewer cited fork source `index.ts:495`; running 2.2.8 uses `loadAgentPrompt("orchestrator")` — verified in dist). Valid findings applied: envsitter + webfetch denies.
- Validation: `validate-opencode-config.sh` OK; jsonc parses; append file verified.
- Pending: restart OpenCode + functional smoke test (boss must delegate, never edit).

## 2026-08-02 — Copilot model cleanup in cebula preset (Phase 1)
- Fixed `designer`: replaced invalid `github-copilot/gemini-3-flash-preview` (not in OpenCode model list — silently fell through to Go kimi) with `github-copilot/claude-sonnet-4.5` (GA, 6x, vision). Chain now: claude-sonnet-4.5 → kimi-k2.7-code → big-pickle.
- Rebuilt `council` balanced lineup: gemini-3.1-pro-preview (6x) + gpt-5.3-codex (6x) + claude-sonnet-4.5 (6x) + deepseek + qwen (Go) = ~18 premium/run.
- Deleted dead `github-models` provider block from `opencode.jsonc` (auth-broken) + both `github-models/*` council seats (gemini-3-flash, gemini-2.5-pro).
- `memory-manager` kept on `github-copilot/gpt-5-mini` (already optimal: cheapest premium @ 0.33x).
- Verified via `opencode models`: all referenced models exist; `make test-config` passes.

## 2026-08-02 — Interview-first spec-authoring enforcement (Phase 1)
- Rewrote `skills/openspec-propose` + `/opsx-propose`, `/opsx-new`, `/opsx-continue`, `/tdd-cycle` to interview-first: mandatory Socratic interview via @openspec-plan, artifact synthesis from interview transcript only, `openspec validate` before apply. Removed one-shot "generate all artifacts / keep momentum" behavior.
- Boss skills denylist in all 3 OMO presets: `["*"]` → `["*", "!openspec-propose"]`.
- Added Fast-Path Opt-In gate (explicit "fast-path approved" + eligibility checklist + audit trail; NEVER auto-classify) and Interactive Review Gate row to `boss_append.md`.
- Extended `@openspec-plan` orchestratorPrompt with deep interview protocol (Full/Compressed/Skip depth modes, silent context scan, one-question-at-a-time with recommended answers, Q1–Q11 incl. numerical-invariants battery, transcript-only synthesis).
- Added Review Disposition zone + Artifact Ownership Tracking to `practice-protected.md`.
- Added `scripts/test-interview-enforcement.sh` (5 checks) + registered in Makefile test targets (script path: `scripts/test-interview-enforcement.sh`).
- Decision: Option C — no forks, plugins auto-update (npm oh-my-opencode-slim@2.2.8 unchanged). Phase 2 (compiled boss gate) deferred.
