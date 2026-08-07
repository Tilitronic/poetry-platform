# Tasks: dev-infra-pin-sync

> **Proposal:** `openspec/changes/dev-infra-pin-sync/proposal.md`
> **Design:** `openspec/changes/dev-infra-pin-sync/design.md`
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/DIA-050.md` (CLOSED by this change)
> **Companion to:** `openspec/changes/volta-to-mise/` (§2.1 contract)
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity). §10 is N/A (validator is pure dev-infra, not AI-tooling config).

## Dependency graph

```
T1 — check-pin-sync.sh core (parse+compare+aggregate + exit codes)
 │  creates scripts/check-pin-sync.sh (~70-90L, new, bash-3 compatible)
 │  four functions: parse_reference / parse_dockerfile / compare / aggregate
 │  exit precedence 2>1>0; report-ALL; output-stream contract
 │
 │  verification: bash -n scripts/check-pin-sync.sh (exit 0)
 │                direct invocation against real repo files (exit 0; current pins match)
 │
 │  ┌────────────────────────────────────────────────────────────────────────┐
 │  │  T2 depends on T1 (script must exist before its bats suite runs)       │
 │  └────────────────────────────────────────────────────────────────────────┘
 ▼
T2 — bats suite T1-T10 + test-helper.bash promotion
 │  creates scripts/__tests__/check-pin-sync.bats (~180L, new, 13 scenarios)
 │  promotes install_fakes/setup_tree from check-tools.bats → test-helper.bash
 │  adds setup_pin_sync_tree to test-helper.bash
 │  refactors check-tools.bats to use shared helpers (no behavior change)
 │
 │  verification: make test-shell (exit 0; +10 new bats cases)
 │                existing 7 check-tools.bats cases still pass (refactor check)
 │
 │  ┌────────────────────────────────────────────────────────────────────────┐
 │  │  T3 depends on T1 + T2 (Makefile wiring needs script + bats in place) │
 │  └────────────────────────────────────────────────────────────────────────┘
 ▼
T3 — Makefile wiring + bats-wrapper + DIA-050 close
    edits Makefile: .PHONY, new check-pin-sync target, test-shell prereq chain
    edits scripts/__tests__/bats-wrapper.sh: bash -n allowlist
    edits docs/dev-infra-audit/tickets/DIA-050.md: OPEN → CLOSED + Fix/Re-verify
    
    verification: make check-pin-sync (exit 0; real-host)
                  make test-shell (exit 0; validator runs as prereq + 10 bats cases)
                  make test-infra (exit 0; end-to-end dev-infra)
                  make test-config (exit 0; unaffected)
                  make test-skills (exit 0; unaffected)
                  openspec validate dev-infra-pin-sync (exit 0; coder lane)
                  DIA-050.md status == CLOSED
```

**Critical path:** T1 → T2 → T3 (linear). Each slice is sized for one fresh context window. T1 is the narrowest (just the script + minimal verification); T2 adds the behavioral coverage; T3 adds the wiring that makes the validator a CI gate.

**Rationale for three slices (not one, not more):**

- **Not one slice:** the validator script (T1) is testable without the bats suite; the bats suite (T2) is testable without the Makefile wiring; the wiring (T3) is a small final step. Three slices allow each to be verified in isolation before the next begins — matching the tdd-craftsman "work one slice at a time" discipline.
- **Not more slices:** each slice is already the narrowest coherent unit. Splitting T1 further (e.g., parse_reference alone) would create a slice that isn't demoable on its own (a parser with no compare/aggregate is not a working validator). Splitting T2 (e.g., T1-T5 then T6-T10) would create artificial boundaries (the bats file is one logical unit; splitting forces a mid-file commit). Splitting T3 (e.g., Makefile edit separate from DIA-050 closure) would separate tightly-coupled changes (the Makefile wiring is what closes DIA-050; they're one conceptual act).

---

## T1 — check-pin-sync.sh core (parse+compare+aggregate + exit codes)

**Blockers:** none
**Vertical slice:** the validator script + minimal verification. After T1, `bash -n scripts/check-pin-sync.sh` exits 0, and `bash scripts/check-pin-sync.sh` exits 0 on the current repo (where all three sync points agree at 24.18.0 / 10.33.0).

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `feat(dev-infra): add check-pin-sync.sh validator (.mise.toml ↔ Dockerfile.dev parity)`

### Sub-steps (implementation order within the slice)

> Per `openspec/config.yaml` apply guidance: "Work one slice at a time". The sub-steps below are ordered to build the validator function-by-function, with each function reachable via a direct invocation that exercises the prior functions.

**Sub-step (a): Scaffold `scripts/check-pin-sync.sh`**

- New file, executable, ~70–90 lines, bash-3 compatible.
- Shebang: `#!/usr/bin/env bash`. Header comment describing the validator's purpose, the volta-to-mise §2.1 contract it enforces, and the exit-code precedence (`0 | 1 | 2`).
- `set -euo pipefail`.
- Resolve `ROOT_DIR` (same pattern as `check-tools.sh` line 23: `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`).
- Resolve `MISE_TOML="${ROOT_DIR}/.mise.toml"`, `DOCKERFILE_DEV="${ROOT_DIR}/Dockerfile.dev"`, and `DOCKERFILE_OC="${ROOT_DIR}/tools/opencode-docker/Dockerfile"`.

