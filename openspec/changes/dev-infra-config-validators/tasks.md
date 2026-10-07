# Tasks: dev-infra-config-validators

> **Proposal:** `openspec/changes/dev-infra-config-validators/proposal.md`
> **Design:** `openspec/changes/dev-infra-config-validators/design.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-045.md` (audit-gaps 1–3) + `docs/dev-infra-audit/tickets/DIA-050.md` (F15 tracking note, created by T1).
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md §2.4 (dev-infra within existing boundaries → `@reviewer`, two-axis: Standards + Spec fidelity). No §10 AI-tooling routing — neither validator modifies opencode config; both only READ it.

## Dependency graph

```
T1 (DIA-050 tracking note — non-code)
 │
 │ (trivial precondition — no code dependency; T2/T3/T4 proceed in parallel)
 │
 ├──▶ T2 (validate-agent-names.sh + bats)
 │
 ├──▶ T3 (validate-handoff.sh + bats)
 │
 └──▶ T4 (Makefile wiring + bash -n loop + wiring regression)
        (depends on T2 + T3 — wires both scripts into test-config)
```

**Critical path:** T2 → T4 OR T3 → T4 (both are symmetric; the coder lane picks the order).
**Parallel track:** T2 and T3 are independent and can be implemented in either order or in parallel. T1 is a non-code task and is the cheapest to do first (it clears the tracking-note bookkeeping before any code lands).
**Rationale for ordering:**

- **T1 is first** because it is trivial (one markdown file, no tests), creates the DIA-050 reference the rest of the change cites, and does not block T2/T3/T4 — only the other way around (T4 references DIA-050 in a comment, if at all).
- **T2 and T3 are independent** because they touch disjoint files. T2 walks 4 agent-name sources; T3 walks 1 HANDOFF file. No shared state, no shared interface, no sequential dependency.
- **T4 depends on T2 and T3** because it wires both scripts into `make test-config` and adds both to the `bash -n` syntax-check loop. Neither wire-up is meaningful until the script itself exists.
- **No blocking edges between T2/T3/T4 that prevent independent verification** (briefing constraint). Each task can be verified in isolation: T2 runs standalone via `bash scripts/validate-agent-names.sh`; T3 runs standalone via `bash scripts/validate-handoff.sh <handoff-path>`; T4 runs via `make test-config` AFTER T2+T3 land (but T4 itself is a single coherent slice that can be implemented and verified in one context window once T2+T3 exist).

---

## T1 — DIA-050 tracking note (DIA-045 F15)

**Blockers:** none
**Vertical slice:** create `docs/dev-infra-audit/tickets/DIA-050.md` as a cross-ref bookkeeping placeholder for the `.mise.toml` ↔ `Dockerfile.dev` pin-sync gap (DIA-045 F15). Non-code deliverable. No Makefile target, no tests.

**Non-code deliverable — no make target.** This task produces a single markdown file. The `make test-config` / `make test-shell` gates do not exercise it. Verification is visual review + grep.

### What changes

