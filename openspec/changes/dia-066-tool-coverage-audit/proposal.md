# Proposal: dia-066-tool-coverage-audit

> **Status:** proposed · **Scope:** dev-infra (`scripts/`, `scripts/__tests__/`, `Makefile`). No application code touched.
> **Escalation:** none — change stays within existing module boundaries. Per AGENTS.md §2.4 (dev-infra within existing boundaries → spec chain + `@reviewer`), no `@architector` dispatch is required.
> **Source ticket:** `docs/dev-infra-audit/tickets/DIA-066.md` (tool-coverage audit script — surface unlisted default-allow tools). All decisions below trace to owner-confirmed interview rulings (Q1–Q7).

## Why

OpenCode permission blocks are per-tool override maps — **unlisted tools fall through to the global permission block → default allow** (DIA-055 root cause). Today, there is no deterministic gate that surfaces newly registered tools (plugin upgrades, new plugins, new built-ins) before they silently become write-capable for every agent. This script converts that systemic exposure into a repeatable, hermetic CI gate.

**Why now:** DIA-055's R2 (2026-08-08) closed the immediate token-export permission gap, but the fix-lane review flagged the recurrence risk: every future plugin install or opencode upgrade can silently reintroduce default-allow tools. DIA-066 is the remediation — a drift-detection gate that fails the build before unlisted tools ship.

## What Changes

1. **`scripts/audit-agent-tool-coverage.sh`** — hybrid tool-coverage auditor:
   - **Runtime census:** invokes `opencode debug agent <canonical-agent>` once (first alphabetical agent in `.opencode/opencode.jsonc`) to obtain the complete registered-tool set (built-ins + plugin-registered + MCP).
   - **Static parse:** parses each agent's `permission` block from the config JSONC using `python3`.
   - **Cross-reference:** computes effective coverage (global ∪ per-agent merge) and reports gaps = (tool universe − effective coverage) where the default disposition is `allow`.
   - **Output contract:** `FAIL:`/`WARN:` to stderr, `ok:` to stdout, final summary `N agents audited, M gaps, K warnings` to stdout.
   - **Exit-code contract:** 0 (no HARD gaps) / 1 (HARD gap found OR malformed JSONC) / 2 (INFRA: no `opencode`, no `python3`, no default model, v2 schema detected, missing config file).

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — hermetic bats test suite:
   - Temp fixture trees with synthetic configs (follows `validate-agent-names.bats` pattern).
   - Runtime census step stubbed via `AUDIT_TOOL_CENSUS_FILE` env override (pre-recorded JSON file — tests do NOT require a live `opencode` install).
   - Coverage: positive (zero gaps → exit 0), negative (remove a deny rule → exit 1 + reports agent), blanket-form detection, v2 schema rejection, effective-coverage merge semantics, default-ask/deny SOFT behavior.

3. **Makefile wiring** — add `audit-agent-tool-coverage.sh` to the existing `test-config` target. Invoked twice: once for `.opencode/opencode.jsonc`, once for `tools/opencode-docker/config/opencode.json` (separate passes).

## Scope (interview-confirmed)

### In scope

- Hybrid enumeration (runtime census + static parse) per Q1 ruling.
- Effective coverage semantics (global ∪ per-agent merge) per Q2.3 ruling.
- Blanket-form detection as a first-class `WARN` category per Q2.1 ruling.
- v1 schema assertion; v2 rejection (exit 2) per Q2.2 ruling.
- Default-ask/deny tools as SOFT findings (hint column, no exit-code flip) per Q2.4 ruling.
- Exit-code contract: 0 / 1 / 2 per Q2.5 and Q5 rulings.
- Hermetic bats tests via `AUDIT_TOOL_CENSUS_FILE` env override per Q7 acceptance criterion #8.
- Makefile wiring: `test-config` invokes for both main config and container profile per Q4.2 and Q4.4 rulings.

### Out of scope (explicitly deferred — interview-confirmed)

- **Caching the runtime census across invocations.** OUT of scope per Q3 ruling. Fresh run every invocation; 3-8s per CI run is acceptable for a Low-severity audit. Caching can be added later if profiling shows it matters.
- **v2 permission schema support.** OUT of scope per Q2.2 ruling. The script asserts v1 and refuses to run on v2. v2 support is a follow-up ticket when the project migrates.
- **Per-agent strict coverage reporting.** OUT of scope per Q2.3 ruling. The script reports effective (merged) coverage, not per-agent strict coverage.
- **JSON or tabular output formats.** OUT of scope per Q6 ruling. The script uses the proposed `FAIL:`/`WARN:`/`ok:` stream contract matching `validate-agent-names.sh`.
- **Any `.sdd/` module doc authoring.** See Design authority section below.
- **Anything beyond the auditor script + bats tests + Makefile wiring.**

## Design authority (.sdd/) reference

**No `.sdd/` module doc governs this change.** The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. Neither `scripts/audit-*.sh` nor the permission model (`.opencode/opencode.jsonc`, `tools/opencode-docker/config/opencode.json`) have an `.sdd/` entry.

This is the same precedent as `openspec/changes/dev-infra-config-validators/proposal.md` §Design authority and `openspec/changes/volta-to-mise/proposal.md` §Design authority (.sdd/) reference: bounded dev-infra within existing boundaries does not require architectural escalation. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill.

**Relevant existing patterns this change follows:**

