# Design: dev-infra-config-validators

> **Proposal:** `openspec/changes/dev-infra-config-validators/proposal.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-045.md` (audit-gaps 1–3) + `docs/dev-infra-audit/tickets/DIA-050.md` (F15 tracking note created by T1).
> **Scope:** implementation design only — no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; routing is AGENTS.md §2.4 (dev-infra → `@reviewer`).

## Approach

This change stays entirely within existing module boundaries. It does not introduce any new module, does not alter any data flow described in `architecture.md` (root), and does not affect the DIA redispatch cycle. The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` + `README.md` — no module doc governs `scripts/`, `.opencode/agents/`, or the agent-name sources. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill. The precedent is `openspec/changes/dev-infra-copilot-fixes/design.md` (same conclusion, same routing, same absence of `.sdd/`).

**Existing patterns followed:**

- **3-tier exit contract + HARD/SOFT partition** — copied verbatim from `.opencode/scripts/validate-skills.sh`.
- **Stderr/stdout stream protocol** — `FAIL:` to stderr, `warn:` to stderr, `ok:` to stdout, final summary `N passed, N failed, N warnings` to stdout. Same as `validate-skills.sh`.
- **Collect-all, never fail-fast** — same as `validate-skills.sh`. A HARD finding does not abort the walk; the script accumulates all findings and reports them in one pass.
- **Env override for bats meta-tests** — `validate-skills.bats` uses `SKILLS_ROOT` to point the validator at a fixture tree; this change's validators use `AGENTS_ROOT` (for `validate-agent-names.sh`) and the first positional argument (for `validate-handoff.sh`).
- **`set -euo pipefail`** — same fail-fast default as `validate-skills.sh` and all other project scripts.

## Files changed

| File                                                                    | Action | Task  | Description                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------------------------------------------------------- | ------ | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/dev-infra-audit/tickets/DIA-050.md`                               | create | T1    | Tracking note for DIA-045 F15 (`.mise.toml` ↔ `Dockerfile.dev` pin-sync gap). Non-code deliverable; uses the existing ticket template (`docs/dev-infra-audit/tickets/_TEMPLATE.md`). No Makefile target, no tests.                                                                                                                                                                      |
| `scripts/validate-agent-names.sh`                                       | create | T2    | Cross-reference validator for the 4 agent-name sources. Exit-code contract + stream contract per §Exit-code table. Collect-all, never fail-fast. `set -euo pipefail`.                                                                                                                                                                                                                   |
| `scripts/__tests__/validate-agent-names.bats`                           | create | T2    | bats unit tests for `validate-agent-names.sh`. 10-case fixture matrix per proposal §Testing Decisions. Uses `AGENTS_ROOT` env override to point the validator at a fixture tree.                                                                                                                                                                                                        |
| `scripts/validate-handoff.sh`                                           | create | T3    | HANDOFF.md prognosis-schema validator. Takes a HANDOFF file path as first positional argument (exact-name only — no glob, per Q2 ruling). Asserts `## Prognosis for next cycle` heading + 5 required `###` subsections (strict literal match). Extra subsections are SOFT warn. Exit-code contract per §Exit-code table. `set -euo pipefail`.                                           |
| `scripts/__tests__/validate-handoff.bats`                               | create | T3    | bats unit tests for `validate-handoff.sh`. 6-case fixture matrix per proposal §Testing Decisions.                                                                                                                                                                                                                                                                                       |
| `scripts/__tests__/test-helper.bash`                                    | modify | T2/T3 | Adds `assert_file_contains_regex` (or equivalent) if not already present (it is — the existing `assert_file_contains` is substring-only; add regex helper if the validators need regex assertions — decision for the coder lane based on whether grep -F vs grep -E is needed for the fixtures). May also add a `setup_fixture_tree` helper for the 4-source agent-name fixture layout. |
| `scripts/__tests__/bats-wrapper.sh`                                     | modify | T4    | Adds `scripts/validate-agent-names.sh` and `scripts/validate-handoff.sh` to the `bash -n` syntax-check loop (lines 30–40). Same shape as the existing entries for `validate-skills.sh`.                                                                                                                                                                                                 |
| `Makefile` (`test-config` target, lines 131–132)                        | modify | T4    | Extends the existing `test-config` recipe to invoke both new validators alongside `validate-opencode-config.sh`. No new top-level target (per Q4 ruling). Exact shape (prereq vs recipe-line) is a coder-lane detail — the spec pins "both wired in" only.                                                                                                                              |
| `scripts/__tests__/test-config-wiring.bats` (new) OR append to existing | create | T4    | Wiring regression test asserting `Makefile` `test-config` target body references both `validate-agent-names.sh` and `validate-handoff.sh`. Static grep over the Makefile. One `@test` block with 2 assertions (one per validator). Appended to an existing file (preferred) or created as a new file if no existing file is a natural fit.                                              |