1. **`docs/dev-infra-audit/tickets/DIA-050.md`** (new file). Use the existing ticket template at `docs/dev-infra-audit/tickets/_TEMPLATE.md` for shape. Fields:
   - `id: DIA-050`
   - `title: ".mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15)"`
   - `area: dev-infra`
   - `severity: Low`
   - `status: OPEN`
   - `blocked_by: []`
   - `source: dia-045-followup`
   - `date: 2026-08-05`
   - `created: 2026-08-05`
   - `updated: 2026-08-05`
   - Description body: short paragraph pointing at DIA-045 F15 (quoted verbatim from DIA-045's Major findings list: "`.mise.toml` ↔ `Dockerfile.dev` pin sync gap untracked; D5 — file a tracking note."). Note that `openspec/changes/volta-to-mise/` design.md §2.1's `.mise.toml` header comment documents the current one-time manual sync — the gap is that no automated validator enforces parity. Remediation is out of scope for the `dev-infra-config-validators` change.
   - Verification / Fix / Re-verify sections left as stubs (per the template's pattern for OPEN tickets).

### Acceptance criteria (user perspective)

- The file exists at `docs/dev-infra-audit/tickets/DIA-050.md`.
- The file parses as valid markdown (no broken frontmatter).
- The frontmatter includes all the required fields per `_TEMPLATE.md`.
- The body references DIA-045 F15 and the volta-to-mise manual-sync contract explicitly.
- The status is `OPEN` (the ticket is tracked, not resolved).

### Verification procedure

1. `cat docs/dev-infra-audit/tickets/DIA-050.md` — visual check: frontmatter well-formed, body references DIA-045 F15 and volta-to-mise.
2. `grep -c '^id: DIA-050' docs/dev-infra-audit/tickets/DIA-050.md` — returns `1`.
3. `grep -c 'DIA-045' docs/dev-infra-audit/tickets/DIA-050.md` — returns ≥1 (the F15 reference).

### Testing

No automated test. This is a tracking-ticket creation task, not code.

---

## T2 — `scripts/validate-agent-names.sh` + `scripts/__tests__/validate-agent-names.bats`

**Blockers:** T1 (trivial — T1 just needs to land first for bookkeeping; T2 does not functionally depend on T1's output).
**Vertical slice:** the agent-name cross-reference validator + its 10-case bats fixture matrix. After T2, running `bash scripts/validate-agent-names.sh` from the repo root produces the expected exit code on the real project config (exit 0 with `21 passed, 0 failed, 0 warnings`; DIA-045 already cleaned up the drift instances, and the owner-ruling-row-420 declared-⊆-resolved contract makes the 6 exempt names PASS without S4 files + reads the council KEY only, not its model-seat members).

### What changes

1. **`scripts/validate-agent-names.sh`** (new file, executable, `set -euo pipefail`). Behavior per design.md §1:
   - Reads `AGENTS.md` (repo root), `.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/agents/*.md` filename stems.
   - Extracts the kebab-case internal-name set from each source.
   - Performs two containment checks per the declared-⊆-resolved contract: (i) each §9 name resolves in S2∪S3∪S4∪exempt, (ii) each S2∪S3 name appears in §9.
   - Disabled agents in `disabled_agents` list are included in validation (Q2 ruling).
   - Empty `agents/` directory → exit 0 with `0/0/0` line (Q5 ruling).
   - JSONC parse error → exit 1 (HARD, Q2 ruling).
   - Missing source file (other than `agents/`) → exit 2 (INFRA).
   - Stream contract per design.md §4: `FAIL:` to stderr, `ok:` to stdout, final `N passed, M failed, K warnings` to stdout. Collect-all, never fail-fast.
   - `AGENTS_ROOT` env override for bats meta-tests (points at fixture tree).

2. **Extraction + contract (owner ruling row 420, supersedes strict 4-way lockstep + row-415 amendment):** the slim-jsonc extraction and the comparison semantics are as follows:
   - **S3 extraction:** extract (a) top-level `agents` keys, (b) `routing` / preset values, (c) `disabled_agents` list members, AND (d) the **presence of the top-level `council` KEY itself** (single name `council` → S3-valid). The `council` block's **MEMBERS are NOT extracted** (they are model seat names — `deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus` — not agent names; extracting them would inject 5 non-agents into S3 and make the real-config run report 25 FAILs).
   - **Declared-⊆-resolved containment contract (replaces symmetric-difference lockstep):** (i) every §9 name (S1) must resolve in S2∪S3∪S4∪exempt; (ii) every S2∪S3 name must appear in §9. Not set-equality. The 6 names `explore`, `general`, `oracle`, `fixer`, `explorer`, `librarian` resolve via the exempt branch of (i); S4 absence for them is correct.
   - **Drift detection still works:** a rename in one source that is not mirrored in any of the others still fails — it breaks containment (the renamed name won't resolve, or the orphaned name in S2∪S3 won't appear in §9).

3. **`scripts/__tests__/validate-agent-names.bats`** (new file). 10-case fixture matrix per proposal §Testing Decisions:

   > **Note:** the acceptance criteria add 2 invariant-level tests (declared-name-not-in-§9, §9-name-unresolved) beyond the original 8-case matrix; total agent-names cases = 10.
   1. Valid: all §9 names resolve + all S2∪S3 names canonical (2 agents, one disabled) → exit 0.
   2. Agent-name mismatch (stem in `agents/` differs from `opencode.jsonc` key) → exit 1.
   3. Disabled-agent mismatch (non-exempt agent name differs across sources) → exit 1.
   4. JSONC parse error in `opencode.jsonc` → exit 1 (HARD, NOT exit 2).
   5. Empty `agents/` directory → exit 0 with `0/0/0` line.
   6. Missing `AGENTS.md` → exit 2 (INFRA).
   7. Missing required routing reference in oh-my-opencode-slim.jsonc → exit 1.
   8. S3 council-KEY-only read + exempt-name-without-S4-file → exit 0 (PASS). Exercising the owner-ruling-row-420 declared-⊆-resolved contract: a fixture slim.jsonc with a top-level `council` block containing model-seat names (`deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus`) — the validator treats only the `council` KEY itself as S3-valid (single name `council`); the model-seat members are NOT extracted as agent names. An exempt name (`explore`/`general`/`oracle`/`fixer`/`explorer`/`librarian`) present in S1/S3 but without a matching `.opencode/agents/<name>.md` file is accepted — S4 absence is correct for the exempt set. Negative sub-assertion: the fixture's model-seat names do NOT appear in the validator's output or counts.
      Each test uses `AGENTS_ROOT` (and related env overrides) to point the validator at a temp fixture tree under `$BATS_TEST_TMPDIR`. Uses `assert_status`, `assert_output_contains` from `test-helper.bash`.

4. **(Conditional) `scripts/__tests__/test-helper.bash` extensions.** If the existing assertion vocabulary is insufficient for the fixture predicates, add helpers. Decision for the coder lane — the existing `assert_file_contains` (substring-only via `grep -qF`) is likely sufficient for the strict-literal-match predicates.

### Acceptance criteria (user perspective)

- `bash scripts/validate-agent-names.sh` from repo root exits 0 with `21 passed, 0 failed, 0 warnings` on the real project config (all 21 AGENTS.md §9 names resolve: 15 active agents via S2∪S3∪S4 paths + 6 exempt via the exempt branch of invariant 1; all S2∪S3 names appear in §9).
- `bash scripts/validate-agent-names.sh` from repo root prints `ok: <name>` lines to stdout, one per consistent agent.
- `bash scripts/validate-agent-names.sh` from repo root prints final summary line `21 passed, 0 failed, 0 warnings` (post-DIA-045 + owner-ruling-row-420 declared-⊆-resolved contract, no drift expected).
- `make test-config` exits 0 on the real project config (agent-names gate green alongside `validate-opencode-config.sh`).
- All 10 bats fixture tests pass under `make test-shell`.
- The script passes `bash -n` syntax check (verified by `bats-wrapper.sh`).
- Empty `agents/` dir fixture → exit 0, `0/0/0` line.
- JSONC parse error fixture → exit 1 (HARD, not INFRA).
- **Council-KEY-only fixture** (case 8): top-level `council` block with model-seat members (`deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus`) → only the name `council` is S3-valid; model-seat names are NOT extracted as agents (negative sub-assertion in the fixture).
- **Declared-name-not-in-§9 fixture** → exit 1 (FAIL — S2∪S3 name absent from §9 violates invariant 2 of the declared-⊆-resolved contract).
- **§9-name-unresolved fixture** (name in §9 but absent from S2, S3, S4, and not in the exempt set) → exit 1 (FAIL — violates invariant 1 of the declared-⊆-resolved contract).
- S4-exempt name present in S1/S3 but without S4 file → exit 0 (PASS — exempt branch of invariant 1).

### Verification procedure

1. `bash scripts/validate-agent-names.sh` — exit 0 expected, `21 passed, 0 failed, 0 warnings`.
2. `make test-shell` — all bats tests pass (pre-existing 93/93 baseline + 10 new cases).
3. `bash -n scripts/validate-agent-names.sh` — exit 0.

### Testing

- RED-GREEN: write the 10 bats tests first (they fail because the validator script does not yet exist), then implement the validator until they pass.
- The 10 fixture tests cover all exit-code paths (0 / 1 / 2), the collect-all discipline, and the owner-ruling-row-420 declared-⊆-resolved contract (council-KEY-only read + S4-exemption + declared-name-not-in-§9 FAIL + §9-name-unresolved FAIL).
- bats uses env override (`AGENTS_ROOT` etc.) to isolate fixture trees — real project config never mutated.

---

## T3 — `scripts/validate-handoff.sh` + `scripts/__tests__/validate-handoff.bats`

**Blockers:** T1 (trivial — bookkeeping only; T3 does not functionally depend on T1's output).
**Vertical slice:** the HANDOFF.md prognosis-schema validator + its 6-case bats fixture matrix. After T3, running `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` from the repo root produces exit 0 (the template has all 5 required subsections).

### What changes

1. **`scripts/validate-handoff.sh`** (new file, executable, `set -euo pipefail`). Behavior per design.md §2:
   - Takes one positional argument: HANDOFF file path (exact-name only — no glob, Q2 ruling).
   - Reads `openspec/templates/HANDOFF.md` as the reference template (hardcoded repo-relative path via `${BASH_SOURCE[0]}` dirname traversal, same pattern as `validate-skills.sh`).
   - Asserts `## Prognosis for next cycle` heading is present.
   - Asserts all 5 required `###` subsections are present (strict literal match: `session_summary`, `fixes_applied`, `open_tickets`, `verification_request`, `resume_instructions`).
   - Extra `###` subsections under `## Prognosis for next cycle` → SOFT warn (do not flip exit code, Q5 ruling).
   - Missing input path argument or non-existent path → exit 2 (INFRA).
   - Missing reference template → exit 2 (INFRA).
   - Missing required heading or subsection → exit 1 (HARD).
   - Stream contract per design.md §4.

2. **`scripts/__tests__/validate-handoff.bats`** (new file). 6-case fixture matrix per proposal §Testing Decisions:
   1. Valid HANDOFF with all 5 required subsections → exit 0.
   2. Missing one required `###` subsection → exit 1.
   3. Missing `## Prognosis for next cycle` heading → exit 1.
   4. Extra `###` subsection beyond the required 5 → exit 0 with `warn:` line to stderr.
   5. Missing input file (no argument) → exit 2.
   6. Non-existent input path → exit 2.
      Each test writes a fixture HANDOFF file under `$BATS_TEST_TMPDIR` and passes it as the positional argument. Uses `assert_status`, `assert_output_contains` from `test-helper.bash`.

### Acceptance criteria (user perspective)

- `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` from repo root exits 0.
- `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` from repo root prints 5 `ok: <subsection_name>` lines and `5 passed, 0 failed, 0 warnings`.
- A HANDOFF fixture missing one subsection → exit 1 with `FAIL:` naming the missing subsection.
- A HANDOFF fixture with an extra subsection → exit 0 with `warn:` naming the extra subsection (SOFT).
- All 6 bats fixture tests pass under `make test-shell`.
- The script passes `bash -n` syntax check.

### Verification procedure

1. `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` — exit 0 expected.
2. `make test-shell` — all bats tests pass (pre-existing 93/93 baseline + 6 new cases).
3. `bash -n scripts/validate-handoff.sh` — exit 0.

### Testing

- RED-GREEN: write the 6 bats tests first, then implement the validator until they pass.
- The 6 fixture tests cover all exit-code paths (0 / 1 / 2) and the SOFT warn discipline.

---

## T4 — Makefile wiring + `bash -n` loop + wiring regression

**Blockers:** T2 + T3 (both scripts must exist before they can be wired in).
**Vertical slice:** wire both validators into `make test-config`, add both to the `bats-wrapper.sh` syntax-check loop, add a wiring regression bats test. After T4, `make test-config` invokes both validators alongside `validate-opencode-config.sh`.

### What changes

1. **`Makefile`** (modified, lines 131–132). Extend the existing `test-config` target to invoke both new validators. The spec pins the invariant — `make test-config` must invoke `validate-agent-names.sh` AND `validate-handoff.sh` AND the pre-existing `validate-opencode-config.sh`. The exact shape (prereq vs recipe-line) is a coder-lane detail per design.md §5. The coder's handoff must document which shape was chosen and why.
   - **Invariants (locked regardless of shape):**
     - Both scripts are invoked with no arguments from the Makefile.
     - The pre-existing `validate-opencode-config.sh` invocation is preserved.
     - The pre-existing `test-interview` and `test-skills` prereqs are preserved.
     - `make test-config` from repo root exits 0 on the real project config (since both validators should pass on the current post-DIA-045 state).

2. **`scripts/__tests__/bats-wrapper.sh`** (modified). Add `scripts/validate-agent-names.sh` and `scripts/validate-handoff.sh` to the `bash -n` syntax-check loop (lines 30–40). Same shape as the existing entries for `validate-skills.sh`.

3. **`scripts/__tests__/test-config-wiring.bats`** (new file) OR append to an existing wiring-aware test file. Wiring regression test:
   - Static grep over `Makefile` asserting the `test-config` target body references `validate-agent-names.sh` AND `validate-handoff.sh`.
   - One `@test` block with 2 assertions (one per validator).
   - Decision: new file preferred (clearer seam, matches the "dedicated wiring test" pattern used elsewhere in the codebase).

### Acceptance criteria (user perspective)

- `make test-config` from repo root exits 0.
- `make test-config` invokes `validate-agent-names.sh` (verified by wiring regression test).
- `make test-config` invokes `validate-handoff.sh` (verified by wiring regression test).
- `make test-config` still invokes `validate-opencode-config.sh` (pre-existing baseline preserved).
- `bash -n scripts/validate-agent-names.sh` runs in `make test-shell` (via `bats-wrapper.sh`).
- `bash -n scripts/validate-handoff.sh` runs in `make test-shell` (via `bats-wrapper.sh`).
- The wiring regression bats test passes.
- Each new validator is also make-callable: `bash scripts/validate-agent-names.sh` and `bash scripts/validate-handoff.sh <handoff-path>` from repo root produce the same exit code as via Make.

### Verification procedure

1. `make test-config` — exit 0 expected. Output should show `validate-agent-names.sh` + `validate-handoff.sh` being invoked alongside `validate-opencode-config.sh`.
2. `make test-shell` — all bats tests pass (pre-existing 93/93 + 10 new for T2 + 6 new for T3 + 1 new wiring regression = 110/110 total).
3. `grep -c 'validate-agent-names.sh' Makefile` — returns ≥1.
4. `grep -c 'validate-handoff.sh' Makefile` — returns ≥1.
5. `bash scripts/validate-agent-names.sh` — exit 0 (standalone call).
6. `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` — exit 0 (standalone call).

### Testing

- The wiring regression test is a pure structural assertion (static grep over the Makefile, no execution) — same shape as the arch-failfast test in `opencode-docker.bats`.
- No new Docker/build integration is needed. The wiring test is hermetic.

---

## Summary of file changes

| File                                                          | Action | Task                       |
| ------------------------------------------------------------- | ------ | -------------------------- |
| `docs/dev-infra-audit/tickets/DIA-050.md`                     | create | T1                         |
| `scripts/validate-agent-names.sh`                             | create | T2                         |
| `scripts/__tests__/validate-agent-names.bats`                 | create | T2                         |
| `scripts/validate-handoff.sh`                                 | create | T3                         |
| `scripts/__tests__/validate-handoff.bats`                     | create | T3                         |
| `scripts/__tests__/test-helper.bash`                          | modify | T2/T3 (conditional)        |
| `scripts/__tests__/bats-wrapper.sh`                           | modify | T4                         |
| `Makefile`                                                    | modify | T4                         |
| `scripts/__tests__/test-config-wiring.bats`                   | create | T4                         |
| `openspec/changes/dev-infra-config-validators/.openspec.yaml` | create | T0 (pre-existing scaffold) |
| `openspec/changes/dev-infra-config-validators/proposal.md`    | create | T0 (pre-existing scaffold) |
| `openspec/changes/dev-infra-config-validators/design.md`      | create | T0 (pre-existing scaffold) |
| `openspec/changes/dev-infra-config-validators/tasks.md`       | create | T0 (pre-existing scaffold) |

## Implementation order (suggested)

1. **T1** (tracking note) — trivial, clears the bookkeeping. ~5 min.
2. **T2** (validate-agent-names + bats) — the larger of the two validators. Write the 10 bats tests RED first, then implement the validator GREEN. ~45 min.
3. **T3** (validate-handoff + bats) — similar shape to T2, smaller fixture matrix. ~30 min.
4. **T4** (Makefile wiring + wiring regression) — the integration slice. ~15 min.
5. **Final PR verification:** run `make test-config` + `make test-shell` end-to-end; expect 110/110 bats tests pass (93 pre-existing + 10 T2 + 6 T3 + 1 T4 wiring regression).

## Out of scope for these tasks

- Remediation of DIA-045's still-open findings (F19/F20/F22) — tracked separately.
- Remediation of DIA-050's underlying `.mise.toml` pin-sync gap — tracked as DIA-050.
- Global config (`~/.config/opencode/opencode.jsonc`) validation — OUT of scope (Q2 ruling).
- Glob-based HANDOFF discovery — OUT of scope (Q2 ruling).
- New `test-dev-infra` Makefile target — OUT of scope (Q4 ruling).
- `.sdd/` module doc authoring — OUT of scope (precedent allows).
- Any change beyond the 4 tasks listed.

## Verification gate summary

| Gate                                                                          | When           | Required                                                                                                                                                |
| ----------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make test-shell`                                                             | After T2/T3/T4 | 110/110 bats tests pass (93 pre-existing + 10 T2 + 6 T3 + 1 T4 wiring regression).                                                                      |
| `make test-config`                                                            | After T4       | Pre-existing 20/0/33 baseline + both new validators exit 0 on the real project config; agent-names validator reports `21 passed, 0 failed, 0 warnings`. |
| `bash scripts/validate-agent-names.sh` (standalone)                           | After T2       | Exit 0 with `21 passed, 0 failed, 0 warnings` on real project config.                                                                                   |
| `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` (standalone) | After T3       | Exit 0 on real template.                                                                                                                                |
| Manual: DIA-050 ticket                                                        | After T1       | Ticket exists, uses `_TEMPLATE.md` shape, points at DIA-045 F15.                                                                                        |
| Wiring regression                                                             | After T4       | bats test asserts `Makefile` `test-config` body references both validators.                                                                             |

## Coder handoff contract

Per AGENTS.md §2.3 and §2.3.1, the coder's handoff to `@reviewer` must include verification evidence (exit codes + summary lines) for each task. For this change specifically:

- **T1 handoff:** `cat docs/dev-infra-audit/tickets/DIA-050.md` (file exists, well-formed).
- **T2 handoff:** `make test-shell` exit code + summary line (e.g., `101 tests, 0 failures`); `bash scripts/validate-agent-names.sh` exit code + summary output (expected `21 passed, 0 failed, 0 warnings`).
- **T3 handoff:** `make test-shell` exit code + summary line; `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` exit code + summary output.
- **T4 handoff:** `make test-config` exit code + output (should show both validators being invoked, exit 0); `grep -c 'validate-agent-names.sh\|validate-handoff.sh' Makefile` output (both return ≥1); `make test-shell` exit code + summary line showing 110/110.
