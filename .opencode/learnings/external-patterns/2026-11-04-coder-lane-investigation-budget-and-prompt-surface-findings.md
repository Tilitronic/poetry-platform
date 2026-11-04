# Coder lane prompt surface: no investigation budget, injected maintenance comment, append-layer recency bias (2026-11-04)

- **Date:** 2026-11-04
- **Ticket:** DIA-261104-dexw (observation source DIA-260827-ft3z). Related: DIA-261104-xw9y (Check B blind spot).
- **Status:** transcription of findings under DIA-261104-dexw (Section 2.5 step 1).

## Observation

A coder lane spent roughly 100 tool calls to answer a question that was fully answerable in 3: "does any test execute .opencode/scripts/validate-opencode-config.sh or lib/jsonc-parse.js --lockstep". Pattern: about 25 near-identical repo-wide greps with varied flags, one git rev-list --all | head -200 | while read | git grep loop, an inline JSONC comment-stripper written twice while an in-repo utility existed, three greps seeded by phrases quoted in the dispatch WHY text, and one multi-thousand-token prompt dump into context. The conclusion was correct; the cost was not.

## Verified findings (all cited against files read this session)

1. The OMO loader does NOT strip HTML comments. Loader body in the deployed package oh-my-opencode-slim@2.2.19 (dist/index.js:19927-19943) calls fs.readFileSync(path, "utf-8") and returns it unmodified; resolvePrompt at :20026-20033 concatenates base + append. Consequence: the 17-line DIA-128 / DIA-260831-h3i4 maintenance comment at the top of .opencode/oh-my-opencode-slim/coder.md is injected into every coder child prompt and reads as instruction.
2. Append semantics are two different layers, not two halves of one document. <agent>.md REPLACES the built-in prompt; <agent>_append.md ALWAYS appends after whichever base wins. The append therefore (a) arrives last, so its wording wins on recency, and (b) survives an inline-prompt reintroduction that would silently drop the base. That is why the append's trailing "test-author or implementer" line would override a three-role rule stated in the base file.
3. The coder surface contains zero search-economy rules. Greps for search/grep/tool/budget/redundant/hypothesis/reuse/scope over .opencode/oh-my-opencode-slim/ returned no operative rule in coder.md or coder_append.md. The only hypothesis rule is scoped to failing tests.
4. The only mechanical backstop is doom_loop = deny, which halts on 3x IDENTICAL calls. Near-identical greps with varied flags pass it by construction. The base coder lane has no steps cap (only the two escalated lanes do).
5. Check B (the deny-first doc-drift gate) scans .opencode/agents/<name>.md and the preset orchestratorPrompt only. It never scans .opencode/oh-my-opencode-slim/<name>.md or <name>_append.md, which are the files the loader actually reads. For the coder pair that is a total blind spot. Tracked separately as DIA-261104-xw9y.
6. DIA-078 is confounded evidence for prompt-guardrail effectiveness. memory/failures.md:151 records that the root cause was the opencode-snip plugin mechanically rewriting bash commands via tool.execute.before, "not model behavior alone". A rule cannot be obeyed when the runtime rewrites the command. It remains valid evidence that mechanical enforcement is the reliable layer.
7. knowledge/model-registry.yaml:46 records swe_bench_verified: null for mimo-v2.6-flash. No reasoning score for that model exists in-repo; a "33/100" figure quoted during the discussion is not citable from this repository.

## Decisions (variant A, developer-approved)

- Three roles: implementer, test-author, verifier. Role is inferred from the task when not stated; RESULT: BLOCKED only on a genuine DIA-175 violation, a self-contradicting task, a missing fact after the investigation budget, or out-of-scope gate drift (after the lane finishes verifying its own changes).
- Investigation budget added to coder.md: two searches for a yes/no or locate question, enumeration exempt only for a full-list deliverable, stop-and-read on the same non-empty file set, explicit zero-hit reporting, one exhaustive search for existence proofs, interface-read before reimplementing a utility, edit only named paths.
- Pre-Handoff checklist scoped by role: RED test-author expects the target suite to FAIL; verifier skips build/lint/typecheck.
- Report schema: RESULT, ROLE, FILES_TOUCHED, VERIFICATION_EVIDENCE, COMMANDS_RUN, BLOCKERS, plus any fields the dispatch asks for.
- Split-file criterion: coder.md holds the contract and procedure; coder_append.md holds craft and isolation invariants; never write the same rule in both.
- Residual risk recorded: no steps cap on the base coder lane, so a runaway tail remains bounded only by doom_loop (identical calls). Deferred until session telemetry is measured.

## Tags

DIA-261104-dexw, DIA-260827-ft3z, DIA-261104-xw9y, DIA-128, DIA-260831-h3i4, DIA-078, DIA-175, investigation-budget, prompt-surface, append-layer, recency-bias, check-b, doom_loop, §10

status: applied (verified 2026-11-04: make test-config exit 0 with 473 ok / 0 fail; independent review ACCEPT after fix cycle 2/2; commits be2267a2 + 99d896d9)
