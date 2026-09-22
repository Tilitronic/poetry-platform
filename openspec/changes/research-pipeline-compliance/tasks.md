# Tasks: research-pipeline-compliance

> **Proposal:** `openspec/changes/research-pipeline-compliance/proposal.md`
> **Design:** `openspec/changes/research-pipeline-compliance/design.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-260820-dr0g.md` (researcher agent deviates from 3-tier fetch chain).
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md section 2.4 (dev-infra within existing boundaries -> `@reviewer`, two-axis: Standards + Spec fidelity). No section 10 AI-tooling routing - validator does not modify opencode config; it only READS research artifacts.

## Dependency graph

```
T1 (validator script + bats tests)
 |
 | (T2 can proceed in parallel - disjoint files)
 |
 ├──▶ T2 (skill prompt update)
```

**Critical path:** T1 -> T2 (T2 references the validator script in the skill prompt, so T1 should land first for consistency, though T2 does not functionally depend on T1's output).
**Parallel track:** T1 and T2 are independent and can be implemented in either order or in parallel. T1 is the larger slice (validator + 7-case bats matrix); T2 is a skill prompt update (visual review, no automated test).
**Rationale for ordering:**

- **T1 is first** because it is the core enforcement mechanism (validator script + bats tests). The skill prompt update in T2 references the validator, so T1 landing first makes the reference concrete.
- **T2 is second** because it is a skill prompt update (additive, no tests). It can be implemented in parallel with T1 if the coder lane prefers, but the reference to `scripts/validate-research-pipeline.sh` in the skill prompt is clearer once the script exists.
- **No blocking edges between T1/T2 that prevent independent verification.** Each task can be verified in isolation: T1 runs standalone via `bash scripts/validate-research-pipeline.sh knowledge/res<id>-<topic>/`; T2 is a visual review of the skill prompt.

---

## T1 - `scripts/validate-research-pipeline.sh` + `scripts/__tests__/validate-research-pipeline.bats`

**Blockers:** none
**Vertical slice:** the research pipeline compliance validator (sources/ + manifest validation) + its 7-case bats fixture matrix. After T1, running `bash scripts/validate-research-pipeline.sh knowledge/res008-source-archival-fallbacks/` from the repo root produces exit 0 (the real research conspect has sources/ + manifest present, well-formed, all claimed sources have archival evidence or are marked NOT ARCHIVED with reason).

### What changes

1. **`scripts/validate-research-pipeline.sh`** (new file, executable, `set -euo pipefail`). Behavior per design.md "Implementation approach":
   - Takes one positional argument: res directory path (e.g., `knowledge/res008-source-archival-fallbacks/`).
   - Input validation:
     - Check first positional argument is provided. If not, exit 2 with "usage: validate-research-pipeline.sh <res-directory>".
     - Check res directory exists. If not found, exit 1 with "FAIL: res directory not found: <path>".
     - Check `command -v jq` (already validated by `check-host-jq.sh`). If not found, exit 2 with "unsupported: jq not found".
   - Sources directory validation:
     - Check `sources/` subdirectory exists. If not found, exit 1 with "FAIL: missing sources/ directory".
     - Check `sources/` is non-empty (at least one file). If empty, exit 1 with "FAIL: sources/ directory is empty".
   - Manifest validation:
     - Check `.source-urls.txt` manifest exists in res directory. If not found, exit 1 with "FAIL: missing .source-urls.txt manifest".
     - Parse manifest (pipe-delimited format: `URL | tool | archived-path-or-NOT-ARCHIVED | relevance/reliability`).
     - For each line:
       - Extract URL, tool, archived-path-or-NOT-ARCHIVED, relevance/reliability.
       - If archived-path-or-NOT-ARCHIVED is `[source not archived]`, check reason is provided (4th field non-empty).
       - Otherwise, check archived file exists in `sources/` directory.
       - If file does not exist and not marked NOT ARCHIVED, exit 1 with "FAIL: URL <url> has no corresponding archive".
     - If all lines pass, continue.
   - Summary:
     - Count total URLs, archived URLs, NOT ARCHIVED URLs, deviations.
     - Exit 0 with "ok: N URLs validated (M archived, K not archived, J deviations recorded)".
   - Exit code contract per design.md Decision 2:
     - Exit 0 = valid evidence (sources/ + manifest present, well-formed, all claimed sources have archival evidence or are marked NOT ARCHIVED with reason).
     - Exit 1 = missing/malformed manifest or archive (including missing res directory, missing sources/, missing manifest, manifest lists URLs with no corresponding archives and no NOT ARCHIVED marker).
     - Exit 2 = validator infrastructure failure (I/O/parser/dependency - manifest not readable, jq not available, etc.).
   - Stream contract per design.md "Stream contract":
     - stderr: `FAIL: <message>` lines for HARD failures (exit 1) or INFRA errors (exit 2).
     - stdout: `ok: <message>` lines for passes; final summary line on exit 0.
     - Fail-fast: YES (unlike other validators that collect-all). Rationale: manifest parsing is sequential; early failures make later steps meaningless.
   - `RESEARCH_DIR` env override for bats meta-tests (points at fixture tree). Same shape as `AGENTS_ROOT` in `validate-agent-names.sh`.

2. **`scripts/__tests__/validate-research-pipeline.bats`** (new file). 7-case fixture matrix per proposal section "Testing Decisions":
   1. Valid: sources/ + manifest present, all URLs archived -> exit 0. stdout `ok:` lines, final summary.
   2. Valid with deviation: manifest records fallback (e.g., "webfetch because trafilatura denied") -> exit 0. stdout `ok:` lines including deviation.
   3. Valid with NOT ARCHIVED: manifest marks URL as `[source not archived]` with reason -> exit 0. stdout `ok:` lines including NOT ARCHIVED marker.
   4. Missing sources/ directory -> exit 1. stderr `FAIL:` line "missing sources/ directory".
   5. Missing manifest (.source-urls.txt) -> exit 1. stderr `FAIL:` line "missing .source-urls.txt manifest".
   6. Manifest lists URL with no corresponding archive and no NOT ARCHIVED marker -> exit 1. stderr `FAIL:` line naming the URL.
   7. res directory not found (evidence failure, not infra) -> exit 1. stderr `FAIL:` line "res directory not found".
      Each test uses `RESEARCH_DIR` env override to point the validator at a temp fixture tree under `$BATS_TEST_TMPDIR`. Uses `assert_status`, `assert_output_contains` from `test-helper.bash`.

3. **(Conditional) `scripts/__tests__/test-helper.bash` extensions.** If the existing assertion vocabulary is insufficient for the fixture predicates, add helpers. Decision for the coder lane - the existing `assert_file_contains` (substring-only via `grep -qF`) is likely sufficient for the strict-literal-match predicates.

### Acceptance criteria (user perspective)

- `bash scripts/validate-research-pipeline.sh knowledge/res008-source-archival-fallbacks/` from repo root exits 0 (the real research conspect has sources/ + manifest present, well-formed, all claimed sources have archival evidence or are marked NOT ARCHIVED with reason).
- `bash scripts/validate-research-pipeline.sh knowledge/res008-source-archival-fallbacks/` from repo root prints `ok:` lines to stdout, one per validated URL, plus final summary line.
- A fixture with missing sources/ directory -> exit 1 with `FAIL: missing sources/ directory` to stderr.
- A fixture with missing manifest -> exit 1 with `FAIL: missing .source-urls.txt manifest` to stderr.
- A fixture with a URL that has no corresponding archive and no NOT ARCHIVED marker -> exit 1 with `FAIL: URL <url> has no corresponding archive` to stderr.
- A fixture with a missing res directory -> exit 1 with `FAIL: res directory not found: <path>` to stderr.
- All 7 bats fixture tests pass under `make test-shell`.
- The script passes `bash -n` syntax check (verified by `bats-wrapper.sh`).

### Verification procedure

1. `bash scripts/validate-research-pipeline.sh knowledge/res008-source-archival-fallbacks/` - exit 0 expected.
2. `make test-shell` - all bats tests pass (pre-existing baseline + 7 new cases).
3. `bash -n scripts/validate-research-pipeline.sh` - exit 0.

### Testing

- RED-GREEN: write the 7 bats tests first (they fail because the validator script does not yet exist), then implement the validator until they pass.
- The 7 fixture tests cover all exit-code paths (0 / 1 / 2), the fail-fast discipline, and the structural invariants (sources/ exists, manifest exists, manifest is well-formed, every URL has archival evidence or NOT ARCHIVED marker).
- bats uses env override (`RESEARCH_DIR`) to isolate fixture trees - real research conspects never mutated.

---

## T2 - `.opencode/skills/research-pipeline/SKILL.md` update

**Blockers:** T1 (trivial - T1 just needs to land first for the reference to be concrete; T2 does not functionally depend on T1's output).
**Vertical slice:** update the research-pipeline skill prompt to add a "Deviation Recording" section with examples of correct vs incorrect manifest entries, warning against using WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND the deviation is recorded, and updating Phase 2 verification to reference the new validator script. After T2, the skill prompt documents the deviation recording requirements and the orchestrator's Phase 2 compliance gate.

### What changes

1. **`.opencode/skills/research-pipeline/SKILL.md`** (modified). Add new section after "Phase 2 verification (HARD GATE)" (lines 34-40):

   ```markdown
   ### Deviation Recording

   If you cannot use the 3-tier chain (e.g., sandbox denies curl/trafilatura), you MUST record the deviation in `.source-urls.txt` with the reason and the alternative tool used.

   **Manifest format (pipe-delimited):**
   ```

   URL | tool | archived-path-or-NOT-ARCHIVED | relevance/reliability

   ```

   **Examples:**

   ```

   # Correct manifest entry (3-tier chain followed):

   https://example.com | trafilatura | sources/example.md | High/High

   # Correct manifest entry (deviation recorded):

   https://example.com | webfetch (trafilatura denied by sandbox) | sources/example.md | High/High

   # Correct manifest entry (source not archived):

   https://example.com | trafilatura+curl+crwl all failed | [source not archived] | High/High

   # INCORRECT (missing archival evidence):

   https://example.com | trafilatura | High/High

   ```

   **WARNING:** DO NOT use WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND you record the deviation in `.source-urls.txt`. The orchestrator will reject your return if archival evidence is missing.

   **Phase 2 compliance validator:** The orchestrator runs `scripts/validate-research-pipeline.sh knowledge/res<id>-<topic>/` after you return. If the validator exits 1, your return is rejected and you are re-dispatched with explicit instructions. If the validator exits 2, the orchestrator halts and escalates to the developer.
   ```

   The exact placement and wording are a coder-lane detail per design.md "Skill prompt update". The coder's handoff must document the final placement and confirm the section includes:
   - Manifest format (pipe-delimited with 4 fields)
   - Examples of correct vs incorrect manifest entries
   - Warning against tool bypass without deviation recording
   - Reference to the validator script and exit code contract

### Acceptance criteria (user perspective)

- The skill prompt includes a "Deviation Recording" section after "Phase 2 verification (HARD GATE)".
- The section documents the manifest format (pipe-delimited with 4 fields: URL, tool, archived-path-or-NOT-ARCHIVED, relevance/reliability).
- The section includes examples of correct manifest entries (3-tier chain followed, deviation recorded, source not archived).
- The section includes an example of an incorrect manifest entry (missing archival evidence).
- The section includes a warning against using WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND the deviation is recorded.
- The section references the validator script (`scripts/validate-research-pipeline.sh`) and documents the exit code contract (exit 1 -> reject + re-dispatch; exit 2 -> halt + escalate).

### Verification procedure

1. `cat .opencode/skills/research-pipeline/SKILL.md` - visual check: "Deviation Recording" section present after "Phase 2 verification (HARD GATE)".
2. `grep -c 'Deviation Recording' .opencode/skills/research-pipeline/SKILL.md` - returns 1.
3. `grep -c 'validate-research-pipeline.sh' .opencode/skills/research-pipeline/SKILL.md` - returns >=1.
4. `grep -c 'WebFetch/context7/gh_grep' .opencode/skills/research-pipeline/SKILL.md` - returns >=1 (the warning).

### Testing

No automated test. This is a skill prompt update, not code. Verification is visual review.

---

## Summary of file changes

| File                                                           | Action | Task                       |
| -------------------------------------------------------------- | ------ | -------------------------- |
| `scripts/validate-research-pipeline.sh`                        | create | T1                         |
| `scripts/__tests__/validate-research-pipeline.bats`            | create | T1                         |
| `scripts/__tests__/test-helper.bash`                           | modify | T1 (conditional)           |
| `.opencode/skills/research-pipeline/SKILL.md`                  | modify | T2                         |
| `openspec/changes/research-pipeline-compliance/.openspec.yaml` | create | T0 (pre-existing scaffold) |
| `openspec/changes/research-pipeline-compliance/proposal.md`    | create | T0 (pre-existing scaffold) |
| `openspec/changes/research-pipeline-compliance/design.md`      | create | T0 (pre-existing scaffold) |
| `openspec/changes/research-pipeline-compliance/tasks.md`       | create | T0 (pre-existing scaffold) |

## Implementation order (suggested)

1. **T1** (validator script + bats tests) - the core enforcement mechanism. Write the 7 bats tests RED first, then implement the validator GREEN. ~45 min.
2. **T2** (skill prompt update) - additive, no tests. Visual review. ~15 min.
3. **Final PR verification:** run `make test-shell` end-to-end; expect pre-existing baseline + 7 new bats tests pass.

## Out of scope for these tasks

- Makefile wiring (validator is invoked by orchestrator during live dispatch, not CI gate) - OUT of scope (Q10 ruling).
- Tool-provenance ban (no telemetry on which tool was used) - OUT of scope (Q7 ruling).
- Conspecter enforcement (conspecter already has Archive-Before-Claim policy; this change reinforces it via skill prompt, not validator) - OUT of scope.
- Relevance/reliability validation (subjective; out of scope).
- `.sdd/` module doc authoring - OUT of scope (precedent allows).
- Any change beyond the 2 tasks listed.

## Verification gate summary

| Gate                                                                                 | When     | Required                                                                               |
| ------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------- |
| `make test-shell`                                                                    | After T1 | Pre-existing bats baseline + new `validate-research-pipeline.bats` (7 cases) pass      |
| `bash scripts/validate-research-pipeline.sh knowledge/res<id>-<topic>/` (standalone) | After T1 | Exit 0 on real research conspect (e.g., `knowledge/res008-source-archival-fallbacks/`) |
| Manual: skill prompt update                                                          | After T2 | Visual review: deviation recording section present, examples correct                   |

## Coder handoff contract

Per AGENTS.md section 2.3 and section 2.3.1, the coder's handoff to `@reviewer` must include verification evidence (exit codes + summary lines) for each task. For this change specifically:

- **T1 handoff:** `make test-shell` exit code + summary line (e.g., `N tests, 0 failures`); `bash scripts/validate-research-pipeline.sh knowledge/res008-source-archival-fallbacks/` exit code + summary output (expected exit 0 with `ok:` lines).
- **T2 handoff:** `cat .opencode/skills/research-pipeline/SKILL.md` (visual review: "Deviation Recording" section present, examples correct, validator reference present).
