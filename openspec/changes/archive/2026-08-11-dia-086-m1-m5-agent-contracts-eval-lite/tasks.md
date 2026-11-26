# Tasks: dia-086-m1-m5-agent-contracts-eval-lite

> **Status:** proposed · **Schema:** spec-driven · **skip_specs:** true
> **Design:** `openspec/changes/dia-086-m1-m5-agent-contracts-eval-lite/design.md`
> **Proposal:** `openspec/changes/dia-086-m1-m5-agent-contracts-eval-lite/proposal.md`

## Slice A: Config-tooling (M1 + M2 + M3 + M4)

Review chain: @coder + @ai-auditor (AGENTS.md 2.5).

### 1. Analyzer output contract (M1)

- [ ] 1.1 Add an additive HTML-comment output-contract header block to the analyzer agent definition. The block is placed in the Output Contract section of the analyzer agent file and declares: `schema-version: 1.0`, `agent: analyzer`, `claim-type` (one of: finding | recommendation | risk), `evidence-source` (file path or session-id), `confidence: <High | Medium | Low>` (mandated by ana012 lines 67, 104), `shelf-registration` pointing to `.opencode/memory-shelf.yaml (shelf.analyses)`. The block uses HTML comment syntax (`<!-- ANALYZER-OUTPUT-CONTRACT ... -->`) so it is invisible in rendered Markdown but parseable by validation scripts.
  - **Blocking edges:** none (can start immediately)
  - **Acceptance criteria:**
    - AC1: The analyzer agent definition file contains the output contract section with the exact field set specified in design.md Seam S1 (including `confidence: <High | Medium | Low>`).
    - AC2: A sample analyzer report (e.g., `knowledge/ana999-test-sample/ana999-test-sample-report.md`) with the header block -- including `confidence: High` -- is parseable by `scripts/validate-output-contracts.sh` (task 1.2) with exit 0.

- [ ] 1.2 Create `scripts/validate-output-contracts.sh` (new) -- the M1+M2 output-contract validator. The script asserts:
  - M1: `.opencode/agents/analyzer.md` contains an `<!-- ANALYZER-OUTPUT-CONTRACT ... -->` HTML comment block with all required fields: `schema-version: 1.0`, `agent: analyzer`, `claim-type`, `evidence-source`, `confidence: <High | Medium | Low>`, `shelf-registration`. The `confidence:` value is one of `High` / `Medium` / `Low`.
  - M2: `.opencode/agents/conspecter.md` contains a `<!-- CONSPECTER-OUTPUT-CONTRACT ... -->` HTML comment block with all required fields: `schema-version: 1.0`, `agent: conspecter`, `phase-a-source-count` (non-negative integer), `phase-a-failures` (non-negative integer), `shelf-registration`.
  - Exit-code contract: 0 = both blocks pass, 1 = any HARD check failed, 2 = infra error (agent file missing, parse failure). Output contract: `FAIL:` / `warn:` to stderr, `ok:` to stdout, final summary on both.
  - Wired into `make test-config` (added to the target chain at Makefile 160-166, after `validate-agent-names.sh`).
  - **Blocking edges:** depends on 1.1 (M1 portion) AND 2.1 (M2 portion) -- both agent files must carry their header blocks before the validator can be exercised end-to-end
  - **Acceptance criteria:**
    - AC1: `bash scripts/validate-output-contracts.sh` exits 0 when both agent files carry the specified header blocks with all required fields (including `confidence: High` in M1).
    - AC2: The script exits 1 when the M1 `confidence:` field is missing or its value is not one of `High` / `Medium` / `Low`.
    - AC3: The script exits 1 when the M2 `phase-a-source-count:` field is not a non-negative integer.
    - AC4: The script exits 2 when either agent file is missing.
    - AC5: The script is wired into `make test-config` (invoked from the target chain in Makefile 160-166).
    - AC6: `bash -n scripts/validate-output-contracts.sh` exits 0 (no syntax errors).

### 2. Conspecter output contract (M2)

- [ ] 2.1 Add an additive HTML-comment output-contract header block to the conspecter agent definition. The block is placed in the PHASE B section of the conspecter agent file and declares: `schema-version: 1.0`, `agent: conspecter`, `phase-a-source-count` (integer), `phase-a-failures` (integer), `shelf-registration` pointing to `.opencode/memory-shelf.yaml (shelf.conspects)`. The block uses HTML comment syntax (`<!-- CONSPECTER-OUTPUT-CONTRACT ... -->`).
  - **Blocking edges:** none (can start immediately, parallel with 1.1)
  - **Acceptance criteria:**
    - AC1: The conspecter agent definition file contains the output contract section with the exact field set specified in design.md Seam S1.
    - AC2: A sample conspect (e.g., `knowledge/res999-test-sample-conspect.md`) with the header block is parseable by `scripts/validate-output-contracts.sh` (task 1.2) with exit 0.

