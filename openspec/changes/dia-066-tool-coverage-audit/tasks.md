# Tasks: dia-066-tool-coverage-audit

> **Proposal:** `openspec/changes/dia-066-tool-coverage-audit/proposal.md`
> **Design:** `openspec/changes/dia-066-tool-coverage-audit/design.md`
> **Source ticket:** `docs/dev-infra-audit/tickets/DIA-066.md` (tool-coverage audit script — surface unlisted default-allow tools).
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md §2.4 (dev-infra within existing boundaries → `@reviewer`, two-axis: Standards + Spec fidelity). No §10 AI-tooling routing — the auditor only READS opencode config; it does not modify it.

## Dependency graph

```
T1 (script skeleton + argument parsing + exit-code contract)
 │
 │ (foundation — T2/T3 proceed in parallel)
 │
 ├──▶ T2 (static JSONC parse: agents + permission blocks)
 │
 ├──▶ T3 (runtime census integration: AUDIT_TOOL_CENSUS_FILE seam)
 │
 └──▶ T4 (cross-reference logic + output formatting + gap detection)
         │
         │ (depends on T2 + T3 — needs both to cross-reference)
         │
         ├──▶ T5 (blanket-form detection + v2 schema detection)
         │
         └──▶ T6 (Makefile wiring + integration test)
                 │
                 │ (depends on T4 + T5 — wires everything into test-config)
```

**Critical path:** T1 → T2 → T4 → T6 OR T1 → T3 → T4 → T6 (symmetric; the coder lane picks the order).
**Parallel track:** T2 and T3 are independent and can be implemented in either order or in parallel. T5 depends on T2 (blanket-form is a static parse special case). T6 depends on T4 and T5.
**Rationale for ordering:**

- **T1 is first** because it is the foundation (script skeleton, argument parsing, exit-code contract). T2/T3/T4/T5/T6 all build on T1.
- **T2 and T3 are independent** because they touch disjoint concerns. T2 parses the config JSONC; T3 stubs the runtime census. No shared state, no shared interface, no sequential dependency.
- **T4 depends on T2 and T3** because it cross-references the static parse (agents + permission blocks) with the runtime census (tool universe). Neither is meaningful without the other.
- **T5 depends on T2** because blanket-form detection is a special case of static parsing (scalar `"permission"` vs per-tool map). v2 schema detection is also a static parse concern.
- **T6 depends on T4 and T5** because it wires the complete auditor into `make test-config`. The wiring is not meaningful until the auditor itself exists.
- **No blocking edges between T2/T3 that prevent independent verification** (briefing constraint). Each task can be verified in isolation: T2 runs standalone via `bash scripts/audit-agent-tool-coverage.sh <config>` (parse-only mode, no runtime census); T3 runs standalone with `AUDIT_TOOL_CENSUS_FILE` set (census-only mode, no cross-reference).

---

## T1 — Script skeleton + argument parsing + exit-code contract

**Blockers:** none
**Vertical slice:** create `scripts/audit-agent-tool-coverage.sh` with basic argument parsing, exit-code contract scaffolding, and a "no config" test. After T1, running `bash scripts/audit-agent-tool-coverage.sh` (no args) produces exit 2 (INFRA) with a clear "missing config file" message.

### What changes

1. **`scripts/audit-agent-tool-coverage.sh`** (new file, executable, `set -euo pipefail`). Behavior:
   - Takes one optional argument: config file path (default: `.opencode/opencode.jsonc`).
   - Checks if the config file exists. If not → exit 2 (INFRA) with message: `error: config file not found: <path>`.
   - Checks if `python3` is available. If not → exit 2 (INFRA) with message: `error: python3 is required to parse JSONC configs.`
   - Checks if `opencode` is available (only if `AUDIT_TOOL_CENSUS_FILE` is NOT set). If not → exit 2 (INFRA) with message: `error: opencode binary not found in PATH; install opencode or set AUDIT_TOOL_CENSUS_FILE`.
   - Exit 0 if all checks pass (placeholder — no logic yet).

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** (new file). Initial test cases:
   - **Test 1:** no config file → exit 2 + stderr contains "config file not found".
   - **Test 2:** no `python3` → exit 2 + stderr contains "python3 is required".
   - **Test 3:** no `opencode` (and `AUDIT_TOOL_CENSUS_FILE` not set) → exit 2 + stderr contains "opencode binary not found".

### Acceptance criteria (user perspective)

- The script exists at `scripts/audit-agent-tool-coverage.sh` and is executable.
- Running the script with no config file produces exit 2 + clear error message.
- Running the script with a missing `python3` produces exit 2 + clear error message.
- Running the script with a missing `opencode` (and no `AUDIT_TOOL_CENSUS_FILE`) produces exit 2 + clear error message.
- The bats tests pass.

