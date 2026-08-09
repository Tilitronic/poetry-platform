# Tasks: ai-self-improvement-auditor-and-cleanup

> **Proposal:** `openspec/changes/ai-self-improvement-auditor-and-cleanup/proposal.md`
> **Design:** `openspec/changes/ai-self-improvement-auditor-and-cleanup/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill (for T1/T2 bats slices). T3 is a doc-only slice. Work one slice at a time.
> **Routing split:**
>
> - **T1 (skill cleanup + validator):** AGENTS.md §2.4 (dev-infra shell validators + bats → `@reviewer`, two-axis).
> - **T2 (`@ai-auditor` registration + `@ai-specialist` narrowing):** AGENTS.md §10 (AI-tooling config → ai-specialist gate already DONE; `@coder` implements; `@ai-specialist` Phase-6 independent review; §10 Phase-5 restart+smoke).
> - **T3 (council budget controls in `NEXT-RUN.md`):** AGENTS.md §2.4 (dev-infra docs → `@reviewer`, two-axis).

## Dependency graph

```
T1 (skill cleanup + validator extension + bats)
 │
 │ (validator is the gate that proves agent registration — T2's 4-source
 │  contract is verified by running validate-agent-names.sh, but T1's
 │  dup-detection does not block T2 structurally)
 │
 ├──▶ T2 (@ai-auditor 4-source registration + ai-specialist narrowing)
 │       (depends on T1 only in the sense that the final verification
 │        matrix runs both gates together; T2 can be implemented in
 │        parallel with T1 if the coder lane chooses)
 │
 └──▶ T3 (NEXT-RUN.md §2 council budget rule — independent)
