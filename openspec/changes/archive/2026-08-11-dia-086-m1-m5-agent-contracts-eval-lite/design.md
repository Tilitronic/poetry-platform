# Design: dia-086-m1-m5-agent-contracts-eval-lite

> **Status:** proposed · **Schema:** spec-driven · **skip_specs:** true
> **Proposal:** `openspec/changes/dia-086-m1-m5-agent-contracts-eval-lite/proposal.md`
> **Dependencies:** proposal.md (complete)
> **Unlocks:** tasks.md

## Context

### Design-authority reference

No new `.sdd/` module doc governs this change. The developer confirmed (locked decision #6): "Feature-level, no .sdd/ -- M1-M5 belong in openspec/changes/ (L3)." The traceability chain is:

- **`.sdd/README.md`** (three-layer model) -- this change lives in L3 `openspec/changes/`, not L1 `.sdd/`. No @architector dispatch required.
- **`.sdd/dia-redispatch-cycle/architecture.md`** (5-ADR seed) -- the only existing .sdd/ module doc. M3 falsification axis interacts with the cycle-management protocol: falsification claims surface at review time (before cycle-level escalation triggers C1-C5 would fire).
- **`architecture.md`** (root) -- authoritative for the application. Agent definitions and dev-infra scripts are not described there; they are governed by AGENTS.md and this change's proposal/design.
- **`knowledge/ana012-scientific-workflow-proposal/`** -- the originating analysis that proposed M1-M5 from the res012 50-source survey.
- **`knowledge/res012-scientific-methodology/`** -- the source conspect.

Per AGENTS.md 2.4 (dev-infra) and 2.5 (opencode config), changes within existing boundaries use the spec chain directly. No `@architector` dispatch.

### The two-slice architecture

This change contains ONE spec change with TWO independent implementation slices, following the volta-to-mise precedent (config + dev-infra in one change, two review chains):

| Slice             | Mandates          | Review chain (AGENTS.md) | Rationale                                                                                                       |
| ----------------- | ----------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------- |
| A: Config-tooling | M1 + M2 + M3 + M4 | @coder + @ai-auditor     | M1-M4 modify agent definitions, reviewer config, and skill files -- all opencode config surface (AGENTS.md 2.5) |
| B: Dev-infra      | M5                | @coder + @reviewer       | M5 adds a shell script + bats tests + Makefile target -- dev-infra surface (AGENTS.md 2.4)                      |

The slices are implemented and reviewed independently (disjoint file sets, different review chains); the only cross-slice dependency is task 8.1, which aggregates Slice A's validators 1.2 and 3.2 into the test-config chain, so Slice A must land before 8.1 completes.

### Observability constraint

M1/M2 headers are **declarative metadata** (schema-version, agent name, shelf-registration path). They are NOT coupled to `registry.jsonl` or session-level machine-readable references. The `evidence-source` field is free-form text (a file path or session-id string), not a structured foreign key. This was an explicit interview decision: the headers are human-readable contracts, not machine-queryable indices.

eval-lite (M5) is stdout-only (locked decision #4). No persistent results log, no `--log` flag.

## Goals / Non-Goals

**Goals:**

1. **M1: analyzer output contract.** Every analyzer report carries an additive HTML-comment header block after the title. Header fields: `schema-version: 1.0`, `agent: analyzer`, `claim-type` (finding | recommendation | risk), `evidence-source` (file path or session-id), `confidence: <High | Medium | Low>` (mandated by ana012 lines 67, 104 -- the mandate text is authoritative, locked decision #3 governs versioning only not field set), `shelf-registration` (.opencode/memory-shelf.yaml shelf.analyses). Migration strategy: FORWARD-ONLY -- existing reports are not retroactively updated; schema-version: 1.0 lets validators distinguish pre-M1/M2 reports (no header) from post (header present), council finding H.
2. **M2: conspecter output contract.** Every conspect carries an additive HTML-comment header block after the title. Header fields: `schema-version: 1.0`, `agent: conspecter`, `phase-a-source-count`, `phase-a-failures`, `shelf-registration` (.opencode/memory-shelf.yaml shelf.conspects). M2 `confidence` field: DECLINED -- the approved M2 mandate (ana012 line 68) is an experiment-log header only (phase-a-source-count / phase-a-failures); extending it to carry confidence would exceed the mandate. Recorded explicitly per council delta-suggestion ruling.
3. **M3: reviewer falsification axis.** `## Falsification` section in reviewer.md between `## Spec` and `## Summary`. Exactly 3 claims, each `[FALSIFICATION-N] file:line -- claim` with severity label from Standards-axis rubric. Claim + severity ONLY -- no fix direction (locked decision #2). Flows into existing practice-protected section-4 disposition loop. **Re-review semantics:** the Falsification triad is emitted on FULL reviews ONLY; re-review mode (`review-re-verify` SKILL.md, untouched per locked decision) tracks prior findings (verified-closed / still-open / partial) and emits NO new Falsification analysis; 'exactly 3' is per full review, not per re-review cycle; initial Falsification findings enter the existing findings-resolution table as ordinary findings via the generic prefix handling (review-re-verify's findings-table generator is prefix-agnostic -- confirmed by council inspection).
4. **M4: hypothesis question.** Identical question in openspec-propose and domain-grilling Phase 1, placed AFTER an explicit `<!-- FIRST-QUESTION -->` HTML anchor comment in each skill file. The anchor is placed after any frontmatter/license HTML comments and before any interview methodology prose. Defense-in-depth: each skill file ALSO gains at least one explicit example question ending in `?` in Phase 1 so the anchor is never orphaned. Exact wording (locked decision #5): "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?"
5. **M5: eval-lite harness.** Host-runnable `make eval-lite` target. Serial execution, <=60s, 20 curated tasks. Tab-separated 6-field format (6th field: `container-bound: yes|no`). Container-aware: detects dev-container state, skips container-bound tasks with a WARN line. Exit codes 0/1/2/3. Stdout only (locked decision #4). NOT wired into CI or verify-pre-commit.sh. Manifest header carries curation metadata (curation date, curator, review cadence).

**Non-Goals:**

- **No .sdd/ module doc** -- confirmed by developer (locked decision #6).
- **No fix-direction in falsification claims** -- confirmed by developer (locked decision #2).
- **No --log flag or persistent results log for eval-lite** -- confirmed by developer (locked decision #4).
- **No CI integration for eval-lite** -- stdout only, not wired into verify-pre-commit.sh.
- **No changes to review-re-verify SKILL.md** -- M3 adds to reviewer.md only; review-re-verify is UNTOUCHED.
- **No new verdicts or escalation paths for M3** -- falsification findings flow into existing section-4 disposition loop.
- **No machine-readable coupling between M1/M2 headers and registry.jsonl** -- evidence-source is free-form text.
- **No FFI/IPC/network** -- all mandates are in-process (Q9 confirmed: none).
- **No visual changes** -- Q10 confirmed: none.
- **No behavioral semantics beyond pass/fail** -- Q11 confirmed: pass/fail only.
- **No retroactive updates to existing analyzer/conspecter reports** -- migration is forward-only (pre-existing reports without the new header blocks are not updated; schema-version: 1.0 lets validators distinguish pre-change from post-change reports, council finding H).
- **No confidence field for M2 conspecter output contract** -- DECLINED; the approved M2 mandate is an experiment-log header only (phase-a-source-count / phase-a-failures); extending it to carry confidence would exceed the mandate (council delta-suggestion ruling, recorded explicitly).
- **No automated curation-quality validator for the eval-lite manifest** -- the 20-task curated set is sanity-read by one human or agent each review cycle (council alpha-suggestion, accepted as recorded as a manual review gate).

## Decisions

### Decision 1: HTML comment blocks for output contracts (M1, M2)

**Choice:** Additive HTML comment blocks (`<!-- ANALYZER-OUTPUT-CONTRACT ... -->`) placed after the title in generated reports/conspects.

**Rationale:**

- HTML comments are invisible in rendered Markdown (both GitHub and local viewers) but parseable by validation scripts.
- The block is additive -- it does not alter any existing content in the report/conspect.
- HTML comment syntax avoids collision with YAML frontmatter (which uses `---` delimiters) and with Mermaid blocks (which use ` ```mermaid `).
- The `schema-version: 1.0` field (locked decision #3) allows future schema evolution without breaking existing validators.

**Alternatives considered:**

- **YAML frontmatter field:** rejected -- frontmatter is consumed by static site generators; mixing agent metadata there risks unintended side effects in rendered output.
- **Markdown table at the top:** rejected -- visible in rendered output, clutters the report.
- **Separate sidecar file (.contract.json):** rejected -- decouples the contract from the report, creates a sync problem.

### Decision 2: Falsification section placement (M3)

**Choice:** `## Falsification` inserted AFTER `## Spec`, BEFORE `## Summary` in reviewer.md.

**Rationale:**

- The two-axis review flows: Standards axis -> Spec axis -> Falsification axis -> Summary. This ordering means the reviewer first checks code quality (Standards), then spec fidelity (Spec), then challenges the lane's own claims (Falsification), before writing the summary.
- Placing Falsification before Summary means the summary can reference falsification findings naturally.
- Placing it after Spec means falsification builds on the spec-fidelity analysis (if the code doesn't match the spec, falsification is moot).

**Alternatives considered:**

- **Before Spec:** rejected -- falsification should build on spec analysis.
- **After Summary:** rejected -- summary would need to be updated after falsification, creating a re-ordering problem.
- **Separate file:** rejected -- fragments the review, makes it easy to skip.

### Decision 3: Claim + severity only for falsification (M3) + re-review semantics

**Choice:** Each falsification claim is `[FALSIFICATION-N] file:line -- claim` with severity label. NO fix-direction field.

**Rationale:**

- Locked decision #2. The reviewer's job is to identify problems, not prescribe solutions. Fix-direction belongs in the practice-protected section-4 disposition loop where the developer decides accept/reject per finding.
- This separation mirrors the existing Standards-axis rubric: findings are severity-labelled, fixes are developer-disposed.

**Re-review semantics (council finding, design.md must state):**

- The Falsification triad is emitted on **FULL reviews only**; re-review mode (`review-re-verify` SKILL.md, untouched) tracks prior findings via its findings-resolution table (verified-closed / still-open / partial) and emits **NO new Falsification analysis**.
- 'Exactly 3' is **per full review**, not per re-review cycle.
- Initial Falsification findings enter the existing findings-resolution table as ordinary findings via the generic `[FALSIFICATION-N]` prefix handling (review-re-verify's findings-table generator is prefix-agnostic -- confirmed by council inspection).
- This keeps review-re-verify SKILL.md byte-identical to its pre-change state (untouched per locked decision).

### Decision 4: Identical wording for hypothesis question (M4) + deterministic anchor

**Choice:** "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?" placed AFTER an explicit `<!-- FIRST-QUESTION -->` HTML anchor comment in both skills.

**Rationale:**

- Locked decision #5. Identical wording ensures consistency across the two interview entry points (openspec-propose for feature specs, domain-grilling for design exploration).
- The `<!-- FIRST-QUESTION -->` anchor makes the placement rule deterministic and validator-checkable. The original spec said "after the first question in Phase 1" but both skill files describe Phase 1 methodology without any explicit `?`-ending example question line, so "first question" was non-operational (council blocker-class precondition).
- Defense-in-depth: each skill ALSO gains at least one explicit example question ending in `?` in Phase 1, so the anchor is never orphaned even if future edits move it.
- Placement rule (validator-checkable): hypothesis question's line number > anchor's line number in each file.

**Alternatives considered:**

- **Placement relative to first `?`-ending line:** rejected -- non-operational until an explicit example question exists (which we are adding as part of this change; anchor is more durable).
- **Placement relative to a Phase 1 heading anchor:** rejected -- the heading is already used for other content and the anchor is more specific.

### Decision 5: Tab-separated 6-field task format for eval-lite (M5)

**Choice:** Tab-separated fields: `<ticket-id>\t<command>\t<expected-exit-code>\t<source-suite>\t<failure-evidence>\t<container-bound>`. The 6th field is `yes` or `no` (case-insensitive; missing field = `no`). Comment lines start with `#`. Parser: `while IFS=$'\t' read -r ticket cmd expected source evidence container_bound`.

**Manifest header (curation metadata):** the manifest file begins with a `#` comment block recording curation metadata:

```
# eval-lite task manifest
# Curated: <ISO-8601 date>
# Curator: <agent or human identifier>
# Review cadence: <e.g. "monthly, aligned with DIA ledger sweep">
# Fields: ticket-id<TAB>command<TAB>expected-exit-code<TAB>source-suite<TAB>failure-evidence<TAB>container-bound
# container-bound: 'yes' = requires dev container running (skipped with WARN when container down); 'no' = host-runnable
```

This header is a convention documented in the manifest itself (not a separate metadata file). A manual review gate (one human or agent sanity-reads the 20-task curated set each review cycle) is acknowledged as the quality mechanism for curation -- no automated curation-quality validator is added (council alpha-suggestion, accepted as recorded).

**Rationale:**

- Tab separation avoids the quoting hell of CSV/space-separated formats when commands contain spaces, pipes, or special characters.
- The 6-field format captures everything needed for container-aware execution: what ran, what was expected, where it came from, what evidence to examine, and whether the container is needed.
- The curation-metadata header makes the manifest self-documenting and surfaces the review cadence for maintainers.
- Comment lines (`#`) allow the task manifest to carry section headers and documentation inline.
- Malformed lines (wrong field count) are skipped with WARN, not hard-failed -- this allows the manifest to evolve without breaking the harness.

**Alternatives considered:**

- **JSON:** rejected -- harder to hand-edit in a Markdown-adjacent workflow, no comment support.
- **CSV:** rejected -- command fields contain commas and quotes; escaping is fragile.
- **One-task-per-line with fixed positions:** rejected -- no comment support, no way to skip/disable a task.
- **5-field TSV (no container-bound column):** rejected -- container state is task-specific and must be declared per row so the harness can make per-skip decisions.

### Decision 6: Exit-code contract for eval-lite (M5)

**Choice:** Exit 0 (all runnable pass), 1 (any non-skipped task fails), 2 (file missing), 3 (no tasks defined).

**Container-skip semantics:** container-bound tasks are SKIPPED with a WARN line when the dev container is not running. For the 'all pass' condition (exit 0), **skips count as pass**: exit 0 when every non-skipped required task passes. The summary line reports `N passed, M failed, K skipped` so the operator sees the skip count explicitly.

**Rationale:**

- Matches the existing dev-infra exit-code convention (0 = success, 1 = check-found-issues, 2 = infra-error) from validate-agent-names.sh, audit-agent-tool-coverage.sh, check-pin-sync.sh.
- Exit 3 (no tasks defined) is a distinct code for the empty-manifest edge case, which is a configuration error, not an infra error.
- Treating skips as pass for exit-0 purposes preserves the DIA-094 host-runnable contract: a host operator with the dev container down can still run `make eval-lite` and get a meaningful result (exit 0 if all host-runnable tasks pass), rather than a spurious exit 1 because pytest tasks failed to invoke.
- Reporting skips separately in the summary line ensures the operator sees when a significant portion of the eval set was not actually executed.

### Decision 7: Host-runnable + container-aware eval-lite (M5)

**Choice:** `make eval-lite` runs on the host, not inside the dev container. DIA-094 host-runnable exemption (same category as test-config, test-shell). The harness is container-aware: it detects dev-container state and skips container-bound tasks with a WARN line rather than failing them.

**Container-detection mechanism:** `docker compose ps --format json dev` (JSON output of the `dev` service status).

- Parses the JSON with the project's existing `jq` allowlist (host `jq` is already required by `scripts/check-host-jq.sh`).
- Service running (Status contains `Up`) -> container is available -> run all tasks.
- Service absent / not running / daemon unreachable (command fails OR returns empty OR status is not `Up`) -> container is unavailable -> skip tasks whose 6th field is `yes`.
- Detection is done ONCE at harness start (not per-task) and cached in a shell variable.

**Skip -> exit-code mapping:**

| Exit | Condition                                                                 |
| ---- | ------------------------------------------------------------------------- |
| 0    | All non-skipped required tasks pass (container-bound skips count as pass) |
| 1    | Any non-skipped task fails                                                |
| 2    | `docs/dev-infra/eval-lite-tasks.md` not found                             |
| 3    | No tasks defined (file exists but contains only comments or is empty)     |

A harness invocation that skips container-bound tasks prints the summary `N passed, M failed, K skipped` with K > 0 so the operator sees the partial coverage.

**Rationale:**

- Host-runnable matches test-config and test-shell precedent (DIA-094).
- The curated task set (tasks.md 5.1) includes pytest commands (api-server, analytics-pipeline) that the Makefile `test-python` target runs INSIDE the dev container (Makefile 133-137). Without container-awareness, running `make eval-lite` on a host with the container down would fail those tasks and exit 1, contradicting the DIA-094 host-runnable claim (council 1/5 Critical, validated).
- `docker compose ps --format json` is robust: JSON parsing with `jq` is deterministic, no string-matching fragility, and works whether the daemon is absent or the service is simply stopped.
- NOT wired into CI (no CI exists per inventory.md 12) and NOT into verify-pre-commit.sh (locked decision #4).

### Decision 8: eval-lite.sh on the `bash -n` allowlist (M5)

**Choice:** Add `"$ROOT/scripts/eval-lite.sh"` to the explicit script list in `scripts/__tests__/bats-wrapper.sh` lines 20-42, so `bash -n scripts/eval-lite.sh` runs as a preflight before the bats suite.

**Rationale:** The bats-wrapper.sh comment (lines 9-10) states: "Also runs `bash -n` over every shell artifact we test so syntax errors surface before the test suite (cheap, and bats errors are less readable than bash -n's)." The new `scripts/eval-lite.sh` is a shell artifact under test; omitting it from the allowlist would violate the wrapper's own stated invariant. Task 6.1 AC7 asserts `bash -n scripts/eval-lite.sh` exits 0.

## Seams

### Seam S1: Agent output contract headers (M1, M2)

**Boundary:** The HTML comment block in `.opencode/agents/analyzer.md` and `.opencode/agents/conspecter.md` defines the contract. The generated reports/conspects carry the block after the title.

**Contract:**

```
<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: <finding | recommendation | risk>
evidence-source: <file path or session-id>
confidence: <High | Medium | Low>
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->
```

```
<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: <N>
phase-a-failures: <N>
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->
```

**Test:** `scripts/validate-output-contracts.sh` (NEW) parses both agent .md files, asserts the corresponding HTML comment block exists with all required fields and correct `schema-version: 1.0`. For M1 specifically, asserts `confidence:` is present and its value is one of `High` / `Medium` / `Low`. For M2, asserts `phase-a-source-count` and `phase-a-failures` are non-negative integers. Wired into `make test-config`.

### Seam S2: Reviewer falsification section (M3)

**Boundary:** The `## Falsification` heading in `.opencode/oh-my-opencode-slim/reviewer.md` must appear AFTER `## Spec` and BEFORE `## Summary`.

**Contract:**

```markdown
## Falsification

<!-- Insert exactly 3 falsification claims after review: -->
<!-- [FALSIFICATION-1] file:line -- claim (severity) -->
<!-- [FALSIFICATION-2] file:line -- claim (severity) -->
<!-- [FALSIFICATION-3] file:line -- claim (severity) -->

Emitted on FULL reviews only. Re-review mode (review-re-verify) tracks prior
findings (verified-closed / still-open / partial) and emits NO new Falsification
analysis. 'Exactly 3' is per full review, not per re-review cycle. Initial
Falsification findings enter the existing findings-resolution table via the
generic prefix handling.
```

Severity labels: Blocker, Critical, Major, Minor, Suggestion (Standards-axis rubric).

**Test:** `scripts/validate-reviewer-sections.sh` (NEW) asserts:

1. `## Falsification` heading exists in reviewer.md
2. It appears after `## Spec` and before `## Summary` (line-order check)
3. The section body mentions the `[FALSIFICATION-N]` format and the exactly-3 requirement

Wired into `make test-config`.

### Seam S3: Hypothesis question placement (M4)

**Boundary:** The hypothesis question must appear in both skill files, placed AFTER an explicit `<!-- FIRST-QUESTION -->` HTML anchor comment in each file's Phase 1 section.

**Contract:**

Each skill file gains:

1. An `<!-- FIRST-QUESTION -->` HTML anchor comment placed in the Phase 1 section, after any frontmatter/license HTML comments and before any interview methodology prose.
2. At least one explicit example question ending in `?` in Phase 1 (defense-in-depth so the anchor is never orphaned).
3. The hypothesis question: "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?" -- placed AFTER the `<!-- FIRST-QUESTION -->` anchor (line-order check: question line number > anchor line number).

validate-skills.sh safety: the anchor and the hypothesis question live in the body (post-frontmatter), so the HARD checks (YAML parse, name/description presence, name==dirname) are unaffected. The SOFT activation-phrase check is WARN-only, and both skill files already carry HTML comments as their first body line -- the new anchor comment does not change whether that SOFT check fires.

**Test:** Extension to `.opencode/scripts/validate-skills.sh` asserts:

1. Both files contain the exact hypothesis question text
2. Both files contain the `<!-- FIRST-QUESTION -->` anchor
3. In each file, the hypothesis question's line number > the anchor's line number

Wired into `make test-skills` (already a prereq of `make test-config`).

### Seam S4: eval-lite task manifest (M5)

**Boundary:** `docs/dev-infra/eval-lite-tasks.md` is a tab-separated 6-field file with a curation-metadata comment header. `scripts/eval-lite.sh` reads it.

**Contract:**

```
# eval-lite task manifest
# Curated: 2026-08-11
# Curator: ana012 / openspec-plan
# Review cadence: monthly, aligned with DIA ledger sweep
# Fields: ticket-id<TAB>command<TAB>expected-exit-code<TAB>source-suite<TAB>failure-evidence<TAB>container-bound
# container-bound: 'yes' = requires dev container running (skipped with WARN when container down); 'no' = host-runnable
DIA-001	make test-editor-engine	0	vitest	editor-engine test suite	no
DIA-002	pytest apps/api-server/tests/	0	pytest	api-server test suite	yes
```

Parser: `while IFS=$'\t' read -r ticket cmd expected source evidence container_bound; do ... done`

**Test:** bats unit tests with fixture trees (hermetic, no live test commands needed).

### Seam S5: eval-lite exit-code contract (M5)

**Boundary:** `scripts/eval-lite.sh` exit codes + skip semantics.

**Contract:**

| Exit | Condition                                                                                                                                                         |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | All non-skipped tasks pass (container-bound skips count as pass; summary reports `N passed, M failed, K skipped` with K > 0 when skips occurred)                  |
| 1    | Any non-skipped task fails (FAIL blocks printed with command/expected-exit/observed-exit/source-suite/failure-evidence + summary "N passed, M failed, K skipped") |
| 2    | `docs/dev-infra/eval-lite-tasks.md` not found ("ERROR: docs/dev-infra/eval-lite-tasks.md not found...")                                                           |
| 3    | No tasks defined (file exists but contains only comments or is empty)                                                                                             |

Container-detection: run once at harness start via `docker compose ps --format json dev` (Decision 7). If container is unavailable, every row whose 6th field is `yes` is skipped with WARN "skipping container-bound task <ticket> (dev container not running)" and counted in K.

Malformed lines (wrong field count): skip with WARN "line N has M fields (expected 5 or 6) -- skipping", continue processing. A 5-field row is accepted as if `container-bound: no` for backward compatibility with pre-M5 manifests (WARN emitted noting the missing 6th field).

**Test:** bats unit tests cover all four exit codes + malformed-line skip + empty-file exit 3 + container-skip scenario (fixture with 6th field = `yes`, harness invoked with container-detection mocked to return 'unavailable').

### Seam S6: Makefile target (M5)

**Boundary:** `make eval-lite` invokes `scripts/eval-lite.sh`.

**Contract:**

```makefile
eval-lite:
	bash scripts/eval-lite.sh
```

**Test:** `make eval-lite` exits 0 on the 20-task curated set (with container up; or exits 0 with skips on the host-runnable subset with container down).

### Seam S7: M1-M4 validator wiring into Makefile (M1-M4)

**Boundary:** The three new validator scripts are wired into the existing Makefile target chains so `make test-config` runs them as part of the pre-merge gate.

**Contract:**

- `make test-config` (Makefile 160-166) gains two new invocations:
  - `bash scripts/validate-output-contracts.sh` (M1+M2)
  - `bash scripts/validate-reviewer-sections.sh` (M3)
- `make test-skills` (Makefile 150-151) is extended by the M4 addition to `.opencode/scripts/validate-skills.sh` -- no Makefile change needed; the existing `bash .opencode/scripts/validate-skills.sh` invocation picks up the new M4 check automatically.
- `make test-config` already has `test-skills` as a prereq, so the M4 check is transitively invoked by `make test-config`.

Exit-code semantics: each validator preserves the dev-infra convention (0 = pass, 1 = check-found-issues, 2 = infra-error). A HARD failure in any validator fails `make test-config` per the existing fail-fast semantics of the target chain.

### Seam S8: bash -n allowlist for eval-lite.sh (M5)

**Boundary:** `scripts/__tests__/bats-wrapper.sh` lines 20-42 carry the explicit `bash -n` allowlist for all shell artifacts under test.

**Contract:** add `"$ROOT/scripts/eval-lite.sh"` to the list.

**Test:** task 6.1 AC7 asserts `bash -n scripts/eval-lite.sh` exits 0 (no syntax errors); the preflight loop in bats-wrapper.sh runs this automatically as part of `make test-shell`.

## Risks / Trade-offs

### Risk 1: HTML comment parsing fragility (M1, M2)

**Risk:** The HTML comment block must survive Markdown renderers, editor auto-formatting, and copy-paste without corruption.

**Mitigation:** HTML comments are part of the CommonMark spec and are preserved by all major Markdown renderers (GitHub, GitLab, VS Code preview). The block uses simple ASCII key-value pairs, no special characters.

**Trade-off:** If a future renderer strips HTML comments, the contract becomes invisible. This is acceptable -- the contract is primarily for the agent's own guidance and for validation scripts.

### Risk 2: Falsification section skipped by reviewer (M3)

**Risk:** The reviewer agent might ignore the `## Falsification` section or produce fewer/more than 3 claims.

**Mitigation:** Structural validation (Seam S2 test) asserts the section exists in reviewer.md. Runtime validation (future) could assert the review output contains exactly 3 claims. The practice-protected disposition loop ensures falsification findings are treated with the same gravity as Standards/Spec findings.

**Trade-off:** We cannot force the LLM to produce exactly 3 claims at the config level -- we can only instruct it and validate post-hoc. The "exactly 3" constraint is a prompt-level instruction, not a structural enforcement.

### Risk 3: eval-lite task staleness (M5)

**Risk:** The 20-task curated set becomes stale as tickets are closed, tests are renamed, or suites are reorganized.

**Mitigation:** The task manifest is a plain-text file that can be updated independently of the harness script. Malformed-line handling (WARN + skip) means stale entries can be commented out with `#` without breaking the harness.

**Trade-off:** No automated sync between DIA tickets and the eval-lite manifest. This is a deliberate deferral -- the curated set is manually maintained, like a test fixture.

### Risk 4: Two review chains for one change (both slices)

**Risk:** Slice A (@coder + @ai-auditor) and Slice B (@coder + @reviewer) may produce conflicting feedback or require coordination.

**Mitigation:** The slices are implemented and reviewed independently (disjoint file sets, different review chains); the only cross-slice dependency is task 8.1, which aggregates Slice A's validators 1.2 and 3.2 into the test-config chain, so Slice A must land before 8.1 completes. They can be implemented and reviewed in separate PRs or in the same PR with two review passes. The volta-to-mise precedent demonstrates this pattern works.

**Trade-off:** Slightly more review overhead than a single review chain. This is acceptable -- the different review chains are architecturally correct (AGENTS.md 2.4 vs 2.5).

## Migration Plan

**Deployment:**

1. Merge Slice A (M1-M4) PR. Review chain: @coder + @ai-auditor.
2. Merge Slice B (M5) PR. Review chain: @coder + @reviewer.
3. `make test-config` now validates M1-M4 structural contracts via three validators: `scripts/validate-output-contracts.sh` (M1+M2), `scripts/validate-reviewer-sections.sh` (M3), and the M4 extension to `.opencode/scripts/validate-skills.sh`.
4. `make test-shell` now includes eval-lite bats suite AND runs `bash -n scripts/eval-lite.sh` via the allowlist.
5. `make eval-lite` is available as a host-runnable, container-aware target.

**Forward-only migration (M1/M2):** pre-existing analyzer/conspecter reports without the new header blocks are not retroactively updated. The `schema-version: 1.0` field lets validators distinguish pre-change (no header) from post-change (header present) reports.

**Rollback:**

- `git revert` of each merge commit. No persistent state changed. No CI wiring to undo.

**Post-merge:**

- ana012 updated to reflect M1-M5 implementation status.
- memory-shelf.yaml updated with this change's spec registration.
- Manifest curation review cadence (Decision 5 header) scheduled for monthly DIA ledger sweeps.

## Open Questions

None. All questions were resolved in the Phase 3 interview (5 locked decisions, Q9-Q11 confirmations).