## Implementation details

### §1 — `scripts/validate-agent-names.sh`

**Inputs (4 sources, all project-scoped, no global config per Q2 ruling):**

1. `AGENTS.md` — root file. The validator greps for `## Agent Naming Convention` (the §9 heading) and walks the markdown table below it. Extracts the "Internal name" column (second column, per the existing table layout). Empty / missing heading → exit 2 (INFRA).
2. `.opencode/opencode.jsonc` — JSONC file. Parse with inline `python3` after stripping comments (same strategy as `validate-skills.sh`). Extract top-level keys of the `agents` block. Parse error → exit 1 (HARD, per Q2 ruling — JSONC parse failure is NOT an INFRA error).
3. `.opencode/oh-my-opencode-slim.jsonc` — JSONC file. Parse with same inline `python3`. Extract: (a) top-level keys of the `agents` block, (b) values referenced by the `routing` / preset assignments, (c) names in the `disabled_agents` list, (d) the **presence of the top-level `council` KEY itself** (the single name `council` is added to S3 — per owner ruling row 420). The `council` block's **MEMBERS are NOT extracted** (they are model seat names — `deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus` — not agent names). Parse error → exit 1 (HARD).
4. `.opencode/agents/*.md` — filename stems (without the `.md` suffix). Missing directory → exit 0 with `0/0/0` line per Q5 ruling (empty agents dir = OK).

**Declared-⊆-resolved semantics (owner ruling row 420, supersedes the strict 4-way-lockstep reading of Q2-4 and the row-415 amendment):** the validator enforces a **containment** contract, not set-equality across the 4 sources. Two invariants must hold:

1. **Every §9 name resolves.** Each canonical internal name in `AGENTS.md` §9 (S1) must appear in at least one of: `opencode.jsonc` `agents` block keys (S2), oh-my-opencode-slim.jsonc `agents` keys / `routing` / preset assignments / `disabled_agents` list / top-level `council` KEY presence (S3), or `.opencode/agents/*.md` stems (S4) — OR be in the exempt set (`explore`, `general`, `oracle`, `fixer`, `explorer`, `librarian`), whose S4 absence is correct.
2. **Every config-declared name is canonical.** Each name read from S2 or S3 must also appear in S1.

This is a presence/containment contract: each S1 name resolves somewhere (S2 ∪ S3 ∪ S4 ∪ exempt); each declared name (S2 ∪ S3) is declared in the canonical §9 list. Set-equality is NOT required — the sources legitimately have different subsets (e.g., a name can exist in S1+S2 but not S4 for a config-defined agent; this is PASS, not drift).

**Council read (row 420 correction):** the top-level `council` BLOCK in `oh-my-opencode-slim.jsonc` contains **MODEL SEAT names** (`deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus`), NOT agent names. Reading its members would inject 5 non-agents into S3. The correct read is: the **presence of the `council` KEY itself** makes the name `council` S3-valid. Council block members are NOT extracted as agent names.

**S4-exemption (retained from row 415, now part of the full contract):** the 6 names `explore`, `general`, `oracle`, `fixer`, `explorer`, `librarian` are exempt from the S4 `.opencode/agents/*.md` file requirement. Rationale: these names are OpenCode built-ins (`explore`, `general`, both disabled in `opencode.jsonc`) or OMO native aliases (`oracle`, `fixer`, `explorer`, `librarian`, all in slim `disabled_agents`). `.opencode/agents/` (PLURAL) is OpenCode's auto-loaded agent-definition directory — creating `.md` files there for these names would register real agents at next OpenCode startup, producing the opposite of the intended disabled/aliased state. For the exempt set, S4 absence is correct and is not counted as drift; they resolve via the exempt branch of invariant 1.