```

**Critical path:** T2 (the largest slice, with §10 Phase-5 restart+smoke as the terminal verification).
**Parallel track:** T1 and T3 are independent and can be implemented in either order or in parallel. T1 and T2 touch disjoint files.
**Rationale for ordering:**

- **T1 is first** in the suggested order because it clears the skill-dupe defect before the 4-source registration runs — the post-T1 `make test-skills` run is the clean baseline the T2 verification matrix depends on.
- **T2 is the integration slice** — 4-source registration + `@ai-specialist` narrowing + §10 Phase-5 restart+smoke. Largest slice, most verification surface, most likely to surface a 4-source drift if a source is missed.
- **T3 is independent** — doc-only change to `NEXT-RUN.md`. No file overlap with T1/T2. Cheapest to implement last as a bookkeeping slice.
- **No blocking edges between T1/T2/T3 that prevent independent verification** (briefing constraint). Each task can be verified in isolation: T1 via `make test-skills` + `make test-shell`; T2 via `make test-config` + standalone `validate-agent-names.sh` + §10 Phase-5 restart+smoke; T3 via visual review of `NEXT-RUN.md` §2.

---

## T1 — Skill cleanup + dup-detection validator + bats

**Blockers:** none
**Vertical slice:** delete the 5 byte-exact duplicate skill directories under `.opencode/skills/` (keeper set: `playwright-browser` + `git-diff`); extend `.opencode/scripts/validate-skills.sh` with the two-tier dup detection; add 6-case bats fixture matrix to `scripts/__tests__/validate-skills.bats`. After T1, running `make test-skills` from the repo root exits 0 on the post-cleanup project config (15 skills, no dup-detection HARD findings), and `make test-shell` passes the pre-existing bats baseline + 6 new dup-detection cases.

### What changes

1. **5 skill-dir deletions under `.opencode/skills/`.** Identify the 5 byte-exact duplicates by running a pre-implementation audit:
   - For each `$d` in `.opencode/skills/*/`, compute `sha256sum $d/SKILL.md`.
   - For each `$g` in `~/.config/opencode/skills/*/` where `basename($g) == basename($d)`, compute `sha256sum $g/SKILL.md`.
   - If the hashes match AND `basename($d)` is NOT `playwright-browser` AND NOT `git-diff` → mark for deletion.
   - Execute the deletions (recoverable via `git revert`).
   - Visual confirmation: `ls .opencode/skills/` shows 15 entries post-deletion.

2. **`.opencode/scripts/validate-skills.sh` (modified, dup-detection section appended).** Behavior per design.md §1:
   - After the existing per-skill frontmatter loop, add a new dup-detection pass.
   - Introduce `GLOBAL_SKILLS_ROOT="${GLOBAL_SKILLS_ROOT:-$HOME/.config/opencode/skills}"`.
   - Missing global dir → exit 2 INFRA (emit `error: global skills directory not found: $GLOBAL_SKILLS_ROOT` to stderr).
   - Empty global dir OR empty project dir → skip dup-detection, fall through to the existing summary.
   - **Tier 1 (byte-exact HARD):** single-pass `sha256sum` over every `SKILL.md` under both `SKILLS_ROOT` and `GLOBAL_SKILLS_ROOT`. Group by hash. For each hash with ≥2 entries where one is project and one is global, emit `FAIL: duplicate skill '<name>' (byte-exact match with global '<global-path>')` to stderr and increment `$failures`.
   - **Tier 2 (near-dupe SOFT):** for each project skill that did NOT match byte-exact, if a same-named skill exists in `GLOBAL_SKILLS_ROOT`, run `diff -r <project-skill-dir> <global-skill-dir>`. If `diff -r` reports any differences, emit `warn: near-duplicate skill '<name>' (differs from global '<global-path>')` to stderr and increment `$warnings`. Does NOT flip the exit code.
   - Fold dup-detection counters into the existing `$passed/$failures/$warnings` accumulators (Q6 ruling — single summary line).
   - Script-header docs: add a comment block documenting the case-sensitive exact + follow-symlinks policy as a human contract.

3. **`scripts/__tests__/validate-skills.bats` (modified, 6 new `@test` blocks appended).** Fixture matrix per proposal §Testing Decisions:
   1. Valid: no duplicates between project and global skills dirs → exit 0.
   2. Byte-exact duplicate (same SKILL.md content, same hash) → exit 1 with `FAIL: duplicate skill ...` line on stderr.
   3. Near-duplicate (different whitespace / minor comment drift) → exit 0 with `warn: near-duplicate skill ...` line on stderr.
   4. Empty project skills dir → exit 0.
   5. Missing global skills dir (`GLOBAL_SKILLS_ROOT` points at nonexistent path) → exit 2 (INFRA).
   6. Multiple duplicates in one run (collect-all discipline) → exit 1, one `FAIL:` line per duplicate.
      Each test sets `SKILLS_ROOT` and `GLOBAL_SKILLS_ROOT` explicitly via `$BATS_TEST_TMPDIR` fixture trees. Uses `assert_status`, `assert_output_contains` from `test-helper.bash`.

> **Errata (2026-08-06):** factual correction to the T1 scope/acceptance expectations above — **not a rule change**. The pre-deletion audit (DIA-052) found only **3 of 5** deletion candidates were byte-exact duplicates: `mermaid-diagramming`, `console-charting`, and `teaching` were deleted (20 → 17). `book-rag` and `debugging-workflow` differ from their global counterparts (project-local fixes) and were **retained** as near-duplicates per the HARD/SOFT partition (SOFT warn, no deletion). Acceptance/verification expectations in this task that hard-code **"5 deletions"**, **"15 entries"**, or **"15 passed"** (What-changes step 1, Acceptance criteria, Verification procedure steps 1–2, Summary of file changes) are superseded: actual counts are **3 deletions** and **17 entries / 17 passed**.

### Acceptance criteria (user perspective)

- `ls .opencode/skills/` shows 15 entries post-T1 (the 14 non-duplicate originals + `playwright-browser` + `git-diff` — net: 15 after 5 deletions from the pre-change 20).
- Keeper skills (`playwright-browser`, `git-diff`) are byte-identical to pre-T1 (`git diff HEAD@{1} -- .opencode/skills/playwright-browser/ .opencode/skills/git-diff/` is empty).
- `make test-skills` from repo root exits 0 on the post-cleanup project config.
- `bash .opencode/scripts/validate-skills.sh` from repo root prints `ok:` lines per surviving skill and a final `N passed, 0 failed, 0 warnings` summary (where N = 15).
- `make test-shell` exits 0 with the pre-existing bats baseline + the 6 new dup-detection cases passing.
- `bash -n .opencode/scripts/validate-skills.sh` exits 0 (via `bats-wrapper.sh`).
- The byte-exact dup fixture → exit 1 with `FAIL:` naming the duplicate pair.
- The near-dupe fixture → exit 0 with `warn:` naming the near-dupe pair.
- The missing-global-dir fixture → exit 2 (INFRA).
- The multiple-duplicates fixture → exit 1 with one `FAIL:` line per duplicate (collect-all discipline verified).

### Verification procedure

1. `ls .opencode/skills/ | wc -l` — returns `15`.
2. `bash .opencode/scripts/validate-skills.sh` — exit 0, `15 passed, 0 failed, 0 warnings` on the real post-cleanup config.
3. `make test-skills` — exit 0.
4. `make test-shell` — all bats tests pass (pre-existing baseline + 6 new cases).
5. `bash -n .opencode/scripts/validate-skills.sh` — exit 0.

### Testing

- RED-GREEN: write the 6 bats tests first (they fail because the dup-detection logic does not yet exist in `validate-skills.sh`), then implement the dup-detection section until they pass.
- The 6 fixture tests cover all exit-code paths (0 / 1 / 2), the HARD/SOFT partition, the collect-all discipline, and the `GLOBAL_SKILLS_ROOT` env seam.
- bats uses env overrides (`SKILLS_ROOT` + `GLOBAL_SKILLS_ROOT`) to isolate fixture trees — real project + real global skills dir never mutated.

---

## T2 — `@ai-auditor` 4-source registration + `@ai-specialist` narrowing

**Blockers:** T1 (the `make test-skills` clean baseline is a precondition for the final verification matrix; T2 does not functionally depend on T1's output)
**Vertical slice:** register `@ai-auditor` in all 4 agent-name sources (AGENTS.md §9, `opencode.jsonc`, `oh-my-opencode-slim.jsonc`, `.opencode/agents/ai-auditor.md`) + narrow `@ai-specialist` description. After T2, running `scripts/validate-agent-names.sh` from the repo root reports `22 passed, 0 failed, 0 warnings` (was 21 pre-T2), and the §10 Phase-5 restart+smoke confirms `@ai-auditor` is dispatchable with read-only enforcement.

### What changes

1. **`AGENTS.md` §9 (modified, one row added).** Insert a new row into the §9 agent naming table:
   - Display name: `@ai-auditor`
   - Internal name: `ai-auditor`
   - Lane: `AI-tooling audit (read-only)`

   Placement: alphabetical by internal name (between `ai-specialist` and `analyzer`, per the existing table layout).

2. **`.opencode/opencode.jsonc` (modified, two changes):**
   - **Add `ai-auditor` agent block** under `agent`:
     ```jsonc
     "ai-auditor": {
       "description": "Read-only auditor for AI-tooling config changes. Independent Phase-6 reviewer under AGENTS.md §10.",
       "mode": "subagent",
       "model": "opencode-go/qwen3.7-plus",
       "temperature": 0.2,
       "color": "info",
       "permission": {
         "edit": "deny",
         "bash": {
           "curl": "allow",
           "wget": "allow",
           "*": "deny"
         },
         "task": "deny"
       }
     }
     ```
   - **Narrow `ai-specialist` `description` field** from:
     `"Researches agent/skill/config best practices for OpenCode itself. Read-only — findings routed through orchestrator for persistence."`
     to:
     `"Read-only researcher of agent/skill/config best practices for OpenCode itself. Findings routed through orchestrator for persistence. Scope: documentation + config review only; no runtime dispatch authority; no implementation."`
     No other fields in the `ai-specialist` block are touched.

3. **`.opencode/oh-my-opencode-slim.jsonc` (modified):** add `ai-auditor` to the top-level `agents` block (model/variant/skills/mcps shape mirroring existing `ai-specialist` presets), AND to each of the 3 preset slots that currently carry `ai-specialist`. Exact model allocation per preset is the coder lane's decision based on the existing `ai-specialist` preset entries.

4. **`.opencode/agents/ai-auditor.md` (new file).** Frontmatter:
   ```yaml
   ---
   description: Read-only auditor for AI-tooling config changes. Independent Phase-6 reviewer under AGENTS.md §10.
   mode: subagent
   ---
   ```
   Body: short mandate description (the auditor's read-only scope). Mirrors `memory-manager.md` frontmatter shape (description + mode only; permissions live in `opencode.jsonc`).

### Acceptance criteria (user perspective)

- `scripts/validate-agent-names.sh` from repo root exits 0 with `22 passed, 0 failed, 0 warnings` (was 21 pre-T2; the new `ai-auditor` is the 22nd name resolved across the 4 sources).
- `make test-config` from repo root exits 0 (all config validators green).
- `ls .opencode/agents/` shows both `memory-manager.md` and `ai-auditor.md`.
- §10 Phase-5 restart+smoke:
  - OpenCode is restarted after T2 lands (config changes require restart to take effect).
  - `@ai-auditor` is dispatchable on a minimal test task (e.g., "list the agents registered in AGENTS.md §9").
  - The read-only `permission` block in `opencode.jsonc` is enforced: an attempt to edit a file via `@ai-auditor` fails at the permission layer; bash commands outside the narrow allowlist (`curl`/`wget`) fail at the permission layer.
- `grep -c '"ai-auditor"' .opencode/opencode.jsonc` returns ≥1.
- `grep -c '"ai-auditor"' .opencode/oh-my-opencode-slim.jsonc` returns ≥4 (one in `agents` block + 3 preset slots).
- `grep -c '^|.*ai-auditor.*|' AGENTS.md` returns 1 (the new §9 row).

### Verification procedure

1. `bash scripts/validate-agent-names.sh` — exit 0, `22 passed, 0 failed, 0 warnings`.
2. `make test-config` — exit 0.
3. `ls .opencode/agents/` — shows `memory-manager.md` and `ai-auditor.md`.
4. **§10 Phase-5 restart+smoke (manual):**
   - Restart OpenCode.
   - Dispatch `@ai-auditor` on a minimal test task.
   - Verify dispatch succeeds; verify the read-only `permission` block is enforced (attempt to edit fails; out-of-allowlist bash fails).
   - Document the result in the coder's handoff.
5. `grep -c '"ai-auditor"' .opencode/opencode.jsonc` — ≥1.
6. `grep -c '"ai-auditor"' .opencode/oh-my-opencode-slim.jsonc` — ≥4.
7. `grep -c '^|.*ai-auditor.*|' AGENTS.md` — 1.

### Testing

- The structural 4-source registration is verified mechanically by `scripts/validate-agent-names.sh` real-config run (post-T2 must report 22 passed).
- The runtime dispatchability + read-only enforcement is verified by §10 Phase-5 restart+smoke (manual — no bats substitute exists for runtime OpenCode behaviour).
- No RED-GREEN cycle for this slice (the bats surface is confined to T1's validator extension; T2 is a config-only change verified by the pre-existing 4-source validator).

---

## T3 — Council budget controls in `NEXT-RUN.md` §2

**Blockers:** none (independent of T1/T2)
**Vertical slice:** add a new bullet to `docs/dev-infra-audit/NEXT-RUN.md` §2 (Orchestrator Operating Rules) capturing the council budget rule + thresholds (warn 75% / 1125, hard-stop 90% / 1350, base 1500). Non-code deliverable; no automated test.

### What changes

1. **`docs/dev-infra-audit/NEXT-RUN.md` (modified, §2 insertion).** Insert a new bullet after the existing `CRISIS-DETECTION` bullet and before `PROGNOSIS-DISCIPLINE`. Exact text per design.md §4:

   > **COUNCIL-BUDGET-GUARD**: the orchestrator MUST monitor cumulative council-dispatch credit spend against a 1500-credit session budget. **Warn** at 75% (1125 credits): emit a visible notice to the developer with the current spend + remaining budget; continue dispatching. **Hard-stop** at 90% (1350 credits): cease all council dispatches for the remainder of the session; notify the developer; hand off remaining council-needs to the next session via the HANDOFF.md prognosis. Detection: `token_stats` + the council-dispatch subset of the spend; credit cost per councillor dispatch is model-dependent (use the live `token_stats` cost field, not a static lookup).

### Acceptance criteria (user perspective)

- The `COUNCIL-BUDGET-GUARD` bullet is present in `NEXT-RUN.md` §2.
- The text mentions the 1500-credit base budget.
- The text mentions the 75% warn threshold (1125 credits).
- The text mentions the 90% hard-stop threshold (1350 credits).
- The detection mechanism references `token_stats`.
- The surrounding §2 bullets (CRISIS-DETECTION before, PROGNOSIS-DISCIPLINE after) are intact and well-formed.

### Verification procedure

1. `cat docs/dev-infra-audit/NEXT-RUN.md` — visual check: new bullet present, well-formed, insertion point correct.
2. `grep -c 'COUNCIL-BUDGET-GUARD' docs/dev-infra-audit/NEXT-RUN.md` — returns `1`.
3. `grep -c '1500' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥1.
4. `grep -c '1125' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥1.
5. `grep -c '1350' docs/dev-infra-audit/NEXT-RUN.md` — returns ≥1.

### Testing

No automated test. This is a docs addition; verification is visual review + grep.

---

## Summary of file changes

| File                                                              | Action | Task |
| ----------------------------------------------------------------- | ------ | ---- |
| `.opencode/skills/<dupe-1>/` through `.opencode/skills/<dupe-5>/` | delete | T1   |
| `.opencode/scripts/validate-skills.sh`                            | modify | T1   |
| `scripts/__tests__/validate-skills.bats`                          | modify | T1   |
| `.opencode/agents/ai-auditor.md`                                  | create | T2   |
| `.opencode/opencode.jsonc`                                        | modify | T2   |
| `.opencode/oh-my-opencode-slim.jsonc`                             | modify | T2   |
| `AGENTS.md` (§9 table)                                            | modify | T2   |
| `docs/dev-infra-audit/NEXT-RUN.md` (§2)                           | modify | T3   |

## Implementation order (suggested)

1. **T1** (skill cleanup + validator + bats) — the largest vertical slice with RED-GREEN bats cycle. ~45 min.
2. **T2** (`@ai-auditor` registration + `@ai-specialist` narrowing) — config-only, but with §10 Phase-5 restart+smoke as the terminal verification. ~30 min + restart+smoke time.
3. **T3** (NEXT-RUN.md §2 council budget rule) — docs-only, cheapest slice. ~5 min.
4. **Final PR verification:** run `make test-config` + `make test-skills` + `make test-shell` end-to-end; run §10 Phase-5 restart+smoke. Expect:
   - `make test-skills` exit 0, 15 passed.
   - `make test-shell` exit 0, pre-existing baseline + 6 new T1 cases.
   - `make test-config` exit 0, `validate-agent-names.sh` reports 22 passed.
   - §10 Phase-5 smoke: `@ai-auditor` dispatchable + read-only enforced.

## Out of scope for these tasks

- CLASH integration (original Phase 1 — dropped per interview Q1).
- Modifications to the global skills directory (`~/.config/opencode/skills/`).
- Merging the keeper skills into the global dir.
- Changes to `dcp.jsonc`.
- Filing a DIA-051 tracking ticket.
- Global opencode config (`~/.config/opencode/opencode.jsonc`) validation.
- OMO JSONC schema validation (known gap, future work — interview Q7).
- `.sdd/` module doc authoring.
- Any change beyond the 3 tasks listed.

## Verification gate summary

| Gate                                                     | When     | Required                                                                                                                                                |
| -------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make test-skills`                                       | After T1 | Exit 0 on the real post-cleanup project config (15 skills, no dup-detection HARD findings).                                                             |
| `make test-shell`                                        | After T1 | Pre-existing bats baseline + 6 new dup-detection cases pass.                                                                                            |
| `bash .opencode/scripts/validate-skills.sh` (standalone) | After T1 | Exit 0, `15 passed, 0 failed, 0 warnings`.                                                                                                              |
| `scripts/validate-agent-names.sh` (standalone)           | After T2 | `22 passed, 0 failed, 0 warnings` on real project config (was 21 pre-T2).                                                                               |
| `make test-config`                                       | After T2 | All config validators green.                                                                                                                            |
| §10 Phase-5 restart+smoke                                | After T2 | OpenCode restarted; `@ai-auditor` dispatchable on a minimal test task; read-only `permission` block enforced (edit fails; out-of-allowlist bash fails). |
| Visual review: `NEXT-RUN.md` §2                          | After T3 | `COUNCIL-BUDGET-GUARD` bullet present with 1500/1125/1350 thresholds and `token_stats` detection reference.                                             |
| Visual review: 5 skill-dir deletions                     | After T1 | `ls .opencode/skills/` shows 15 entries; keeper skills byte-identical to pre-change.                                                                    |

## Coder handoff contract

Per AGENTS.md §2.3 and §2.3.1, the coder's handoff to `@reviewer` (for T1/T3) and to the orchestrator (for T2 §10 chain) must include verification evidence (exit codes + summary lines) for each task. For this change specifically:

- **T1 handoff:** `make test-skills` exit code + summary line (expected `15 passed, 0 failed, 0 warnings`); `make test-shell` exit code + summary line (pre-existing baseline + 6 new cases); `bash -n .opencode/scripts/validate-skills.sh` exit code.
- **T2 handoff:** `scripts/validate-agent-names.sh` exit code + summary output (expected `22 passed, 0 failed, 0 warnings`); `make test-config` exit code; §10 Phase-5 restart+smoke result (dispatch outcome + permission enforcement evidence).
- **T3 handoff:** `grep -c 'COUNCIL-BUDGET-GUARD' docs/dev-infra-audit/NEXT-RUN.md` output (expected `1`); visual confirmation of the surrounding bullet order.