### Verification procedure

1. `bash scripts/audit-agent-tool-coverage.sh /nonexistent` — exits 2, stderr contains "config file not found".
2. `PATH=/usr/bin:/bin bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` (simulating no `python3`) — exits 2, stderr contains "python3 is required".
3. `PATH=/usr/bin:/bin AUDIT_TOOL_CENSUS_FILE=/dev/null bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` (simulating no `opencode`) — exits 0 (because `AUDIT_TOOL_CENSUS_FILE` is set, the `opencode` check is skipped).
4. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Uses `test-helper.bash` assertions (`assert_status`, `assert_output_contains`).

---

## T2 — Static JSONC parse: agents + permission blocks

**Blockers:** T1
**Vertical slice:** extend the auditor to parse the config JSONC and extract each agent's permission block. After T2, running `bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` lists all agents and their permission blocks (placeholder output — no cross-reference yet).

### What changes

1. **`scripts/audit-agent-tool-coverage.sh`** — extend with static JSONC parse:
   - Use `python3` to parse the JSONC file (follow `validate-agent-names.sh` pattern).
   - Extract the global `permission` block (if present).
   - Extract each agent's `permission` block from the `agents` block.
   - Detect v1 vs v2 schema: if `permissions` (array) is present → exit 2 (INFRA) with message: "v2 permission schema detected — audit script not yet adapted".
   - Detect blanket form: if `permission` is a scalar (not a map) → emit `WARN: <file>:<line> blanket permission=<value>` and skip per-tool enumeration for that config.
   - Placeholder output: list each agent and its permission block (no cross-reference yet).

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — extend with parse tests:
   - **Test 4:** valid v1 config → exit 0 (placeholder) + lists agents.
   - **Test 5:** v2 config (with `permissions: []`) → exit 2 + stderr contains "v2 permission schema detected".
   - **Test 6:** blanket-form config → exit 0 (placeholder) + stderr contains "WARN: blanket permission".

### Acceptance criteria (user perspective)

- The script parses the config JSONC and extracts the global + per-agent permission blocks.
- The script detects v2 schema and exits 2 with a clear message.
- The script detects blanket-form and emits a `WARN:` line.
- The bats tests pass.

### Verification procedure

1. `bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` — exits 0, lists agents (placeholder output).
2. Create a synthetic v2 config with `permissions: []` → `bash scripts/audit-agent-tool-coverage.sh <v2-config>` exits 2, stderr contains "v2 permission schema detected".
3. Create a synthetic blanket-form config with `"permission": "allow"` → `bash scripts/audit-agent-tool-coverage.sh <blanket-config>` exits 0, stderr contains "WARN: blanket permission".
4. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Uses temp fixture trees with synthetic configs (follows `validate-agent-names.bats` pattern).

---

## T3 — Runtime census integration: AUDIT_TOOL_CENSUS_FILE seam

**Blockers:** T1
**Vertical slice:** extend the auditor to obtain the tool universe via the runtime census (or the `AUDIT_TOOL_CENSUS_FILE` env override). After T3, running the script with `AUDIT_TOOL_CENSUS_FILE` set loads the census from the file; without it, the script invokes `opencode debug agent <canonical-agent>`.

### What changes

1. **`scripts/audit-agent-tool-coverage.sh`** — extend with runtime census:
   - Check for `AUDIT_TOOL_CENSUS_FILE` env var.
   - If set: read the census from the file (JSON format: `{"tools": {"tool1": true, "tool2": true, ...}}`).
   - If not set: invoke `opencode debug agent <canonical-agent>` where `<canonical-agent>` is the first alphabetical agent in the config. Parse the JSON output and extract the `tools` map.
   - If the `opencode` invocation fails (no default model, etc.) → exit 2 (INFRA) with message: "error: opencode debug agent failed — no default model resolvable".
   - Placeholder output: list the tool universe (no cross-reference yet).

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — extend with census tests:
   - **Test 7:** `AUDIT_TOOL_CENSUS_FILE` set → exit 0 (placeholder) + lists tools.
   - **Test 8:** `AUDIT_TOOL_CENSUS_FILE` not set + `opencode` fails → exit 2 + stderr contains "opencode debug agent failed".

### Acceptance criteria (user perspective)

- The script obtains the tool universe via `AUDIT_TOOL_CENSUS_FILE` (test mode) or `opencode debug agent` (production mode).
- The script handles `opencode` invocation failure gracefully (exit 2 + clear message).
- The bats tests pass.

### Verification procedure