**Canonical key:** the kebab-case internal name (Q2 ruling). Every source is normalized to the same kebab-case form before equality comparison.

**Cross-reference logic:** the validator performs two containment checks (not a 4-way symmetric difference):

1. **Invariant 1 — every S1 name resolves.** For each name in S1, the validator asserts that the name appears in S2 OR S3 OR S4, OR is a member of the exempt set. A name in S1 that does not resolve in any of these is a HARD failure (`FAIL: <name> — declared in §9 but unresolved in S2∪S3∪S4∪exempt`).
2. **Invariant 2 — every declared name is canonical.** For each name in S2 or S3, the validator asserts that the name appears in S1. A name declared in S2∪S3 but missing from S1 is a HARD failure (`FAIL: <name> — declared in <source> but absent from §9`).

Each name that passes both invariants → `ok: <name>` to stdout. Each failure → `FAIL:` line to stderr naming the violated invariant and the offending sources.

**Stream contract:**

- Each agent name that resolves (passes both invariants) → `ok: <name>` to stdout.
- Each containment violation → `FAIL: <name> — declared in §9 but unresolved in S2∪S3∪S4∪exempt` OR `FAIL: <name> — declared in <source> but absent from §9` to stderr.
- Final line to stdout: `N passed, M failed, K warnings` (warnings will be 0 for this validator unless extended later).

**Exit code:**

- 0 if `M == 0` (no HARD failures).
- 1 if `M > 0` (any HARD failure — containment violation per either invariant, JSONC parse error, missing required routing reference).
- 2 on INFRA errors (missing `AGENTS.md`, missing `.opencode/opencode.jsonc`, missing `.opencode/oh-my-opencode-slim.jsonc`, missing `python3`).

### §2 — `scripts/validate-handoff.sh`

**Input:** a single HANDOFF file path as the first positional argument (exact-name only — no glob, per Q2 ruling). Missing argument → validate the reference template (default behavior for make-callable invocation); if the template is also unavailable → exit 2 (INFRA).

**Reference template:** the validator reads `openspec/templates/HANDOFF.md` (hardcoded repo-relative path) to anchor the schema — this is the canonical 5-subsection contract. Missing template → exit 2 (INFRA).

**Required schema (Q2 ruling — strict literal match):**

- One `## Prognosis for next cycle` heading (level 2).
- Five `###` subsections directly under it:
  1. `### session_summary`
  2. `### fixes_applied`
  3. `### open_tickets`
  4. `### verification_request`
  5. `### resume_instructions`

The match is **strict literal** (case-sensitive, exact underscore). No regex relaxation, no alias matching. This matches the `openspec/templates/HANDOFF.md` file's actual headings exactly.

**Extra headings:** any `###` heading under `## Prognosis for next cycle` that is NOT one of the 5 required → SOFT warn to stderr (`warn: extra subsection '<name>' in Prognosis`). Does NOT flip the exit code; joins the soft-warnings bucket (Q5 ruling).

**Stream contract:**

- Each required subsection found → `ok: <subsection_name>` to stdout.
- Each required subsection missing → `FAIL: missing required subsection '<subsection_name>' under '## Prognosis for next cycle'` to stderr.
- Missing `## Prognosis for next cycle` heading itself → `FAIL: missing required heading '## Prognosis for next cycle'` to stderr (single line, counts as 1 HARD failure).
- Each extra subsection → `warn: extra subsection '<name>' under '## Prognosis for next cycle'` to stderr (SOFT).
- Final line to stdout: `N passed, M failed, K warnings`.

**Exit code:**

- 0 if `M == 0` (no HARD failures; SOFT warnings may print).
- 1 if `M > 0` (any required subsection or heading is missing).
- 2 on INFRA errors (missing input file, missing reference template, missing `## Prognosis` heading when it should be present — actually, missing heading is HARD not INFRA, so exit 2 is reserved for file-not-found / template-not-found).

### §3 — Exit-code table (behavioral contract)

The table below is the locked behavioral contract. Every exit-code case is testable via the bats fixture matrix.

**`validate-agent-names.sh`:**