**Sub-step (b): Implement the INFRA preflight**

- Check all three source files exist: `[ -f "${MISE_TOML}" ]`, `[ -f "${DOCKERFILE_DEV}" ]`, and `[ -f "${DOCKERFILE_OC}" ]`. Any missing → emit `fail: source defective: <file> not found at <path>` to stderr + `summary: 0 ok, 0 fail (infra)` to stderr + exit 2.
- This is the first exit-2 short-circuit — it precedes any parsing.

**Sub-step (c): Implement `parse_reference`**

- Reads `$MISE_TOML`, extracts `node` / `pnpm` pins from the `[tools]` section.
- Implementation: `awk` between `/^\[tools\]/` and the next `^\[` line; for each line, match `^(node|pnpm)\s*=\s*"([^"]+)"$` (after quote stripping) or the single-quote / unquoted variants.
- Tracks per-key occurrence counts (use `case` + plain variables `SEEN_NODE=0`, `SEEN_PNPM=0`, incremented on each match). If any key's count exceeds 1, emit `fail: source defective: .mise.toml has duplicate key '<tool>' under [tools]` to stderr + exit 2.
- Returns via two global shell variables: `MISE_NODE`, `MISE_PNPM`.

**Sub-step (d): Implement `parse_dockerfile <path> <label>`**

- Reads one Dockerfile (invoked per source: once for `$DOCKERFILE_DEV` with label `"Dockerfile.dev"`, once for `$DOCKERFILE_OC` with label `"tools/opencode-docker/Dockerfile"`), extracts `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...`.
- Implementation: `grep -E '^\s*ARG\s+(NODE_VERSION|PNPM_VERSION)=' | awk -F'=' '{...}'`. Last-wins semantics documented but duplicate-detection short-circuits first (per INFRA ruling).
- Tracks per-ARG occurrence counts. If any ARG appears more than once, emit `fail: source defective: <label> has duplicate ARG '<NAME>'` to stderr + exit 2.
- Returns via two global shell variables: `DOCKER_NODE`, `DOCKER_PNPM`. The main flow invokes `parse_dockerfile` once per Dockerfile source and immediately saves the results into per-source variable pairs (`DOCKER_DEV_NODE`/`DOCKER_DEV_PNPM` after the first call, `DOCKER_OC_NODE`/`DOCKER_OC_PNPM` after the second) before the next invocation overwrites the globals.

**Sub-step (e): Implement `compare`**

- Pure function: takes a tool name, mise value, docker value. Strips quotes (`"`, `'`), CRLF (`\r`), leading/trailing whitespace from both values via `sed "s/[\"'\\r]//g; s/^[[:space:]]*//; s/[[:space:]]*$//"`.
- Returns 0 (match) or 1 (mismatch). No I/O.

**Sub-step (f): Implement `aggregate` + main flow**

- For each `(label, docker_node, docker_pnpm)` in `{("Dockerfile.dev", DOCKER_DEV_NODE, DOCKER_DEV_PNPM), ("tools/opencode-docker/Dockerfile", DOCKER_OC_NODE, DOCKER_OC_PNPM)}`:
  - For each tool in `{node, pnpm}`: call `compare <tool> <mise_value> <docker_value>`.
    - Match → emit `ok: <tool> <version> (parity @ <label>)` to stdout; increment ok counter.
    - Mismatch → emit `fail: <tool> — .mise.toml=<X> <label>=<Y>` to stderr; increment fail counter; accumulate mismatch.
