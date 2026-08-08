# Design: dia-066-tool-coverage-audit

> **Status:** proposed · **Schema:** spec-driven · **skip_specs:** true
> **Dependencies:** proposal.md (✓ complete)
> **Unlocks:** tasks.md

## Context

See proposal.md — §Why and §What Changes for motivation and scope. This design document explains **HOW** to implement the tool-coverage auditor, grounded in the interview rulings (Q1–Q7) and the res-2 research findings.

**Current state:** OpenCode permission blocks are per-tool override maps (v1 schema). Unlisted tools fall through to the global permission block → default allow (with exceptions for `doom_loop`, `external_directory`, and `.env` patterns). There is no deterministic gate that surfaces newly registered tools before they silently become write-capable.

**Constraints:**

- The script must run in headless CI (no interactive `opencode` session).
- The script must NOT depend on the project's actual `.opencode/opencode.jsonc` for testing (hermeticity).
- The script must follow the existing `validate-*.sh` pattern (3-tier exit codes, stderr/stdout stream contract, collect-all-never-fail-fast).
- The runtime census step requires a resolvable default model (`opencode debug agent` mechanism per res-2 finding #1).

## Goals / Non-Goals

**Goals:**

1. **Hermetic tool-coverage audit.** The script deterministically surfaces tools not explicitly covered by permission rules, with `file:line` output pointing to the offending agent block.
2. **Hybrid enumeration.** Runtime census (one `opencode debug agent` invocation) for the complete tool universe + static JSONC parse for permission blocks.
3. **Effective coverage semantics.** A tool is a "gap" only if it's not covered in the agent's block AND not covered in the global block (merge semantics).
4. **First-class blanket-form detection.** The container profile's `"permission": "allow"` blanket form produces a `WARN:` line, not a false flood of per-tool gaps.
5. **v1 schema assertion.** The script refuses to run on v2 configs (exit 2) rather than silently miscomputing coverage.
6. **Hermetic bats tests.** Tests use temp fixture trees and stub the runtime census via `AUDIT_TOOL_CENSUS_FILE` env override — no live `opencode` install required.

**Non-Goals:**

- **Caching the runtime census.** OUT of scope (Q3 ruling). Fresh run every invocation.
- **v2 permission schema support.** OUT of scope (Q2.2 ruling). Follow-up ticket when the project migrates.
- **Per-agent strict coverage reporting.** OUT of scope (Q2.3 ruling). The script reports effective (merged) coverage.
- **JSON or tabular output.** OUT of scope (Q6 ruling). Stream contract matches `validate-agent-names.sh`.

## Decisions

### Decision 1: Hybrid enumeration (runtime census + static parse)

**Choice:** One `opencode debug agent <canonical-agent>` invocation for the tool universe + static JSONC parse of each agent's permission block.

**Rationale:**

- Pure-static (JSONC parse only) cannot see plugin-registered tools (envsitter*\*, console-ninja*_, dcp\__, token\_\*) or MCP tools without maintaining a hardcoded list. The list becomes stale the moment a plugin upgrades — **this is exactly the gap DIA-066 exists to close**.
- Pure-runtime (per-agent `opencode debug agent` calls) has N× cold-start cost (16+ agents × provider startup) and does not include `file:line` source locations in the output.
- Hybrid gives census truth (one invocation) + static source locations (JSONC parse).

**Alternatives considered:**

- **Option A (pure runtime):** rejected — N× cost, no `file:line`.
- **Option B (pure static):** rejected — blind to plugin/MCP tools, defeats DIA-066's purpose.

**Canonical agent selection:** First alphabetical agent in `.opencode/opencode.jsonc` (deterministic without hardcoding a name).

### Decision 2: Exit-code contract (0 / 1 / 2)

**Choice:**

- Exit 0: run completed, no HARD gaps found (WARNs do not fail).
- Exit 1: HARD gap found (unlisted write-capable tool per Decision 6) OR malformed JSONC.
- Exit 2: INFRA error (no `opencode`, no `python3`, no default model, v2 schema detected, missing config file).

**Rationale:** Matches `validate-agent-names.sh` precedent. The "can't run the check" (INFRA) vs "check found gaps" (HARD) distinction must be preserved. Malformed JSONC is a config defect (HARD), not an INFRA error. HARD gaps are scoped to write-capable tools only (Decision 6) — all other unlisted default-allow tools are WARN and do not flip the exit code.

**Alternatives considered:**

- **All exit 2:** rejected — conflates "missing config" with "config has gaps".
- **Exit 0 for no gaps, exit 1 for everything else:** rejected — loses the INFRA vs HARD distinction.

### Decision 3: Effective coverage semantics (global ∪ per-agent merge)

**Choice:** A tool is a "gap" for agent X only if it's not covered in agent X's block AND not covered in the global block.

**Rationale:** Matches the runtime effective state. OpenCode's permission model merges global + per-agent, with agent rules taking precedence. Reporting a tool as a "gap" when it's covered globally would be a false positive.

**Alternatives considered:**

- **Per-agent strict (gap = not in agent block, regardless of global):** rejected — over-reports, doesn't match runtime behavior.
- **Global-only (ignore per-agent blocks):** rejected — misses per-agent overrides.

### Decision 4: Blanket-form detection as first-class WARN

**Choice:** When the config uses `"permission": "allow"` (scalar, not a per-tool map), the script emits `WARN: <file>:<line> blanket permission=<value> — N tools unlisted-by-name` and does NOT attempt per-tool enumeration against the blanket.

**Rationale:** The blanket form is a _different_ (and more severe) exposure mode than per-tool gaps. Conflating them would produce a false flood. The script should make the distinction explicit.

**Alternatives considered:**

- **Treat blanket as all-tools gap:** rejected — false flood, conflates two exposure modes.
- **Skip blanket with warning:** rejected — silent about the exposure.

### Decision 5: v1 schema assertion (exit 2 on v2)

**Choice:** Detect v2 by the presence of `permissions: []` (array form) and exit 2 (INFRA) with a clear message: "v2 permission schema detected — audit script not yet adapted for last-match-wins semantics."

**Rationale:** v2 has fundamentally different semantics (ordered array, last-match-wins, default-ask). Adapting to v2 means implementing last-match-wins evaluation, which is a materially different script. Ship v1-only now; treat v2 as a follow-up ticket.

**Alternatives considered:**

- **Detect and adapt to both:** rejected — materially different script, v2 support is a separate feature.
- **Assume v1, don't check:** rejected — would silently miscompute coverage if v2 semantics differ.

### Decision 6: Severity tiering — scoped HARD gaps (write-capable subset)

**Choice:** Gaps are split into two severity tiers:

- **HARD gaps (exit 1):** unlisted **write-capable tools** — tools whose documented primary purpose is to produce persistent state changes (file mutations, shell execution, network writes, or transitive dispatch to write-capable subagents). A write-capable tool unlisted from every agent's effective coverage → exit 1.
- **WARN gaps (exit 0):** all other unlisted default-allow tools. Reported as WARN with the same `file:line agent=... tool=... default=allow` format, but do NOT flip the exit code.

**Canonical write-capable tool list** (hardcoded in the script, overrideable via `AUDIT_WRITE_CAPABLE_TOOLS` env var for tests):

| Family                      | Tool IDs                                                                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| File mutation               | `write`, `edit`, `ast_grep_replace`                                                                                                |
| Shell execution             | `bash`                                                                                                                             |
| Network + disk write        | `webfetch` (via `save_binary` parameter)                                                                                           |
| Transitive dispatch         | `task` (dispatches subagents that can write)                                                                                       |
| Dotenv mutation (envsitter) | `envsitter_set`, `envsitter_delete`, `envsitter_format`, `envsitter_reorder`, `envsitter_unset`, `envsitter_add`, `envsitter_copy` |

**Classification rule for future tools:** any tool whose documented primary purpose is to produce persistent state changes (file mutations, shell execution with side effects, network writes, or transitive dispatch to write-capable subagents) is classified write-capable and must be added to the canonical list. Tools that are read-only, informational, or analytical (e.g., `read`, `glob`, `grep`, `token_stats`) are NOT write-capable.

**Rationale:** During implementation attempts (2026-08-08), the coder lane discovered that naive application of "all default-allow unlisted tools = HARD gap" produces ~440 HARD gaps against the current config, which would break `make test-config` (T6) permanently — a spec contradiction between T4 (exit 1 on HARD gaps) and T6 (test-config must exit 0). The owner ruled (Option 1, 2026-08-08) to scope HARD gaps to write-capable tools only, resolving the contradiction while preserving DIA-066's core purpose: surfacing write-capable exposure before it ships.

**Alternatives considered:**

- **All unlisted tools as HARD gaps:** rejected — ~440 gaps in current config, breaks `make test-config`, contradicts T6.
- **All unlisted tools as WARN:** rejected — loses the exit-1 signal for write-capable exposure, defeats DIA-066's core purpose.
- **Dynamic classification via tool metadata:** rejected — opencode does not expose per-tool write-capability metadata; the canonical list is the pragmatic choice.

**Interaction with Decision 6 (original — default-ask/deny tools):** The original Decision 6 is now subsumed. Default-ask/deny tools remain SOFT (hint column, no exit-code flip) — this is consistent with the new tiering: they are WARN by default disposition, not HARD.

### Decision 8: No caching of runtime census

**Choice:** Fresh run every invocation. No `.cache/` directory, no mtime-based invalidation.

**Rationale:** The script is a CI gate, not a hot-path tool. 3-8s per CI run is acceptable. Cache invalidation is subtle (any plugin install, opencode upgrade, or config change should invalidate). Getting this wrong produces exactly the lie DIA-066 exists to prevent.

**Alternatives considered:**

- **mtime-based cache:** rejected — invalidation complexity, risk of stale-cache lies.

### Decision 9: Hermetic bats tests via AUDIT_TOOL_CENSUS_FILE env override

**Choice:** The auditor checks for `AUDIT_TOOL_CENSUS_FILE` env var. If set, it reads the tool census from the specified JSON file instead of invoking `opencode debug agent`. Bats tests set this env var to pre-recorded JSON files.

**Rationale:** Tests must NOT depend on a live `opencode` install. The env override is a clean seam for stubbing the runtime step.

**Alternatives considered:**

- **Mock `opencode` binary in PATH:** rejected — fragile, platform-dependent.
- **Skip runtime census in tests:** rejected — wouldn't test the cross-reference logic.

## Seams (pre-agreed public boundaries where tests will live)

**Confirmed with developer before any test is written:**

### Seam 1: Runtime census stubbing

**Boundary:** The auditor invokes `opencode debug agent <canonical-agent>` to obtain the tool universe. The bats tests stub this by setting `AUDIT_TOOL_CENSUS_FILE` to a pre-recorded JSON file.

**Contract:**

```bash
# In the auditor script:
if [ -n "${AUDIT_TOOL_CENSUS_FILE:-}" ]; then
  # Read census from file (test mode)
  CENSUS=$(cat "$AUDIT_TOOL_CENSUS_FILE")
else
  # Invoke opencode debug agent (production mode)
  CENSUS=$(opencode debug agent "$CANONICAL_AGENT" 2>/dev/null)
fi
```

**Test usage:**

```bash
# In bats tests:
export AUDIT_TOOL_CENSUS_FILE="$FIXTURE_DIR/census.json"
run scripts/audit-agent-tool-coverage.sh "$FIXTURE_DIR/config.jsonc"
```

### Seam 2: Config file paths

**Boundary:** The auditor takes config file paths as arguments (default: `.opencode/opencode.jsonc`). The bats tests pass synthetic config paths from temp fixture trees.

**Contract:**

```bash
# In the auditor script:
CONFIG_FILE="${1:-.opencode/opencode.jsonc}"
```

**Test usage:**

```bash
# In bats tests:
run scripts/audit-agent-tool-coverage.sh "$FIXTURE_DIR/config.jsonc"
```

### Seam 3: Exit-code contract

**Boundary:** The auditor must exit 0 / 1 / 2 per the specified conditions.

**Contract:**

- Exit 0: run completed, no HARD (write-capable) gaps found (WARNs do not fail).
- Exit 1: HARD (write-capable) gap found (unlisted write-capable tool per Decision 6) OR malformed JSONC.
- Exit 2: INFRA error (no `opencode`, no `python3`, no default model, v2 schema detected, missing config file).

**Test usage:**

```bash
# In bats tests:
run scripts/audit-agent-tool-coverage.sh "$FIXTURE_DIR/config.jsonc"
[ "$status" -eq 0 ]  # or 1 or 2
```

## Risks / Trade-offs

### Risk 1: Runtime census fails in CI (no default model)

**Risk:** The `opencode debug agent` invocation requires a resolvable default model. If the CI environment doesn't have a default model configured, the script exits 2 (INFRA).

**Mitigation:** The exit-2 contract makes this failure visible. The CI environment must configure a default model (via `OPENCODE_CONFIG_CONTENT` or provider env vars) for the audit to run. This is a hard requirement, not a silent failure.

**Trade-off:** The script has a soft dependency on `opencode` being installed and a default model being resolvable. This is acceptable for a CI gate (the CI environment can be configured), but it means the script cannot run in fully hermetic environments without `opencode`.

### Risk 2: v2 schema migration breaks the auditor

**Risk:** When the project migrates to v2 permission schema, the auditor will refuse to run (exit 2).

**Mitigation:** The exit-2 message is clear: "v2 permission schema detected — audit script not yet adapted for last-match-wins semantics." This is honest failure, not silent wrongness. The migration ticket must include updating the auditor.

**Trade-off:** The auditor is v1-only. v2 support is a follow-up ticket. This is acceptable because the project is currently on v1, and v2 migration is a separate effort.

### Risk 3: Blanket-form output is noisy

**Risk:** The container profile's blanket `"permission": "allow"` will produce a `WARN:` line reporting N unlisted tools. This might be noisy if N is large.

**Mitigation:** The `WARN:` line is a single line with the count, not a per-tool flood. The developer can triage the blanket exposure separately from per-tool gaps.

**Trade-off:** The blanket form is a more severe exposure mode than per-tool gaps. The script makes the distinction explicit. This is the correct behavior, even if it's noisy.

### Risk 4: Effective coverage semantics over-reports

**Risk:** A tool covered globally but not per-agent is NOT reported as a gap. If the developer expects per-agent strict coverage, they might think the script is missing gaps.

**Mitigation:** The proposal and design documents explicitly state the effective coverage semantics. The output includes a hint column showing the default disposition, so the developer can see what's covered globally.

**Trade-off:** Effective coverage matches runtime behavior. Per-agent strict coverage would over-report. The choice is deliberate and documented.

## Migration Plan

**Deployment:**

1. Merge the PR with the new script, tests, and Makefile wiring.
2. `make test-config` now includes the auditor.
3. If the auditor finds gaps in the current config, fix them as part of the PR (or create follow-up tickets if they're intentional).

**Rollback:**

1. `git revert <commit>` — removes the script, tests, and Makefile wiring.
2. No application code is touched. No config files are modified.
3. Rollback is a single `git revert`.

## Open Questions

None. All design decisions have been resolved via the interview (Q1–Q7).

## References

- **Source ticket:** `docs/dev-infra-audit/tickets/DIA-066.md`
- **Tool enumeration research:** `knowledge/res003-tool-enumeration/sources/` (res-2 findings)
- **Immediate prior art:** `scripts/validate-agent-names.sh`, `scripts/__tests__/validate-agent-names.bats`
- **OpenSpec change pattern:** `openspec/changes/dev-infra-config-validators/` (same shape)