| Exit code | Trigger                                                                                                                                                                                              | Category    |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 0         | All §9 names resolve in S2∪S3∪S4∪exempt AND every S2∪S3 name appears in §9; OR empty agents dir (0/0/0 per Q5).                                                                                      | OK          |
| 1         | §9 name unresolved in S2∪S3∪S4∪exempt; OR S2∪S3 name absent from §9; OR JSONC parse error in either project JSONC (HARD per Q2); OR missing required routing reference in oh-my-opencode-slim.jsonc. | HARD fail   |
| 2         | INFRA: `AGENTS.md` not found at repo root; OR `.opencode/opencode.jsonc` not found; OR `.opencode/oh-my-opencode-slim.jsonc` not found; OR `python3` not on PATH.                                    | INFRA error |

**`validate-handoff.sh`:**

| Exit code | Trigger                                                                                                                       | Category    |
| --------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 0         | All 5 required subsections present (extra subsections → SOFT warn, does not flip exit).                                       | OK          |
| 1         | Missing `## Prognosis for next cycle` heading; OR any of the 5 required `###` subsections missing.                            | HARD fail   |
| 2         | INFRA: no input path argument; OR input file does not exist; OR `openspec/templates/HANDOFF.md` reference template not found. | INFRA error |

### §4 — Stream contract (locked)

- **stderr:** `FAIL: <message>` lines for HARD failures; `warn: <message>` lines for SOFT warnings.
- **stdout:** `ok: <message>` lines for passes; final summary line `N passed, M failed, K warnings`.
- **Fail-fast:** NEVER. Collect all findings, then exit. (Per Q5 ruling — "collect-all never fail-fast".)
- **Shell defaults:** both scripts use `set -euo pipefail`. (Per Q5 ruling.)

Note: `set -e` with collect-all requires care — the script must NOT let `set -e` abort on individual check failures. Pattern: each check is wrapped in an `if` or `||` clause that captures the failure into the accumulator instead of propagating it. Same pattern as `validate-skills.sh`.

### §5 — Makefile wiring

**Locked decision (Q4):** wire both into the existing `make test-config` target (alongside the pre-existing `validate-skills.sh` + `validate-opencode-config.sh`). No new `test-dev-infra` target.

**Shape options (coder-lane detail — spec pins the invariant, not the exact recipe form):**

- **Option A (prereq):** add `test-validate-agent-names` and `test-validate-handoff` as `.PHONY` prereqs of `test-config` (same shape as the existing `test-interview` / `test-skills` prereqs).
- **Option B (recipe line):** append `bash scripts/validate-agent-names.sh && bash scripts/validate-handoff.sh` to the existing `test-config` recipe body.
- **Option C (hybrid):** one as prereq, one as recipe line.

The spec pins the invariant: after T4, running `make test-config` MUST invoke both validators AND the pre-existing `validate-opencode-config.sh`. The exact shape (A/B/C) is a coder-lane decision based on which shape best matches the existing Makefile style. The coder's handoff must document which shape was chosen and why.

**Invariants (locked regardless of shape):**

- Both scripts are make-callable: `make test-config` invokes them with no arguments and they discover the project root via `${BASH_SOURCE[0]}` dirname traversal (same as `validate-skills.sh`).
- Both scripts have a standalone exit-code contract: they can be invoked directly via `bash scripts/validate-agent-names.sh` or `bash scripts/validate-handoff.sh <handoff-path>` from the repo root with the same exit-code semantics as via Make.
- `bash -n` syntax checks for both scripts run in `make test-shell` via `bats-wrapper.sh` (T2/T3 extension to the loop).
- The wiring regression test (T4) asserts the Makefile body references both script filenames (static grep, same shape as the arch-failfast test in `opencode-docker.bats`).

### §6 — T1 — DIA-050 tracking note

Non-code deliverable. Uses the existing ticket template (`docs/dev-infra-audit/tickets/_TEMPLATE.md`). Fields:

- `id: DIA-050`
- `title: ".mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15)"`
- `area: dev-infra`
- `severity: Low` (no runtime impact — only drift risk for developers reading `.mise.toml` alongside the Dockerfile)
- `status: OPEN`
- `blocked_by: []`
- `source: dia-045-followup`
- `date: 2026-08-05`
- `created: 2026-08-05`
- `updated: 2026-08-05`