- **Standalone shell validators with 3-tier exit codes** — `scripts/validate-agent-names.sh` (the immediate prior art; same `exit 0 / exit 1 / exit 2` contract, same HARD vs SOFT partition, same collect-all-never-fail-fast discipline, same stderr/stdout stream protocol).
- **Hybrid runtime+static enumeration** — no direct prior art in this repo, but the pattern is grounded in the res-2 research findings (tool enumeration mechanisms). The runtime census step is bounded (one `opencode` invocation) and the static parse follows the `validate-agent-names.sh` JSONC-parsing pattern.
- **bats meta-tests on validators** — `scripts/__tests__/validate-agent-names.bats` uses `AGENTS_ROOT` env override to point the validator at a temp fixture tree; this change's bats tests follow the same shape (env override for runtime census stubbing).
- **`test-helper.bash` assertion vocabulary** — `assert_status`, `assert_output_contains`, `assert_file_contains` reused verbatim; no new assertions added.
- **Makefile `test-config` target pattern** — already aggregates `validate-skills.sh`, `validate-agent-names.sh`, `validate-handoff.sh` as recipe lines; the auditor slots in as additional recipe lines (invoked twice: once per config profile).

## Testing Decisions

**What makes a good test for this change:**

1. **Hermeticity:** tests must NOT depend on a live `opencode` install or the project's actual `.opencode/opencode.jsonc`. The runtime census step is stubbed via `AUDIT_TOOL_CENSUS_FILE` env override pointing at a pre-recorded JSON file.
2. **Negative testing:** the test suite must include a case where removing a deny rule on a **write-capable** tool (e.g., `write`, `edit`, or `bash` from the canonical list per Decision 6) from a synthetic config triggers exit 1 and reports the offending agent block (DIA-066 verification #3). Removing a deny rule on a non-write-capable tool (e.g., `read`, `glob`) produces a WARN but does NOT flip the exit code.
3. **Boundary conditions:** blanket-form detection, v2 schema rejection, effective-coverage merge semantics, default-ask/deny SOFT behavior — each gets a dedicated bats test case.
4. **Exit-code contract:** tests assert the 0 / 1 / 2 exit-code boundaries (no HARD gaps → 0; HARD gap found → 1; INFRA error → 2).

**Modules tested:**

- `scripts/audit-agent-tool-coverage.sh` — the auditor script itself.
- `scripts/__tests__/audit-agent-tool-coverage.bats` — the bats test suite.

**Prior art:**

- `scripts/__tests__/validate-agent-names.bats` — same shape (env override for hermeticity, temp fixture trees, `test-helper.bash` assertions).
- `scripts/__tests__/validate-handoff.bats` — same pattern for schema validation tests.

**Test seams (confirmed with developer before any test is written):**

- **Seam 1: Runtime census stubbing.** The auditor invokes `opencode debug agent <canonical-agent>` to obtain the tool universe. The bats tests stub this by setting `AUDIT_TOOL_CENSUS_FILE` to a pre-recorded JSON file. The auditor script must check for this env var and skip the runtime call if it's set.
- **Seam 2: Config file paths.** The auditor takes config file paths as arguments (default: `.opencode/opencode.jsonc`). The bats tests pass synthetic config paths from temp fixture trees.
- **Seam 3: Exit-code contract.** The auditor must exit 0 / 1 / 2 per the specified conditions. The bats tests assert these boundaries.

## Success criteria

1. **Tool-coverage drift is hermetically caught for write-capable tools.** Any newly registered **write-capable** tool (plugin upgrade, new plugin, new built-in — per the canonical list in Decision 6: `write`, `edit`, `ast_grep_replace`, `bash`, `webfetch`, `task`, `envsitter_*`) that is not explicitly covered by the permission config fails `make test-config` with a clear `FAIL:` line naming the offending agent and tool. Non-write-capable unlisted tools are reported as WARN but do NOT flip the exit code.
2. **Blanket-form exposure is surfaced.** The container profile's blanket `"permission": "allow"` form produces a `WARN:` line reporting the count of unlisted-by-name tools. The script does NOT attempt per-tool enumeration against the blanket.
3. **v2 schema is rejected.** A synthetic v2 config (with `permissions: []` array form) triggers exit 2 with a clear "v2 schema not supported" message.
4. **The script is hermetic in CI.** bats tests pass without a live `opencode` install, using temp fixture trees and the `AUDIT_TOOL_CENSUS_FILE` env override.
5. **Both config profiles are audited.** `make test-config` invokes the script for `.opencode/opencode.jsonc` AND `tools/opencode-docker/config/opencode.json`.
6. **Effective coverage semantics.** A tool covered globally but not per-agent is NOT reported as a gap for that agent.
7. **Default-ask/deny tools are SOFT.** `doom_loop`, `external_directory`, and `.env` patterns are reported with their default disposition but do NOT flip the exit code.

## Rollback plan

The change is low-risk and fully reversible:

1. **Remove the script:** `rm scripts/audit-agent-tool-coverage.sh`.
2. **Remove the tests:** `rm scripts/__tests__/audit-agent-tool-coverage.bats`.
3. **Revert Makefile wiring:** remove the two recipe lines from the `test-config` target.

No application code is touched. No config files are modified. The change is purely additive (new script + new tests + Makefile wiring). Rollback is a single `git revert`.

## References

- **Source ticket:** `docs/dev-infra-audit/tickets/DIA-066.md`
- **DIA-055 R2 finding:** `.opencode/learnings/external-patterns/2026-08-08-dia055-token-permission-closure.md` (R2 section)
- **Tool enumeration research:** `knowledge/res003-tool-enumeration/sources/` (res-2 findings)
- **Immediate prior art:** `scripts/validate-agent-names.sh`, `scripts/__tests__/validate-agent-names.bats`
- **OpenSpec change pattern:** `openspec/changes/dev-infra-config-validators/` (same shape: dev-infra, `skip_specs: true`, 3-tier exit codes, bats meta-tests)