- After the loop: emit `summary: N ok, M fail` to BOTH stdout and stderr (same shape as `check-host-jq.sh` / `validate-skills.sh`). N+M=4 when no INFRA condition.
- Exit 0 if `M=0`; exit 1 if `M>0`. (Exit 2 was already short-circuited earlier.)

**Sub-step (g): Verification (manual for T1 — the bats suite is T2)**

The coder runs the following checks and reports the results in the handoff evidence:

1. `bash -n scripts/check-pin-sync.sh` — syntax check. Exit 0 required.
2. `bash scripts/check-pin-sync.sh` — real-host invocation. Expected: exit 0, four `ok:` lines (`ok: node 24.18.0 (parity @ Dockerfile.dev)`, `ok: pnpm 10.33.0 (parity @ Dockerfile.dev)`, `ok: node 24.18.0 (parity @ tools/opencode-docker/Dockerfile)`, `ok: pnpm 10.33.0 (parity @ tools/opencode-docker/Dockerfile)`) + `summary: 4 ok, 0 fail`. (On the current repo, all three sync points agree.)
3. Bash-3 compliance grep: `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/check-pin-sync.sh` returns no matches.
4. Visual inspection: the script is under 90 lines; the four-function shape is visible; exit precedence `2 > 1 > 0` is documented in the header; two `parse_dockerfile` invocations are visible in the main flow.

### Acceptance criteria (T1, user perspective)