### 3. Reviewer falsification axis (M3)

- [ ] 3.1 Insert a `## Falsification` section in the reviewer config file. The section is placed AFTER the existing `## Spec` heading and BEFORE the existing `## Summary` heading (line-order check). The section instructs the reviewer to produce exactly 3 falsification claims in the format `[FALSIFICATION-N] file:line -- claim`, each labelled with a severity from the Standards-axis rubric (Blocker / Critical / Major / Minor / Suggestion). Claims carry claim + severity ONLY -- no fix-direction field (locked decision #2). Falsification findings flow into the existing practice-protected section-4 disposition loop; no new verdicts; no separate escalation path. The section body ALSO states the re-review semantics: Falsification triad emitted on FULL reviews only; re-review mode (review-re-verify) tracks prior findings and emits NO new Falsification analysis; 'exactly 3' is per full review; initial Falsification findings enter the existing findings-resolution table. The review-re-verify SKILL.md file is NOT modified.
  - **Blocking edges:** none (M3 touches `.opencode/oh-my-opencode-slim/reviewer.md`, a file independent of M1/M2; parallel with 1.1 and 2.1)
  - **Acceptance criteria:**
    - AC1: The reviewer config file contains `## Falsification` positioned after `## Spec` and before `## Summary` (line-order assertion passes).
    - AC2: The section body references the `[FALSIFICATION-N]` format and the exactly-3 claims requirement.
    - AC3: The section body states the re-review semantics (Falsification on full reviews only; re-review mode emits no new Falsification analysis; initial findings enter the existing findings-resolution table).
    - AC4: The review-re-verify SKILL.md file is byte-identical to its pre-change state (untouched -- `git diff` shows no changes to this file).
    - AC5: `bash scripts/validate-reviewer-sections.sh` (task 3.2) exits 0.

- [ ] 3.2 Create `scripts/validate-reviewer-sections.sh` (new) -- the M3 section-position validator. The script asserts:
  - `.opencode/oh-my-opencode-slim/reviewer.md` contains a `## Falsification` heading.
  - The `## Falsification` heading appears AFTER a `## Spec` heading and BEFORE a `## Summary` heading (line-order check).
  - The section body contains the `[FALSIFICATION-N]` format reference and the exactly-3 claims requirement.
  - Exit-code contract: 0 = all checks pass, 1 = any HARD check failed, 2 = infra error (reviewer.md missing). Output contract mirrors validate-output-contracts.sh.
  - Wired into `make test-config` (added to the target chain at Makefile 160-166, after validate-output-contracts.sh).
  - **Blocking edges:** depends on 3.1 (the `## Falsification` section must exist before the validator can be exercised end-to-end)
  - **Acceptance criteria:**
    - AC1: `bash scripts/validate-reviewer-sections.sh` exits 0 when reviewer.md carries `## Falsification` positioned correctly with the required section-body content.
    - AC2: The script exits 1 when `## Falsification` is missing, or is positioned before `## Spec`, or after `## Summary`.
    - AC3: The script exits 1 when the section body does not mention `[FALSIFICATION-N]` or does not state the exactly-3 requirement.
    - AC4: The script exits 2 when `.opencode/oh-my-opencode-slim/reviewer.md` is missing.
    - AC5: The script is wired into `make test-config` (invoked from the target chain in Makefile 160-166).
    - AC6: `bash -n scripts/validate-reviewer-sections.sh` exits 0 (no syntax errors).

### 4. Hypothesis question in Socratic interviews (M4)

- [ ] 4.1 Insert the identical hypothesis question into Phase 1 of both the openspec-propose skill file and the domain-grilling skill file. Each file gains: (a) an explicit `<!-- FIRST-QUESTION -->` HTML anchor comment placed in Phase 1 after any frontmatter/license HTML comments and before any interview methodology prose; (b) at least one explicit example question ending in `?` in Phase 1 (defense-in-depth so the anchor is never orphaned); (c) the hypothesis question -- "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?" -- placed AFTER the `<!-- FIRST-QUESTION -->` anchor (line-order check: question line number > anchor line number).
  - **Blocking edges:** none (M4 touches `.opencode/skills/openspec-propose/SKILL.md` and `.opencode/skills/domain-grilling/SKILL.md`, files independent of M1/M2/M3; parallel with 1.1, 2.1, 3.1)
  - **Acceptance criteria:**
    - AC1: Both skill files contain the exact question text: "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?"
    - AC2: Both skill files contain the `<!-- FIRST-QUESTION -->` anchor comment.
    - AC3: In each file, the hypothesis question's line number > the `<!-- FIRST-QUESTION -->` anchor's line number.
    - AC4: Each file contains at least one explicit example question ending in `?` in Phase 1.
    - AC5: The `.opencode/scripts/validate-skills.sh` extension (task 4.2) exits 0 when run against the modified skill files.
    - AC6: validate-skills.sh HARD checks (YAML parse + name/description + name==dirname) still pass for both files -- the `<!-- FIRST-QUESTION -->` anchor lives in the body (post-frontmatter), so HARD checks are unaffected.

- [ ] 4.2 Extend `.opencode/scripts/validate-skills.sh` with an M4 check. After the existing per-skill HARD/SOFT loop, the script asserts for the openspec-propose and domain-grilling skill files specifically:
  - The file contains the `<!-- FIRST-QUESTION -->` anchor.
  - The file contains the exact hypothesis question text.
  - The hypothesis question's line number > the anchor's line number.
  - Exit-code behavior: the M4 check participates in the existing HARD/SOFT accounting (HARD failure on missing anchor OR missing question OR wrong line order; contributes to the existing exit-1 HARD-failure path).
  - Wired into `make test-skills` automatically (no Makefile change -- the existing `bash .opencode/scripts/validate-skills.sh` invocation picks up the new check).
  - **Blocking edges:** depends on 4.1 (both skill files must carry the anchor + question before the extended validator can be exercised end-to-end)
  - **Acceptance criteria:**
    - AC1: `bash .opencode/scripts/validate-skills.sh` exits 0 when both skill files carry the anchor + question in the correct order.
    - AC2: The script exits 1 when the `<!-- FIRST-QUESTION -->` anchor is missing in either file.
    - AC3: The script exits 1 when the hypothesis question is missing in either file.
    - AC4: The script exits 1 when the hypothesis question's line number <= the anchor's line number in either file.
    - AC5: The M4 check does NOT affect HARD/SOFT behavior for other skill files (the check is scoped to openspec-propose and domain-grilling only).
    - AC6: The existing HARD checks (YAML parse + name/description + name==dirname) still pass for both modified skill files.
    - AC7: `bash -n .opencode/scripts/validate-skills.sh` exits 0 (no syntax errors after the extension).

## Slice B: Dev-infra (M5)

Review chain: @coder + @reviewer (AGENTS.md 2.4).

### 5. Eval-lite task manifest and documentation (M5 foundation)

- [ ] 5.1 Create the eval-lite task manifest file at `docs/dev-infra/eval-lite-tasks.md`. The file begins with a curation-metadata `#` comment header (curation date, curator, review cadence) followed by tab-separated 6-field task lines: `<ticket-id>\t<command>\t<expected-exit-code>\t<source-suite>\t<failure-evidence>\t<container-bound>`. The 6th field is `yes` (task requires the dev container) or `no` (host-runnable). Comment lines start with `#`. Populate with an initial curated set of 20 tasks drawn from the 4-source priority: (1) `docs/dev-infra-audit/tickets/` DIA ledger, (2) vitest editor-engine 91 + phonetics-core 25, (3) pytest api-server 2 + analytics-pipeline 4, (4) escalated/crisis session-log patterns. The pytest tasks (3) are marked `container-bound: yes` (the Makefile `test-python` target at 133-137 runs pytest inside the dev container). The curation-metadata header acknowledges a manual review gate: one human or agent sanity-reads the 20-task curated set each review cycle (council alpha-suggestion, accepted as recorded).
  - **Blocking edges:** none (can start immediately, parallel with Slice A)
  - **Acceptance criteria:**
    - AC1: The file contains exactly 20 non-comment task lines.
    - AC2: Every non-comment line has exactly 6 tab-separated fields (validator: `awk -F'\t' 'NF != 6 && !/^#/' docs/dev-infra/eval-lite-tasks.md` produces no output).
    - AC3: The `expected-exit-code` field is a valid integer (0 or positive) for every task line.
    - AC4: The `container-bound` field is `yes` or `no` (case-insensitive) for every task line.
    - AC5: The file begins with a `#` comment block carrying curation metadata (curation date, curator, review cadence) and documenting the field format.
    - AC6: The pytest api-server + analytics-pipeline tasks are marked `container-bound: yes`.

### 6. Eval-lite harness script (M5 core)

- [ ] 6.1 Create `scripts/eval-lite.sh` -- the eval-lite harness. The script reads `docs/dev-infra/eval-lite-tasks.md` using `while IFS=$'\t' read -r ticket cmd expected source evidence container_bound` and executes each command serially. Container-detection runs ONCE at harness start via `docker compose ps --format json dev` (JSON parse with host `jq`); result cached in a shell variable. Exit-code contract: 0 (all non-skipped tasks pass -- container-bound skips count as pass), 1 (any non-skipped task fails -- print FAIL blocks with command/expected-exit/observed-exit/source-suite/failure-evidence + summary "N passed, M failed, K skipped"), 2 (file missing -- "ERROR: docs/dev-infra/eval-lite-tasks.md not found..."), 3 (no tasks defined -- file exists but contains only comments or is empty). Malformed lines (wrong field count): skip with WARN "line N has M fields (expected 5 or 6) -- skipping", continue processing; a 5-field row is accepted as `container-bound: no` with a WARN noting the missing 6th field. When container is unavailable, tasks whose 6th field is `yes` are skipped with WARN "skipping container-bound task <ticket> (dev container not running)" and counted in K. Stdout only -- no `--log` flag, no persistent results log (locked decision #4). Wall-clock target: <=60s.
  - **Blocking edges:** depends on 5.1 (the script reads the task manifest)
  - **Acceptance criteria:**
    - AC1: `scripts/eval-lite.sh` exits 0 when all non-skipped tasks pass (container up: all 20 tasks; container down: only the host-runnable subset, with skips reported in the summary).
    - AC2: `scripts/eval-lite.sh` exits 1 when at least one non-skipped task fails, printing FAIL blocks and the summary line `N passed, M failed, K skipped`.
    - AC3: `scripts/eval-lite.sh` exits 2 when `docs/dev-infra/eval-lite-tasks.md` does not exist.
    - AC4: `scripts/eval-lite.sh` exits 3 when the manifest file exists but contains no task lines (only comments or empty).
    - AC5: Malformed lines (wrong field count) are skipped with WARN output, processing continues for remaining lines.
    - AC6: The script produces stdout output only -- no `--log` flag, no persistent results file.
    - AC7: `bash -n scripts/eval-lite.sh` exits 0 (no syntax errors).
    - AC8: Container-detection mechanism: `docker compose ps --format json dev` + `jq` parse; result cached; container unavailable -> skip `yes` rows with WARN.
    - AC9: A 5-field row (missing 6th field) is accepted as `container-bound: no` with WARN.

### 7. Eval-lite bats test suite (M5 tests)

- [ ] 7.1 Create `scripts/__tests__/eval-lite.bats` -- a hermetic bats unit test suite for `scripts/eval-lite.sh`. Tests use fixture trees (temp directories with synthetic task manifests and stub commands) following the existing pattern from `scripts/__tests__/audit-agent-tool-coverage.bats` and `scripts/__tests__/check-pin-sync.bats`. Cover all exit codes, edge cases, and container-skip behavior.
  - **Blocking edges:** depends on 6.1 (the tests exercise the harness script)
  - **Acceptance criteria:**
    - AC1: bats suite covers all-pass scenario (exit 0) with all tasks host-runnable.
    - AC2: bats suite covers one-fail scenario (exit 1, FAIL block output).
    - AC3: bats suite covers missing-file scenario (exit 2, ERROR message).
    - AC4: bats suite covers malformed-line skip scenario (WARN output, processing continues).
    - AC5: bats suite covers empty-file scenario (exit 3).
    - AC6: bats suite covers container-skip scenario (fixture with 6th field = `yes`, container-detection mocked to return 'unavailable' -- exit 0, WARN skip line printed, K > 0 in summary).
    - AC7: bats suite covers 5-field row scenario (missing 6th field, accepted as `container-bound: no` with WARN).
    - AC8: `make test-shell` passes (bats suite is picked up by the existing bats wrapper).

### 8. Makefile wiring (M5 integration + M1-M4 validator wiring)

- [ ] 8.1 Add a new `eval-lite` target to the `Makefile`. The target invokes `bash scripts/eval-lite.sh`. The target is host-runnable (DIA-094 host-runnable exemption like `test-config` and `test-shell`). NOT wired into `verify-pre-commit.sh` (locked decision #4). NOT wired into CI. NOT replacing existing test gates. ALSO wire the three M1-M4 validators into the existing Makefile target chains:
  - Add `bash scripts/validate-output-contracts.sh` to `make test-config` target chain (Makefile 160-166, after `validate-agent-names.sh`).
  - Add `bash scripts/validate-reviewer-sections.sh` to `make test-config` target chain (after `validate-output-contracts.sh`).
  - Add `"$ROOT/scripts/eval-lite.sh"` to the explicit `bash -n` list in `scripts/__tests__/bats-wrapper.sh` lines 20-42 (after `validate-agent-names.sh`).
  - The M4 validator (task 4.2) extends `.opencode/scripts/validate-skills.sh`, which is ALREADY invoked by `make test-skills`, which is already a prereq of `make test-config` -- no additional Makefile wiring needed for M4.
  - **Blocking edges:** depends on 6.1 (the eval-lite target invokes the harness) AND 1.2 AND 3.2 (the test-config chain invokes the new validators)
  - **Acceptance criteria:**
    - AC1: `make eval-lite` exits 0 on the 20-task curated set with container up (or exits 0 with K > 0 skips with container down).
    - AC2: `make eval-lite` is host-runnable (does not require the dev container for the host-runnable subset).
    - AC3: `scripts/verify-pre-commit.sh` is byte-identical to its pre-change state (eval-lite NOT wired into pre-commit).
    - AC4: Existing test gates (`make test-config`, `make test-shell`, `make test-infra`) are unaffected in their exit-code semantics (still fail when any validator fails).
    - AC5: `make test-config` invokes `bash scripts/validate-output-contracts.sh` (M1+M2 validator).
    - AC6: `make test-config` invokes `bash scripts/validate-reviewer-sections.sh` (M3 validator).
    - AC7: `bash -n scripts/eval-lite.sh` runs as part of `make test-shell` (via bats-wrapper.sh allowlist).

## Dependency graph

```
Slice A (config-tooling) -- all four content tasks parallel (touch different files):
  1.1 (M1) -+
  2.1 (M2) -+--> 1.2 (M1+M2 validator)
  3.1 (M3) -----> 3.2 (M3 validator)
  4.1 (M4) -----> 4.2 (M4 validator, extends validate-skills.sh)

  Rationale: M1/M2/M3/M4 touch four independent files (analyzer.md, conspecter.md,
  reviewer.md, openspec-propose+domain-grilling SKILL.md). The falsification format
  uses severity labels from the Standards rubric, NOT the M1/M2 claim-type
  vocabulary -- the previously-stated rationale for 3.1 -> {1.1, 2.1} and
  4.1 -> 3.1 was false (council finding). Real dependencies run from each content
  task to its validator (validator cannot be exercised end-to-end until the
  content it checks exists).

Slice B (dev-infra):
  5.1 (manifest) --> 6.1 (script) --> 7.1 (bats)
                                  --> 8.1 (Makefile + bats-wrapper)
  1.2 --------------------------------> 8.1 (test-config wiring)
  3.2 --------------------------------> 8.1 (test-config wiring)

Slices A and B are independent (no cross-slice dependencies except via 8.1,
which aggregates Makefile wiring for both slices).
```

## Review-chain summary

| Task | Slice | Mandate                      | Review chain         |
| ---- | ----- | ---------------------------- | -------------------- |
| 1.1  | A     | M1                           | @coder + @ai-auditor |
| 1.2  | A     | M1+M2                        | @coder + @ai-auditor |
| 2.1  | A     | M2                           | @coder + @ai-auditor |
| 3.1  | A     | M3                           | @coder + @ai-auditor |
| 3.2  | A     | M3                           | @coder + @ai-auditor |
| 4.1  | A     | M4                           | @coder + @ai-auditor |
| 4.2  | A     | M4                           | @coder + @ai-auditor |
| 5.1  | B     | M5                           | @coder + @reviewer   |
| 6.1  | B     | M5                           | @coder + @reviewer   |
| 7.1  | B     | M5                           | @coder + @reviewer   |
| 8.1  | B     | M5 (+ M1-M4 Makefile wiring) | @coder + @reviewer   |