Body: a short Description section pointing at DIA-045 F15 ("`.mise.toml` ↔ `Dockerfile.dev` pin sync gap untracked") and noting that `openspec/changes/volta-to-mise/` §2.1's header comment documents the current one-time manual sync — the gap is that no automated validator enforces parity. Fix is out of scope for this change.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                      | What it is                                                                                               | Test location                                                                                                   | Test type                                                                                     |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **S1 — `scripts/validate-agent-names.sh`**                | Cross-reference validator for the 4 agent-name sources.                                                  | `scripts/__tests__/validate-agent-names.bats` (new suite, `AGENTS_ROOT` env override for fixture trees).        | Behavioral: exit code + stderr/stdout content per 10-case fixture matrix.                     |
| **S2 — `scripts/validate-handoff.sh`**                    | HANDOFF.md prognosis-schema validator.                                                                   | `scripts/__tests__/validate-handoff.bats` (new suite).                                                          | Behavioral: exit code + stderr/stdout content per 6-case fixture matrix.                      |
| **S3 — `Makefile` `test-config` target wiring**           | `make test-config` invokes both new validators alongside `validate-opencode-config.sh`.                  | `scripts/__tests__/test-config-wiring.bats` (new) OR appended to an existing file; static grep over `Makefile`. | Structural assertion: `grep`-based (same shape as `opencode-docker.bats` arch-failfast test). |
| **S4 — `bash -n` syntax-check loop in `bats-wrapper.sh`** | Both new scripts pass `bash -n` syntax check on every `make test-shell` run.                             | `scripts/__tests__/bats-wrapper.sh` (modified — added entries).                                                 | Implicit: `bash -n` runs in `make test-shell`; syntax errors fail the build.                  |
| **S5 — `test-helper.bash` extensions** (conditional)      | New assertion helpers if `assert_file_contains` (substring-only) is insufficient for the fixture matrix. | `scripts/__tests__/test-helper.bash` (modified — conditional additions).                                        | Helper additions — exercised by every test that uses them.                                    |

### New seams vs. existing seams

- **S1 + S2 are new top-level scripts but reuse the existing bats harness** (`bats-wrapper.sh`, `test-helper.bash`). No new harness infrastructure needed.
- **S3 is a new bats test** (or append to existing) for the wiring regression. The natural home is either `scripts/__tests__/test-config-wiring.bats` (new, dedicated file) or appended to an existing Makefile-aware test if one exists. Decision for the coder lane; default to a new file for clarity.
- **S4 extends the existing `bash -n` loop** (no new seam).
- **S5 is conditional** — only if the existing assertion vocabulary is insufficient. The coder lane decides based on whether substring-match (`assert_file_contains`) is enough for the HANDOFF fixture predicates (likely yes — strict literal match means substring is the right predicate).

### Testability env seams

- **`AGENTS_ROOT` env override** for `validate-agent-names.sh` — points the validator at a temp fixture tree for bats tests. Same shape as `SKILLS_ROOT` in `validate-skills.sh`.
- **First positional argument** for `validate-handoff.sh` — the HANDOFF file path. bats tests pass temp-fixture paths via this argument.
- **`REPO_ROOT` env override** (conditional) — if the validator needs to find `openspec/templates/HANDOFF.md` via a path that differs from the bats test's `REPO_ROOT` (the test-helper's existing `REPO_ROOT` is set to the real repo root; the validator should use the same mechanism). If the validator uses `${BASH_SOURCE[0]}` dirname traversal to find `openspec/templates/HANDOFF.md` relative to itself, it works both in production (invoked from repo root via Make) and in bats tests (same repo-relative path). Decision for the coder lane — default to `${BASH_SOURCE[0]}` dirname traversal for the template reference, matching `validate-skills.sh`'s pattern for finding `SKILLS_ROOT`.

## Design constraints and trade-offs

### Why kebab-case internal name as the canonical key (Q2 ruling)