1. Create a synthetic census JSON file → `AUDIT_TOOL_CENSUS_FILE=<census.json> bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` exits 0, lists tools.
2. Simulate `opencode` failure (e.g., no default model) → `bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc` exits 2, stderr contains "opencode debug agent failed".
3. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Uses `AUDIT_TOOL_CENSUS_FILE` env override for hermeticity.

---

## T4 — Cross-reference logic + output formatting + gap detection

**Blockers:** T2, T3
**Vertical slice:** extend the auditor to cross-reference the static parse (agents + permission blocks) with the runtime census (tool universe) and report gaps with severity tiering per Decision 6. After T4, running the script reports `FAIL:` lines for write-capable gaps (HARD → exit 1), `WARN:` lines for non-write-capable gaps (do not flip exit code), `ok:` lines for agents with full coverage, and a final summary.

### What changes

1. **`scripts/audit-agent-tool-coverage.sh`** — extend with cross-reference logic:
   - Compute effective coverage for each agent: global ∪ per-agent merge.
   - Compute gaps = (tool universe − effective coverage) where the default disposition is `allow`.
   - **Severity tiering (Decision 6):** classify each gap against the canonical write-capable tool list (hardcoded in script, overrideable via `AUDIT_WRITE_CAPABLE_TOOLS` env var). Write-capable tools: `write`, `edit`, `ast_grep_replace`, `bash`, `webfetch`, `task`, `envsitter_set`, `envsitter_delete`, `envsitter_format`, `envsitter_reorder`, `envsitter_unset`, `envsitter_add`, `envsitter_copy`.
   - For each **write-capable gap** (HARD): emit `FAIL: <file>:<line> agent=<name> tool=<tool-id> default=allow severity=HARD` to stderr.
   - For each **non-write-capable gap** (WARN): emit `WARN: <file>:<line> agent=<name> tool=<tool-id> default=allow severity=WARN` to stderr.
   - For each agent with zero HARD gaps: emit `ok: agent=<name> <N> tools covered, 0 hard gaps` to stdout.
   - Final summary: `N agents audited, M hard gaps, K warnings` to stdout.
   - Exit 1 if any HARD (write-capable) gaps found; exit 0 otherwise. WARN-only gaps do NOT flip the exit code.

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — extend with gap detection tests:
   - **Test 9:** config with zero gaps → exit 0 + stdout contains "ok: agent=<name>" + summary "0 hard gaps".
   - **Test 10:** config with one write-capable gap (remove a deny rule on `write`, `edit`, or `bash` — must be a write-capable tool per Decision 6) → exit 1 + stderr contains "FAIL: ... agent=<name> tool=<tool-id> severity=HARD".
   - **Test 11:** effective coverage semantics (tool covered globally but not per-agent) → exit 0 (no gap for that agent).
   - **Test 11b (WARN-only gap):** config with one non-write-capable gap (e.g., `read` or `glob` unlisted) → exit 0 + stderr contains "WARN: ... severity=WARN" + summary shows warnings incremented but 0 hard gaps.

### Acceptance criteria (user perspective)

- The script reports write-capable gaps with `FAIL: <file>:<line> agent=<name> tool=<tool-id> default=allow severity=HARD` on stderr.
- The script reports non-write-capable gaps with `WARN: <file>:<line> agent=<name> tool=<tool-id> default=allow severity=WARN` on stderr.
- The script reports clean agents with `ok: agent=<name> <N> tools covered, 0 hard gaps` on stdout.
- The script reports a final summary `N agents audited, M hard gaps, K warnings` on stdout.
- The script exits 1 if any HARD (write-capable) gaps found; exit 0 otherwise. WARN-only gaps do NOT flip the exit code.
- The bats tests pass.

### Verification procedure

1. Create a synthetic config + census with zero gaps → script exits 0, stdout contains "ok: agent=<name>" + summary "0 hard gaps".
2. Create a synthetic config + census with one **write-capable** gap (e.g., remove deny rule on `bash` from the canonical write-capable list) → script exits 1, stderr contains "FAIL: ... agent=<name> tool=bash severity=HARD".
3. Create a synthetic config + census with one **non-write-capable** gap (e.g., `read` or `glob` unlisted) → script exits 0, stderr contains "WARN: ... severity=WARN", summary contains "0 hard gaps, 1 warnings".
4. Create a synthetic config where a tool is covered globally but not per-agent → script exits 0 (no gap for that agent).
5. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Uses temp fixture trees + `AUDIT_TOOL_CENSUS_FILE` env override.

---

## T5 — Blanket-form detection + v2 schema detection

**Blockers:** T2
**Vertical slice:** extend the auditor to handle blanket-form and v2 schema as special cases. After T5, running the script against a blanket-form config produces a `WARN:` line (not a false flood); running against a v2 config exits 2.

