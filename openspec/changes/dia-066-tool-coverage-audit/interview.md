# Interview Transcript: dia-066-tool-coverage-audit

> **Date:** 2026-08-08
> **Interviewer:** @openspec-plan
> **Mode:** Full
> **Source ticket:** DIA-066 (tool-coverage audit script — surface unlisted default-allow tools)

## Phase 0 — Depth Mode

**Recommendation:** Full mode
**Rationale:** Single-module script tool with novel design decisions and non-trivial external dependency (opencode debug agent). ~5 open design forks warrant Socratic grilling.
**Developer choice:** Full mode ✓

## Phase 1 — Context Scan (silent)

Key findings:

- `.sdd/` has no module doc for scripts surface or permission model — same precedent as `dev-infra-config-validators`
- Closest prior art: `scripts/validate-agent-names.sh` (3-tier exit codes, HARD/SOFT, collect-all-never-fail-fast)
- Test infra: bats for shell scripts, `scripts/__tests__/test-helper.bash`
- Res-2 research findings authoritative on tool enumeration mechanisms

## Phase 2 — Structured Interview

### Q1 — Scope: Runtime vs Static Tool Enumeration

Presented three options:

- **Option A (Pure runtime):** `opencode debug agent <name>` per agent. Pros: ground truth. Cons: N× cold-start cost, no file:line output, requires default model per invocation.
- **Option B (Pure static):** JSONC parse only. Pros: hermetic. Cons: cannot see plugin/MCP tools — defeats DIA-066's purpose.
- **Option C (Hybrid):** One runtime census (first alphabetical agent) + static JSONC parse. Pros: bounded cost + source locations + plugin/MCP coverage.

**Recommendation:** Option C
**Developer answer:** Option C ✓

**Follow-on Q1.1 — Default-model fallback:**

- (a) Exit 2 INFRA (recommended) — "can't run check" ≠ "check found gaps"
- (b) Degraded static mode — would silently lie about plugin tools

**Developer answer:** (a) Exit 2 INFRA ✓

**Follow-on Q1.2 — Canonical agent for census:**

- First alphabetical (recommended) — deterministic
- Named: orchestrator — hardcodes a name that could be renamed away

**Developer answer:** First alphabetical ✓

### Q2 — Boundary Conditions

**Q2.1 — Container profile's blanket `"permission": "allow"`**

- First-class WARN (recommended) — separate exposure mode
- Treat as all-tools gap — false flood
- Skip with warning — silent about exposure

**Developer answer:** First-class WARN ✓

**Q2.2 — v1 vs v2 schema**

- Assert v1, exit 2 on v2 (recommended) — ship v1-only now
- Detect and adapt — materially different script
- Assume v1, don't check — silent wrongness

**Developer answer:** Assert v1, exit 2 on v2 ✓

**Q2.3 — Merge semantics**

- Effective coverage (agent ∪ global) (recommended) — matches runtime
- Per-agent strict — over-reports
- Global-only — misses per-agent overrides

**Developer answer:** Effective coverage ✓

**Q2.4 — Default-ask/deny exceptions**

- Hint column only, only default-allow is HARD (recommended)
- Report all uncovered as gaps — noisy
- Hardcode skip — no visibility

**Developer answer:** Hint column only ✓

**Q2.5 — No config file**

- Exit 2 INFRA (recommended) — matches validate-agent-names.sh precedent
- Exit 0, no gaps — masks missing-config condition

**Developer answer:** Exit 2 INFRA ✓

### Q3 — Performance: Caching

- No caching (recommended) — fresh run every invocation, 3-8s acceptable
- mtime-based cache — invalidation complexity, risk of stale-cache lies

**Developer answer:** No caching ✓

### Q4 — Integration

**Q4.1 — Script name**

- audit-agent-tool-coverage.sh (recommended)
- validate-tool-coverage.sh — implies schema validation

**Developer answer:** audit-agent-tool-coverage.sh ✓

**Q4.2 — Makefile target**

- Add to test-config (recommended) — config integrity check
- New test-coverage target — isolates runtime dependency

**Developer answer:** Add to test-config ✓

**Q4.4 — Container profile**

- Separate pass per profile (recommended)
- Main config only — misses container profile exposure

**Developer answer:** Separate pass per profile ✓

### Q5 — Error States

- All as recommended: opencode missing → exit 2, python3 missing → exit 2, malformed JSONC → exit 1 (HARD)

**Developer answer:** All as recommended ✓

### Q6 — Output Format

- Proposed format (recommended): FAIL:/WARN:/ok: lines, file:line, final summary
- Human + JSON dual — more CI-friendly but more code
- Tabular matrix — dense but harder to parse

**Developer answer:** Proposed format ✓

### Q7 — Acceptance Criteria

10 criteria proposed:

1. Exits 0 against current config after DIA-055 fixes
2. Per-gap output: file:line agent=... tool=... default=allow on stderr
3. Negative bats test: removing deny rule triggers exit 1
4. Blanket-form container profile produces WARN + unlisted-tools count
5. v2 schema rejection: exit 2 with clear message
6. Effective coverage: globally-covered tool not a per-agent gap
7. Default-ask/deny tools are SOFT (hint column, no exit-code flip)
8. Hermetic bats tests via AUDIT_TOOL_CENSUS_FILE env override
9. Exit-code contract: 0 / 1 / 2 as specified
10. Makefile: test-config invokes for both main config and container profile

**Developer answer:** Accept as proposed ✓

## Phase 3 — Interview Summary (Confirmed)

All rulings locked. Developer confirmed the summary as accurate and authorized artifact synthesis.

---

## Addendum — 2026-08-08 (Post-Interview Owner Ruling)

**Owner ruling: Option 1 — Scoped HARD gaps (write-capable subset).**

**Context:** During implementation attempts on 2026-08-08, the coder lane discovered that naive application of "all default-allow unlisted tools = HARD gap" produces **~440 HARD gaps** against the current config. This would break `make test-config` (T6 invariant) permanently — a spec contradiction between T4 (exit 1 on HARD gaps) and T6 (test-config must exit 0 on current config).

**Ruling:** HARD gaps are scoped to **write-capable tools only** — tools whose documented primary purpose is to produce persistent state changes (file mutations, shell execution, network writes, or transitive dispatch to write-capable subagents). All other unlisted default-allow tools become WARN (exit 0).

**Canonical write-capable list** (hardcoded in script, overrideable via `AUDIT_WRITE_CAPABLE_TOOLS`):

- File mutation: `write`, `edit`, `ast_grep_replace`
- Shell execution: `bash`
- Network + disk write: `webfetch` (via `save_binary` parameter)
- Transitive dispatch: `task`
- Dotenv mutation (envsitter): `envsitter_set`, `envsitter_delete`, `envsitter_format`, `envsitter_reorder`, `envsitter_unset`, `envsitter_add`, `envsitter_copy`

**Motivation:** ~440-gap discovery proved the unscoped HARD interpretation was operationally non-viable — it would permanently break CI while providing no additional safety signal (the 13 write-capable tools are the actual exposure surface). The scoped interpretation preserves DIA-066's core purpose (surfacing write-capable exposure before it ships) while resolving the T4/T6 contradiction.

**Artifacts updated:** design.md Decision 6 (new), Decision 2 (exit-code contract), Seam 3; tasks.md T4 (severity tiering + WARN-only test 11b), T6 (invariant documented); proposal.md Testing Decisions #2, Success criteria #1.