The AGENTS.md §9 table already uses kebab-case for the "Internal name" column (`code-navigator`, `ai-specialist`, `resource-manager`, `memory-manager`, etc.). The 4 sources already use kebab-case natively except for a couple of historical holdovers that DIA-045 already cleaned up (the `ai_specialist` / `resource_manager` underscore→hyphen renames). Using kebab-case as the canonical form means the validator is a no-op transform on 99% of inputs — the comparison is equality, not normalization. This is the simplest, most auditable choice.

### Why JSONC parse failure is HARD fail, not INFRA (Q2 ruling)

An INFRA error (exit 2) signals "the validator's own environment is broken — cannot run the check at all". A JSONC parse failure signals "the config file is broken — the check ran and found a defect". These are different conditions with different remediation paths. If `.opencode/opencode.jsonc` contains malformed JSONC, the developer needs to fix the file, not the validator's environment. Categorizing parse failure as HARD (exit 1) surfaces the defect as a first-class finding in the test report, which is the correct remediation signal.

### Why exact-name only for HANDOFF.md (no glob, Q2 ruling)

Glob-based discovery would silently validate stale HANDOFF files left over from past cycles. The validator's contract is to validate a specific HANDOFF file passed in — the caller decides which one. This matches the fresh-session verifier contract (the verifier knows exactly which HANDOFF it is verifying). If a future need arises to walk a directory of HANDOFF files, a wrapper script is the right abstraction — not overloading this validator.

### Why disabled agents STILL validated (Q2 ruling)

A disabled agent is still a declared agent. Its name must remain consistent across sources because: (a) re-enabling a disabled agent is a one-line change in `oh-my-opencode-slim.jsonc` — if the name is drifted, re-enablement silently breaks dispatch; (b) the disabled list itself is a cross-reference source (the agent name appears in `disabled_agents`, and that reference must match the declared name in the `agents` block). Excluding disabled agents from validation creates a drift reservoir that grows silently.

### Why extra HANDOFF subsections are SOFT warn, not HARD fail (Q5 ruling)

The Prognosis schema is a minimum contract (5 subsections must be present). Handoff authors may add subsections for cycle-specific context (e.g., a `### blockers_encountered` or `### decision_log` subsection). These are additive — they do not violate the contract, and the fresh-session verifier can still reconstruct context from the 5 required subsections. A HARD fail on extras would over-constrain the handoff authoring workflow for no robustness gain.

### Why `set -euo pipefail` AND collect-all (Q5 ruling — not contradictory)

`set -e` aborts on the first uncaught non-zero exit. Collect-all requires the script to continue past individual check failures. The two combine correctly when every check is wrapped in an `if` or `||` clause that captures the failure into an accumulator. `set -e` then protects against truly unexpected failures (command-not-found, missing file when not gated, etc.) while the explicit check wrappers handle the expected failure paths. Same pattern as `validate-skills.sh` lines 32+ (the inline python validator emits `HARD|...` lines that bash wraps with `||` to accumulate).

## Verification gate summary