### What changes

1. **`scripts/audit-agent-tool-coverage.sh`** — extend with blanket-form + v2 detection:
   - **Blanket-form:** if `permission` is a scalar (not a map), emit `WARN: <file>:<line> blanket permission=<value> — N tools unlisted-by-name` to stderr. Do NOT attempt per-tool enumeration against the blanket. Count N = (tool universe size).
   - **v2 schema:** if `permissions` (array) is present, exit 2 (INFRA) with message: "v2 permission schema detected — audit script not yet adapted for last-match-wins semantics".
   - Increment the warnings counter for blanket-form.

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — extend with blanket-form + v2 tests:
   - **Test 12:** blanket-form config → exit 0 (no HARD gaps) + stderr contains "WARN: blanket permission" + summary "0 gaps, 1 warnings".
   - **Test 13:** v2 config → exit 2 + stderr contains "v2 permission schema detected".

### Acceptance criteria (user perspective)

- The script detects blanket-form and emits a `WARN:` line with the count of unlisted-by-name tools.
- The script does NOT attempt per-tool enumeration against a blanket.
- The script detects v2 schema and exits 2 with a clear message.
- The bats tests pass.

### Verification procedure

1. Create a synthetic blanket-form config + census → script exits 0, stderr contains "WARN: blanket permission=<value> — N tools unlisted-by-name", summary contains "0 gaps, 1 warnings".
2. Create a synthetic v2 config → script exits 2, stderr contains "v2 permission schema detected".
3. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Uses temp fixture trees + `AUDIT_TOOL_CENSUS_FILE` env override.

---

## T6 — Makefile wiring + integration test

**Blockers:** T4, T5
**Vertical slice:** wire the auditor into the `test-config` Makefile target. After T6, running `make test-config` invokes the auditor for both `.opencode/opencode.jsonc` and `tools/opencode-docker/config/opencode.json`.

### What changes

1. **`Makefile`** — extend the `test-config` target:
   - Add two recipe lines:
     ```make
     @bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc
     @bash scripts/audit-agent-tool-coverage.sh tools/opencode-docker/config/opencode.json
     ```
   - The auditor is invoked twice: once for the main config, once for the container profile.

2. **`scripts/__tests__/audit-agent-tool-coverage.bats`** — extend with integration test:
   - **Test 14:** `make test-config` → exits 0 (assuming the current config has no gaps after DIA-055 fixes).

### Acceptance criteria (user perspective)

- `make test-config` invokes the auditor for both config profiles.
- The auditor exits 0 if no HARD (write-capable) gaps are found; exits 1 if write-capable gaps are found. **Invariant: `make test-config` passes iff no HARD write-capable gaps remain** (Decision 6 scoping — WARN-only gaps do not flip the exit code, so `make test-config` is not broken by the ~440 non-write-capable unlisted tools).
- The bats tests pass.

### Verification procedure

1. `make test-config` — exits 0 (assuming no gaps), runs the auditor for both configs.
2. Temporarily introduce a gap in `.opencode/opencode.jsonc` → `make test-config` exits 1, stderr contains "FAIL: ...".
3. `bats scripts/__tests__/audit-agent-tool-coverage.bats` — all tests pass.

### Testing

bats tests in `scripts/__tests__/audit-agent-tool-coverage.bats`. Integration test verifies the Makefile wiring.

---

## Summary

| Task | Blockers | Vertical slice                                                                          | Exit criteria                                                                           |
| ---- | -------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| T1   | none     | Script skeleton + argument parsing + exit-code contract                                 | Script exits 2 on missing config/python3/opencode                                       |
| T2   | T1       | Static JSONC parse (agents + permission blocks)                                         | Script lists agents + detects v2/blanket                                                |
| T3   | T1       | Runtime census integration (AUDIT_TOOL_CENSUS_FILE seam)                                | Script loads census from file or invokes `opencode debug agent`                         |
| T4   | T2, T3   | Cross-reference logic + output formatting + gap detection (Decision 6 severity tiering) | Script reports write-capable gaps as FAIL (exit 1) + non-write-capable as WARN (exit 0) |
| T5   | T2       | Blanket-form detection + v2 schema detection                                            | Script emits `WARN:` for blanket + exits 2 for v2                                       |
| T6   | T4, T5   | Makefile wiring + integration test                                                      | `make test-config` invokes auditor for both configs                                     |

**Total tasks:** 6
**Estimated effort:** 1-2 days (each task is a single context window)
**Critical path:** T1 → T2 → T4 → T6 OR T1 → T3 → T4 → T6