1. `scripts/check-pin-sync.sh` exists, is executable, is bash-3 compatible.
2. `bash -n scripts/check-pin-sync.sh` exits 0.
3. On the current repo (where `.mise.toml` pins match both Dockerfiles' ARGs at 24.18.0 / 10.33.0), `bash scripts/check-pin-sync.sh` exits 0 with four ok lines (one per pin per Dockerfile) + `summary: 4 ok, 0 fail`.
4. If `.mise.toml` is missing, exits 2 (INFRA) with source-defective fail line.
5. If `Dockerfile.dev` is missing, exits 2 (INFRA) with source-defective fail line.
6. If `tools/opencode-docker/Dockerfile` is missing, exits 2 (INFRA) with source-defective fail line.
7. If `.mise.toml` has duplicate `node` / `pnpm` key under `[tools]`, exits 2 (INFRA) with duplicate-key fail line.
8. If `Dockerfile.dev` has duplicate `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...`, exits 2 (INFRA) with duplicate-ARG fail line.
9. If `tools/opencode-docker/Dockerfile` has duplicate `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...`, exits 2 (INFRA) with duplicate-ARG fail line.
10. On pin mismatch in either Dockerfile (one or more comparisons fail), exits 1 with mismatch fail line(s); report-ALL (not fail-fast).
11. Output contract: ok→stdout, fail→stderr, summary on both streams.
12. Script is under 90 lines; four-function shape (parse_reference / parse_dockerfile / compare / aggregate) is visible; two `parse_dockerfile` invocations in main flow.

### Testing (T1)

- **No bats tests in T1** — the bats suite is T2. T1's verification is manual (direct invocation + syntax check).
- **Gate B acceptance:** the coder runs `bash scripts/check-pin-sync.sh` against the real repo files and confirms exit 0.

### Verification evidence (T1 coder handoff)

- `bash -n scripts/check-pin-sync.sh` exit code (expected: 0).
- `bash scripts/check-pin-sync.sh` exit code + output (expected: exit 0 + four `ok:` lines + `summary: 4 ok, 0 fail`).
- Bash-3 compliance grep result (expected: no matches).
- Line count of `scripts/check-pin-sync.sh` (expected: ≤ 90).

---

## T2 — bats suite T1-T13 + test-helper.bash promotion

**Blockers:** T1 (script must exist before the bats suite runs)
**Vertical slice:** the 13-scenario bats suite + test-helper promotion. After T2, `make test-shell` passes with the 13 new cases, the existing 7 `check-tools.bats` cases still pass (refactor check), and the shared fixture helpers are reusable.

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `test(dev-infra): 13-scenario bats suite for check-pin-sync + test-helper promotion`

### Sub-steps

> Per `openspec/config.yaml` apply guidance: "Write the failing test BEFORE any production code". But the production code (T1) is already in place. The RED-GREEN discipline here applies to the test-helper refactor: refactor first (existing tests must still pass), then add the new bats file (10 new cases must pass).

**Sub-step (a): Promote `install_fakes()` / `setup_tree()` from `check-tools.bats` → `test-helper.bash`**

- Move the inline `install_fakes()` definition (check-tools.bats lines 19-59) into `scripts/__tests__/test-helper.bash`. Rename to `install_check_tools_fakes()` to distinguish from future fakes (the pin-sync validator does not use mise/node/pnpm fakes — it uses fixture files; different helper).
- Move the inline `setup_tree()` definition (check-tools.bats lines 63-71) into `test-helper.bash`. Rename to `setup_check_tools_tree()` for the same reason.
- Update `check-tools.bats` to call the shared helpers via `load test-helper` (it already does).
- **Verification:** `make test-shell` exits 0; the existing 7 `check-tools.bats` cases still pass. If any regress, the refactor is broken — do not proceed.

**Sub-step (b): Add `setup_pin_sync_tree` to `test-helper.bash`**

- New helper: `setup_pin_sync_tree <with_mise_toml 0|1> <with_dockerfile_dev 0|1> <with_dockerfile_oc 0|1> <mise_node_pin> <mise_pnpm_pin> <docker_dev_node_pin> <docker_dev_pnpm_pin> <docker_oc_node_pin> <docker_oc_pnpm_pin>`.
- Creates a temp tree under `$BATS_TEST_TMPDIR` with:
  - `scripts/check-pin-sync.sh` (copied from `$REPO_ROOT/scripts/check-pin-sync.sh`).
  - Optionally `.mise.toml` with `[tools]` section containing the specified node/pnpm pins (default: quoted form `node = "<pin>"`).
  - Optionally `Dockerfile.dev` with `ARG NODE_VERSION=<pin>` / `ARG PNPM_VERSION=<pin>`.
  - Optionally `tools/opencode-docker/Dockerfile` with `ARG NODE_VERSION=<pin>` / `ARG PNPM_VERSION=<pin>`.
- Returns the tree root via stdout (same pattern as `setup_check_tools_tree`).
- Supports the quote/CRLF/whitespace variants via additional optional parameters (e.g., `setup_pin_sync_tree 1 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "24.18.0" "10.33.0" "crlf"` — the last argument selects a line-ending variant).

**Sub-step (c): Write `scripts/__tests__/check-pin-sync.bats`**

- New file, ~180 lines.
- Header comment describing the 13-case matrix (T1–T13) + the FAKE-mock invariant (bats NEVER reads real repo files, except one S4-style structural assertion).
- `load test-helper`.
- 13 `@test` blocks:
   - **T1** — `all pins match across both Dockerfiles -> exit 0 + four ok lines + summary: 4 ok, 0 fail`.
   - **T2** — `single pin mismatch in Dockerfile.dev (node) -> exit 1 + mismatch fail line + summary: 3 ok, 1 fail`.
   - **T3** — `multiple pin mismatches across both Dockerfiles (report-ALL) -> exit 1 + all fail lines + summary`.
   - **T4** — `.mise.toml missing -> exit 2 (INFRA) + source-defective fail line`.
   - **T5** — `Dockerfile.dev missing -> exit 2 (INFRA) + source-defective fail line`.
   - **T6** — `duplicate [tools] key in .mise.toml -> exit 2 (INFRA) + duplicate-key fail line` (the INFRA ruling).
   - **T7** — `duplicate ARG in Dockerfile.dev -> exit 2 (INFRA) + duplicate-ARG fail line`.
   - **T8** — `quote variations (single/double/unquoted, in any source file) -> exit 0 after stripping`.
   - **T9** — `CRLF line endings (in any source file) -> exit 0 after stripping`.
   - **T10** — `whitespace variations (extra spaces around =, in any source file) -> exit 0 after stripping`.
   - **T11** — `tools/opencode-docker/Dockerfile missing -> exit 2 (INFRA) + source-defective fail line`.
   - **T12** — `single pin mismatch in tools/opencode-docker/Dockerfile (node only; Dockerfile.dev matches) -> exit 1 + mismatch fail line + summary: 3 ok, 1 fail`.
   - **T13** — `duplicate ARG in tools/opencode-docker/Dockerfile -> exit 2 (INFRA) + duplicate-ARG fail line`.
- One S4-style structural-integrity test (asserting the real repo `.mise.toml` has `[tools]` + `node = "24.18.0"` + `pnpm = "10.33.0"` + header comment) — this is the ONE case that reads the real repo file, explicitly documented as an exception to the FAKE-mock invariant.

> **Old → new matrix traceability (for implementer/reviewer):**
> T1–T10 retain their scenario identity from the prior 10-case matrix. T1 expands its expected output from `summary: 2 ok, 0 fail` to `summary: 4 ok, 0 fail` (now covers both Dockerfiles). T2/T3 expand to allow either Dockerfile as the mismatch source. T5/T7 remain specific to `Dockerfile.dev`. T11/T12/T13 are new second-Dockerfile scenarios (missing / mismatch / duplicate-ARG), mirroring T5/T7 for `tools/opencode-docker/Dockerfile`.

**Sub-step (d): Verification**

The coder runs:

1. `make test-shell` — exit 0. Existing 7 `check-tools.bats` cases still pass (refactor check). 13 new `check-pin-sync.bats` cases pass.
2. Test count delta: baseline → baseline+13. If the delta differs, the coder explains.
3. Bash-3 compliance grep on `scripts/check-pin-sync.sh` (no change from T1; re-confirmed).

### Acceptance criteria (T2, user perspective)

1. `scripts/__tests__/test-helper.bash` exposes `install_check_tools_fakes`, `setup_check_tools_tree`, and `setup_pin_sync_tree` helpers.
2. `scripts/__tests__/check-tools.bats` uses the shared helpers (refactor from inline definitions); existing 7 cases pass unchanged.
3. `scripts/__tests__/check-pin-sync.bats` exists with 13 `@test` blocks (T1–T13).
4. Every test in `check-pin-sync.bats` (except the S4 structural assertion) uses fixture files under `$BATS_TEST_TMPDIR`; no test reads the real repo `.mise.toml` / `Dockerfile.dev` / `tools/opencode-docker/Dockerfile` for behavioral coverage.
5. T1–T13 cover every branch: match across both Dockerfiles, single-mismatch in either Dockerfile, multi-mismatch (report-ALL), missing source (×3: .mise.toml / Dockerfile.dev / tools/opencode-docker/Dockerfile), duplicate key (×3: .mise.toml / Dockerfile.dev / tools/opencode-docker/Dockerfile), quote/CRLF/whitespace normalization (×3).
6. `make test-shell` exits 0 with +13 cases; existing 7 `check-tools.bats` cases still pass.

### Testing (T2)

- **RED-GREEN discipline:** the refactor of `check-tools.bats` helpers (sub-step a) is tested first — existing 7 cases must still pass. Then the new bats file is added (sub-step c) — all 13 cases pass against the T1 production code.
- **FAKE-mock strategy:** every behavioral test uses `setup_pin_sync_tree` to plant fixture files with controlled content. The S4 structural assertion is the documented exception.
- **Invariant enforcement:** the coder verifies by inspection that no behavioral test reads `$REPO_ROOT/.mise.toml` / `$REPO_ROOT/Dockerfile.dev` / `$REPO_ROOT/tools/opencode-docker/Dockerfile`. (Automated enforcement: no trivial grep can enforce this across fixture-tree indirection; the coder's inspection is the gate.)

### Verification evidence (T2 coder handoff)

- `make test-shell` exit code (expected: 0).
- Test count delta (expected: baseline → baseline+13). If different, explanation.
- Confirmation that `scripts/__tests__/check-tools.bats` 7 cases still pass (refactor check).
- Confirmation that `scripts/__tests__/check-pin-sync.bats` 13 cases pass.
- Bash-3 compliance grep result (no change from T1; re-confirmed).

---

## T3 — Makefile wiring + bats-wrapper + DIA-050 close

**Blockers:** T1 + T2 (script + bats suite must exist before wiring)
**Vertical slice:** the Makefile wiring + bats-wrapper allowlist + DIA-050 ticket closure. After T3, `make check-pin-sync` runs the validator as a standalone target; `make test-shell` runs the validator as a prereq before bats; the bats-wrapper syntax-checks the new script; DIA-050 is CLOSED.

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `chore(dev-infra): wire check-pin-sync into make test-shell + close DIA-050`

### Sub-steps

**Sub-step (a): Edit `scripts/__tests__/bats-wrapper.sh`**

- Add `"$ROOT/scripts/check-pin-sync.sh" \` to the `bash -n` syntax-check loop (lines 20-38), placed adjacent to `check-tools.sh` (alphabetical within the check-* prefix).
- **Verification:** `bash scripts/__tests__/bats-wrapper.sh` runs `bash -n` on the new script as part of its normal flow.

**Sub-step (b): Edit `Makefile`**

- `.PHONY` line (25): append `check-pin-sync` adjacent to `check-tools` (alphabetical; `check-pin-sync` sorts before `check-tools` — `pi` < `to`). Result: `... check-pin-sync check-tools check-host-jq ...`.
- New `check-pin-sync` target adjacent to `check-tools` target (lines 60-67, pin-sync before tools alphabetically):
   ```makefile
   # Standalone source-parity validator (scripts/check-pin-sync.sh). Asserts
   # .mise.toml ↔ Dockerfile parity (Dockerfile.dev + tools/opencode-docker/Dockerfile)
   # for node/pnpm. Exit precedence 2>1>0 (INFRA>mismatch>match). 4 comparisons
   # total. See openspec/changes/dev-infra-pin-sync/.
   check-pin-sync:
   	bash scripts/check-pin-sync.sh
   ```
- `test-shell:` prereq line (99): insert `check-pin-sync` before `check-host-jq` (the validator runs before any bats, failing fast on pin drift). Result:
  `test-shell: check-pin-sync check-host-jq check-host-lsp test-opencode-docker`

**Sub-step (c): Close DIA-050**

- Edit `docs/dev-infra-audit/tickets/DIA-050.md`:
  - `status: OPEN` → `status: CLOSED`
  - `updated: 2026-08-05` → `updated: 2026-08-07` (today's date; adjust to actual closure date).
  - `Fix` section: populate with:
     > Closed by change `openspec/changes/dev-infra-pin-sync/`. `scripts/check-pin-sync.sh` asserts `.mise.toml` ↔ Dockerfile parity (`Dockerfile.dev` + `tools/opencode-docker/Dockerfile`) for `node`/`pnpm` under `make test-shell`. 13-scenario bats suite (T1–T13) covers match/mismatch/missing/duplicate/normalization branches across both Dockerfile sources. Exit precedence `2>1>0` (INFRA>mismatch>match). 4 comparisons total (2 pins × 2 Dockerfiles).
  - `Re-verify` section: populate with:
     > 1. `bash scripts/check-pin-sync.sh` exits 0 with four ok lines (one per pin per Dockerfile) + `summary: 4 ok, 0 fail`.
     > 2. `make test-shell` exits 0; includes 13 new `check-pin-sync.bats` cases.
     > 3. `make check-pin-sync` exits 0 (standalone invocation).

**Sub-step (d): Full verification gate**

The coder runs the following checks and reports the results in the handoff evidence:

1. **`bash -n scripts/check-pin-sync.sh`** — syntax check. Exit 0 required.
2. **`make check-pin-sync`** — standalone invocation. Expected: exit 0 + four `ok:` lines (one per pin per Dockerfile) + `summary: 4 ok, 0 fail`.
3. **`make test-shell`** — full bats suite. Expected: exit 0, validator runs as prereq (Gate B), then bats runs (Gate A) with 13 new cases passing. Test count increases by 13 from baseline.
4. **`make test-infra`** — end-to-end dev-infra validation. Expected: exit 0.
5. **`make test-config`** — OpenCode config validators. Expected: exit 0, unaffected.
6. **`make test-skills`** — skill frontmatter validators. Expected: exit 0, unaffected.
7. **`openspec validate dev-infra-pin-sync`** — routed through a coder lane (the openspec CLI is blocked in @openspec-plan's lane via permission shadowing). The orchestrator dispatches a coder lane to run this validation; the result feeds back into T3's verification evidence. Exit 0 required.
8. **DIA-050 closure visual inspection** — confirm `status: CLOSED`, `Fix` section populated, `Re-verify` section populated, `updated` date matches closure date.
9. **Bash-3 compliance grep** — `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/check-pin-sync.sh` returns no matches.

### Acceptance criteria (T3, user perspective)

1. `make check-pin-sync` runs `scripts/check-pin-sync.sh` as a standalone target and exits 0 on the current repo.
2. `make test-shell` runs `check-pin-sync` as a prereq BEFORE any bats run; bats auto-discovery runs `check-pin-sync.bats` with 13 cases. Post-change: all pass.
3. `scripts/__tests__/bats-wrapper.sh` syntax-checks `scripts/check-pin-sync.sh` via `bash -n` as part of its normal flow.
4. `docs/dev-infra-audit/tickets/DIA-050.md` status is `CLOSED` with populated `Fix` / `Re-verify` sections.
5. `make test-infra` passes end-to-end post-change (validator + bats + Docker smoke + Python tests).
6. `make test-config` and `make test-skills` are unaffected (no regressions).
7. `openspec validate dev-infra-pin-sync` passes (coder lane).
8. `scripts/check-pin-sync.sh` is bash-3 compatible (no bash-4-only constructs).

### Testing (T3)

- **No new tests in T3** — T3 is pure wiring. The validator script (T1) and bats suite (T2) are already tested. T3's tests are the wiring's effects: `make check-pin-sync` runs, `make test-shell` runs the prereq + bats, `bash -n` covers the new script.
- **Regression check:** existing `make test-shell` / `make test-infra` / `make test-config` / `make test-skills` targets continue to pass. No target breaks as a result of the wiring.

### Verification evidence (T3 coder handoff)

- `bash -n scripts/check-pin-sync.sh` exit code (expected: 0).
- `make check-pin-sync` exit code + output (expected: exit 0 + four ok lines + `summary: 4 ok, 0 fail`).
- `make test-shell` exit code + summary line (expected: exit 0, test count increases by 13 from baseline).
- `make test-infra` exit code + summary line (expected: exit 0).
- `make test-config` exit code (expected: 0, unaffected).
- `make test-skills` exit code (expected: 0, unaffected).
- `openspec validate dev-infra-pin-sync` exit code (coder lane — expected: 0).
- Bash-3 compliance grep result (no matches).
- Confirmation that `docs/dev-infra-audit/tickets/DIA-050.md` status == `CLOSED` + Fix/Re-verify sections populated (coder's visual inspection; one-line grep confirmation per section).

---

## Out of scope for these tasks

- **`.mise.toml` edits** — explicitly deferred per proposal scope boundary.
- **`Dockerfile.dev` edits** — explicitly deferred per proposal scope boundary.
- **`scripts/check-tools.sh` edits** — explicitly deferred per proposal scope boundary.
- **`tools/opencode-docker/Dockerfile` edits** — the validator reads it as a parity comparison source (like `Dockerfile.dev`); it is NOT modified.
- **§10 routing** — explicitly N/A per proposal scope boundary.
- **Any `.sdd/` document authoring** — gap flagged in proposal, not filled here.
- **Extra bats cases beyond the 13-case matrix (T1–T13)** — explicitly excluded per proposal Testing Decisions.
- **Windows host support** — out of scope; Windows developers use the dev container.

## Verification gate summary

| Gate                                       | When          | Required                                                                                   |
| ------------------------------------------ | ------------- | ------------------------------------------------------------------------------------------ |
| `bash -n scripts/check-pin-sync.sh`        | T1 sub-step g | Exit 0 (syntax valid, bash-3 compatible)                                                   |
| `bash scripts/check-pin-sync.sh` (real)    | T1 sub-step g | Exit 0 on current repo (all three sync points agree at 24.18.0 / 10.33.0; 4 ok lines)      |
| Bash-3 compliance grep                     | T1/T2/T3      | No matches for `declare -A\|\$\{!\|\[\[ \|\*\*\|printf -v`                                  |
| Line count of script                       | T1 sub-step g | ≤ 90 lines                                                                                 |
| `make test-shell`                          | T2 sub-step d | Exit 0; existing 7 `check-tools.bats` cases still pass (refactor check)                    |
| `make test-shell`                          | T3 sub-step d | Exit 0; includes 13 new `check-pin-sync.bats` cases (Gate A FAKE-mock)                     |
| `make check-pin-sync`                      | T3 sub-step d | Exit 0 on current repo (Gate B real-host standalone invocation; 4 ok lines)                |
| `make test-infra`                          | T3 sub-step d | Exit 0 (end-to-end dev-infra)                                                              |
| `make test-config`                         | T3 sub-step d | Exit 0 (unaffected)                                                                        |
| `make test-skills`                         | T3 sub-step d | Exit 0 (unaffected)                                                                        |
| `openspec validate dev-infra-pin-sync`     | T3 sub-step d | Exit 0 (coder lane — openspec CLI blocked in @openspec-plan's lane)                        |
| Visual: DIA-050.md status                  | T3 sub-step d | `status: CLOSED` + Fix/Re-verify populated + `updated` date matches closure date           |