| Gate                                                                          | When        | Required                                                                                                                                          |
| ----------------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make test-shell`                                                             | After T2/T3 | 93/93 bats tests pass (pre-existing baseline) + new `validate-agent-names.bats` + `validate-handoff.bats` + wiring test pass.                     |
| `make test-config`                                                            | After T4    | Pre-existing 20 passed / 0 failed / 33 soft warnings + both new validators exit 0 on the real project config.                                     |
| `bash scripts/validate-agent-names.sh` (standalone)                           | After T2    | Exit 0 on the real project config (all §9 names resolve, all S2∪S3 names canonical, post-DIA-045 cleanup + row-420 declared-⊆-resolved contract). |
| `bash scripts/validate-handoff.sh openspec/templates/HANDOFF.md` (standalone) | After T3    | Exit 0 on the real template (all 5 required subsections present).                                                                                 |
| Manual: DIA-050 ticket                                                        | After T1    | Ticket exists at `docs/dev-infra-audit/tickets/DIA-050.md`, uses `_TEMPLATE.md` shape, points at DIA-045 F15.                                     |
| Wiring regression                                                             | After T4    | bats test asserts `Makefile` `test-config` body references both validators.                                                                       |

## Traceability to confirmed rulings

Every design decision above is locked to a confirmed interview ruling. The mapping:

| Decision                                                                                                                                                                                                        | Ruling source                                                                                                                             |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Single change `dev-infra-config-validators`                                                                                                                                                                     | Q1                                                                                                                                        |
| T1 = DIA-050/F15 tracking note                                                                                                                                                                                  | Q1                                                                                                                                        |
| T2 = `validate-agent-names.sh` + bats                                                                                                                                                                           | Q1                                                                                                                                        |
| T3 = `validate-handoff.sh` + bats                                                                                                                                                                               | Q1                                                                                                                                        |
| T4 = Makefile wiring into existing `test-config`                                                                                                                                                                | Q1, Q4                                                                                                                                    |
| kebab-case internal name as canonical key                                                                                                                                                                       | Q2 (ruling 1)                                                                                                                             |
| Containment across 4 sources (each §9 name resolves; each S2∪S3 name is canonical — row 420 supersedes strict equality reading)                                                                                 | Q2 (ruling 2), Owner ruling row 420                                                                                                       |
| Disabled agents STILL validated                                                                                                                                                                                 | Q2 (ruling 3)                                                                                                                             |
| Global config OUT of scope                                                                                                                                                                                      | Q2 (ruling 4)                                                                                                                             |
| agent/\*.md stems IN scope                                                                                                                                                                                      | Q2 (ruling 5)                                                                                                                             |
| HANDOFF.md exact-name only (no glob)                                                                                                                                                                            | Q2 (ruling 6)                                                                                                                             |
| Strict literal match on 5 required ### subsections                                                                                                                                                              | Q2 (ruling 7)                                                                                                                             |
| JSONC parse failure = HARD fail                                                                                                                                                                                 | Q2 (ruling 8)                                                                                                                             |
| Wire both into existing `test-config`                                                                                                                                                                           | Q4                                                                                                                                        |
| Standalone exit-code contract + make-callable                                                                                                                                                                   | Q4                                                                                                                                        |
| NO new `test-dev-infra` target                                                                                                                                                                                  | Q4                                                                                                                                        |
| Exit 2 = INFRA                                                                                                                                                                                                  | Q5                                                                                                                                        |
| Exit 0 = OK (empty agents dir = 0/0/0)                                                                                                                                                                          | Q5                                                                                                                                        |
| Exit 1 = HARD (containment violation / JSONC parse / missing required heading)                                                                                                                                  | Q5, Owner ruling row 420 (containment framing)                                                                                            |
| SOFT warn for HANDOFF extra heading                                                                                                                                                                             | Q5                                                                                                                                        |
| Collect-all never fail-fast                                                                                                                                                                                     | Q5                                                                                                                                        |
| Stream contract: stderr `FAIL:`/`warn:` + stdout `ok:` + final summary                                                                                                                                          | Q5                                                                                                                                        |
| `set -euo pipefail` both scripts                                                                                                                                                                                | Q5                                                                                                                                        |
| S3 slim-mode extraction includes: `agents` keys, `routing`/preset values, `disabled_agents` list, AND the presence of the top-level `council` KEY itself (single name `council` → S3-valid)                     | Owner ruling row 420 (amendment to §1 source-3 extraction; supersedes row-415 council-members read — members are model seats, not agents) |
| S3 council block **MEMBERS** (`deepseek`, `gemini-3.1-pro`, `gpt-5.3-codex`, `claude-sonnet-4.5`, `qwen3.7-plus`) are NOT extracted as agent names                                                              | Owner ruling row 420 (structural correction — these are model seat names, not agent names)                                                |
| Declared-⊆-resolved containment contract (S1→S2∪S3∪S4∪exempt; S2∪S3→S1), replacing strict 4-way symmetric-difference lockstep                                                                                   | Owner ruling row 420 (supersedes strict Q2-4 lockstep reading AND row-415's active-15 full-lockstep amendment)                            |
| S4-exemption for built-ins/native-aliases (`explore`, `general`, `oracle`, `fixer`, `explorer`, `librarian`) — S4 absence is correct, not drift (now a clause of the declared-⊆-resolved contract, invariant 1) | Owner ruling row 415 (retained), row 420 (reframed as containment-clause rather than lockstep-exemption)                                  |

No decision in this design.md is invented beyond the confirmed rulings. If a gap emerges during implementation, the coder lane flags it to the orchestrator rather than deciding silently.
