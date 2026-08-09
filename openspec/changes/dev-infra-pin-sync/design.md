# Design: dev-infra-pin-sync

> **Proposal:** `openspec/changes/dev-infra-pin-sync/proposal.md`
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/DIA-050.md` (CLOSED by this change)
> **Companion to:** `openspec/changes/volta-to-mise/` (§2.1 contract: `.mise.toml` is the single source of truth for node/pnpm tool pins)
> **Scope:** dev-infra only — no system architecture decisions, no `.sdd/` escalation required, no §10 routing.

## Approach

This change stays within the existing dev-infra module boundary and replicates the de-facto contract established by `scripts/check-host-jq.sh` and `scripts/check-tools.sh`: a small standalone bash validator, wired as a `make test-shell` prerequisite, with a FAKE-mock bats counterpart for spec-logic coverage and a real-host seam for integration coverage. No new module is introduced, no cross-cutting technology decision is made, `architecture.md` is not affected.

### Governing contract (volta-to-mise §2.1)

`openspec/changes/volta-to-mise/design.md` §2.1 establishes the dual-path mise contract:

1. `.mise.toml` — the single source of truth for node/pnpm tool pins.
2. `Dockerfile.dev` — the trust chain for the mise binary itself + the ARG declarations consumed by the node/pnpm install blocks.
3. `tools/opencode-docker/Dockerfile` — the opencode-docker image build + its own ARG declarations for node/pnpm versions (currently identical pins: `24.18.0` / `10.33.0`).

Per §2.1's "manual-sync contract" paragraph, the sources are manually synced at spec-author time, and "bumping either version requires updating BOTH the Dockerfile ARGs and the `[tools]` entry." This change **enforces that contract** with a validator that reads all three sync points and asserts parity (`.mise.toml` reference vs. each Dockerfile). The validator does NOT modify any source — it only reads.

### Patterns reused (no new patterns introduced)

- **Validator line shape:** mirrors `check-host-jq.sh` (`ok:` / `fail:` / `summary:` lines; every non-zero exit preceded by a what/why/how-to-fix remediation pointer; no bare `exit N`). Deviations per the confirmed summary: ok→stdout, fail→stderr, summary emitted on both; exit codes extended to `0 | 1 | 2` with `2 > 1 > 0` precedence (mirrors `validate-skills.sh`).
- **Three-sync-point comparison contract:** parse each source independently, normalize both sides (quote/CRLF/whitespace stripping), compare the `.mise.toml` reference against each Dockerfile. Total comparisons: 4 (2 pins × 2 Dockerfiles). No cross-source mutation. No "fix drift on detection" — the validator only reports.
- **bats FAKE-mock pattern:** mirrors `check-tools.bats` `install_fakes()` shape — fixture trees planted under `$BATS_TEST_TMPDIR`, the script under test invoked against the fixture tree. Fixture helpers promoted to `test-helper.bash` for reuse.
- **Makefile prereq wiring pattern:** mirrors the LSP/jq probes — new target adjacent to the existing `check-tools` target, `.PHONY` appended alphabetically, `test-shell:` prereq prepended so the validator runs before any bats.

### Bash-3 compatibility (Q-contract)

`scripts/check-pin-sync.sh` must run on macOS's stock bash 3.2. The script uses only:

- `set -euo pipefail`
- `command -v`, `test`, `[ ... ]`
- `$(...)` command substitution
- `if`/`then`/`else`/`fi`, `case`/`esac`
- `grep`, `awk`, `sed`, `tr` (POSIX-standard, ubiquitous)
- Basic string comparison `[ ... = ... ]`

It does NOT use (and the coder must not introduce):

- Associative arrays (`declare -A`) — the parsed pin map is six named shell variables total (two per source: `MISE_NODE`/`MISE_PNPM` from `.mise.toml`, `DOCKER_DEV_NODE`/`DOCKER_DEV_PNPM` from `Dockerfile.dev`, `DOCKER_OC_NODE`/`DOCKER_OC_PNPM` from `tools/opencode-docker/Dockerfile`), not a map.
- Indirect expansion (`${!var}`)
- `[[ ... ]]` bashisms (use `[ ... ]` or `test`)
- Arrays of any kind beyond positional parameters
- `**` globstar
- `printf -v`

This is a deliberate design choice: the validator's data model is six named pins (two per source, three sources), not a dynamic key-value map. Shell variables are sufficient; associative arrays would be over-engineering.

## Files changed

| File                                          | Change                                                                                                                                                                                                                                                                                                                                                                                                             | Notes                                                                                                            |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `scripts/check-pin-sync.sh`                   | **New file** — bash-3 compatible, `set -euo pipefail`, standalone source-parity validator. Four functions: `parse_reference()` (reads `.mise.toml`), `parse_dockerfile()` (reads one Dockerfile — invoked per source: `Dockerfile.dev` AND `tools/opencode-docker/Dockerfile`), `compare()` (normalizes + compares), `aggregate()` (accumulates results + emits summary). Exit precedence `2 > 1 > 0`. ~70–90 lines. 4 comparisons total (2 pins × 2 Dockerfiles). | Exit 0 iff all 4 comparisons match; exit 1 on any mismatch; exit 2 on defective source (missing file, duplicate key).     |
| `scripts/__tests__/check-pin-sync.bats`       | **New file** — 13-case FAKE-mock matrix (T1–T13). Fixture helpers promoted to `test-helper.bash`. Each test plants a fixture tree under `$BATS_TEST_TMPDIR` with controlled `.mise.toml` / `Dockerfile.dev` / `tools/opencode-docker/Dockerfile` contents; the validator runs against the fixture.                                                                                                                                                       | bats NEVER reads the real repo source files (except one S4-style structural assertion on `.mise.toml`).              |
| `scripts/__tests__/test-helper.bash`          | **Extended** — promote `install_fakes()`-style tree builder from `check-tools.bats` into a shared `setup_pin_sync_tree <with_mise_toml 0|1> <with_dockerfile_dev 0|1> <with_dockerfile_oc 0|1> <mise_node_pin> <mise_pnpm_pin> <docker_dev_node_pin> <docker_dev_pnpm_pin> <docker_oc_node_pin> <docker_oc_pnpm_pin>` helper. Refactor `check-tools.bats`'s inline `setup_tree()` to call the shared helper (no behavior change to existing tests). | Pure refactor of shared fixture plumbing; existing `check-tools.bats` behavior is unchanged.                     |
| `Makefile`                                    | `.PHONY` line (25): append `check-pin-sync` adjacent to `check-tools` (alphabetical). New `check-pin-sync` target adjacent to `check-tools` target (lines 60-67). `test-shell:` prereq line (99): insert `check-pin-sync` before `check-host-jq` (validator runs before any bats).                                                                                                                              | Gate B prereq: `make test-shell` now fails fast on pin drift before any bats run.                                |
| `scripts/__tests__/bats-wrapper.sh`           | `bash -n` syntax-check loop (lines 20-38): add `scripts/check-pin-sync.sh` adjacent to `check-tools.sh`. bats auto-discovery (line 65) picks up the new `.bats` file with no further wiring.                                                                                                                                                                                                                        | Pure allowlist edit; no other logic change.                                                                      |
| `docs/dev-infra-audit/tickets/DIA-050.md`     | Status: `OPEN` → `CLOSED`. `Fix` section populated: "Closed by change `openspec/changes/dev-infra-pin-sync/` — `scripts/check-pin-sync.sh` asserts `.mise.toml` ↔ `Dockerfile.dev` parity under `make test-shell`." `Re-verify` section populated: "`bash scripts/check-pin-sync.sh` exits 0; `make test-shell` passes with the new prereq + 10 new bats cases." `updated` date set to closure date.             | Traces DIA-050 → this change → validator script.                                                                 |

### Files NOT changed (by ruling)

- **`.mise.toml`** — the file is the single source of truth (per `volta-to-mise` §2.1); this change reads it, not modifies it.
- **`Dockerfile.dev`** — the validator consumes it as-is.
- **`scripts/check-tools.sh`** — orthogonal concern (runtime activation probe vs. source-parity probe). Both scripts coexist; the validator does NOT subsume `check-tools.sh`.
- **`tools/opencode-docker/Dockerfile` edits** — the validator reads it as a parity comparison source (like `Dockerfile.dev`); it is NOT modified. Only the `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...` lines are consumed; the `MISE_VERSION` pin in that Dockerfile is a separate concern outside DIA-050's scope.
- **`opencode.jsonc`** / **`oh-my-opencode-slim.jsonc`** / **`.opencode/agents/*.md`** / **`.opencode/skills/*/SKILL.md`** — not touched. §10 routing is N/A.
- **`.sdd/`** — no new document authored (gap carried forward from jq-probe / language-servers proposals, not a blocker).

## Data flow

### Validator logic

```
make test-shell
   │
   ├── prereq: check-pin-sync  (Gate B — real-host)
   │        │
   │        ▼
   │   scripts/check-pin-sync.sh
   │        │
    │        ├── resolve paths: ROOT_DIR/.mise.toml, ROOT_DIR/Dockerfile.dev, ROOT_DIR/tools/opencode-docker/Dockerfile
    │        │       │
    │        │       └── any missing? ──▶ exit 2 (INFRA: source defective)
    │        │                            fail: source defective: <file> not found at <path>
    │        │                            summary: 0 ok, 0 fail (infra)
    │        │
    │        ├── parse_reference(MISE_TOML) ──▶ (MISE_NODE, MISE_PNPM)
    │        │       │
    │        │       └── duplicate [tools] key detected? ──▶ exit 2 (INFRA)
    │        │                                                 fail: source defective: .mise.toml has duplicate key '<tool>'
    │        │                                                 summary: 0 ok, 0 fail (infra)
    │        │
    │        ├── parse_dockerfile(DOCKERFILE_DEV, "Dockerfile.dev") ──▶ (DOCKER_NODE, DOCKER_PNPM)
    │        │       │                                                  │
    │        │       │                                                  └── save: DOCKER_DEV_NODE=$DOCKER_NODE, DOCKER_DEV_PNPM=$DOCKER_PNPM
    │        │       │
    │        │       └── duplicate ARG NAME=... detected? ──▶ exit 2 (INFRA)
    │        │                                                  fail: source defective: Dockerfile.dev has duplicate ARG '<NAME>'
    │        │                                                  summary: 0 ok, 0 fail (infra)
    │        │
    │        ├── parse_dockerfile(DOCKERFILE_OC, "tools/opencode-docker/Dockerfile") ──▶ (DOCKER_NODE, DOCKER_PNPM)
    │        │       │                                                                  │
    │        │       │                                                                  └── save: DOCKER_OC_NODE=$DOCKER_NODE, DOCKER_OC_PNPM=$DOCKER_PNPM
    │        │       │
    │        │       └── duplicate ARG NAME=... detected? ──▶ exit 2 (INFRA)
    │        │                                                  fail: source defective: tools/opencode-docker/Dockerfile has duplicate ARG '<NAME>'
    │        │                                                  summary: 0 ok, 0 fail (infra)
    │        │
    │        ├── for each (label, docker_node, docker_pnpm) in
    │        │   { ("Dockerfile.dev", DOCKER_DEV_NODE, DOCKER_DEV_PNPM),
    │        │     ("tools/opencode-docker/Dockerfile", DOCKER_OC_NODE, DOCKER_OC_PNPM) }:
    │        │       │
    │        │       ├── for each tool in {node, pnpm}:
    │        │       │       │
    │        │       │       ├── strip quotes / CRLF / whitespace from both sides
    │        │       │       │
    │        │       │       ├── compare(mise_value, docker_value)
    │        │       │       │       │
    │        │       │       │       ├── equal ──▶ ok: <tool> <version> (parity @ <label>)    [stdout]
    │        │       │       │       │
    │        │       │       │       └── differ ──▶ fail: <tool> — .mise.toml=<X> <label>=<Y>  [stderr]
    │        │       │       │                      accumulate mismatch
    │        │
    │        ├── aggregate(): emit summary: N ok, M fail   [both streams]  (N+M=4 when no INFRA)
   │        │
   │        └── exit: 0 if M=0, else 1
   │
   ├── prereq: check-host-jq  (existing)
   │
   ├── prereq: check-host-lsp  (existing)
   │
   ├── prereq: test-opencode-docker  (existing)
   │
   └── bash scripts/__tests__/bats-wrapper.sh
            │
            ├── bash -n scripts/check-pin-sync.sh  (allowlist edit)
            └── exec bats __tests__/
                   │
                    └── check-pin-sync.bats  (Gate A — FAKE-mock, 13 cases)
                          auto-discovered via bats-wrapper.sh:65
```

### Function contracts

#### `parse_reference <mise_toml_path>`

Reads `.mise.toml` and extracts the `node` / `pnpm` pins from the `[tools]` section. Implementation: `awk` between `/^\[tools\]/` and the next `^\[` line; for each line, match `^(node|pnpm)\s*=\s*"([^"]+)"$` (after quote stripping) or the single-quote / unquoted variants. Tracks per-key occurrence counts — if any key appears more than once in the `[tools]` section, exit 2 (INFRA: duplicate key).

Returns via two global shell variables: `MISE_NODE`, `MISE_PNPM`. (No associative array; bash-3 compat.)

#### `parse_dockerfile <dockerfile_path> <label>`

Reads one Dockerfile (invoked per source: once for `Dockerfile.dev`, once for `tools/opencode-docker/Dockerfile`) and extracts `ARG NODE_VERSION=<value>` / `ARG PNPM_VERSION=<value>`. Implementation: `grep -E '^\s*ARG\s+(NODE_VERSION|PNPM_VERSION)=' | awk -F'=' '{...}'`. Last-wins semantics: if multiple `ARG NODE_VERSION=...` lines exist, the LAST one wins (matches Docker's own resolution behavior). HOWEVER — per the INFRA ruling, multiple declarations for the same ARG NAME is a structural defect; the validator exits 2 rather than silently picking the last one. The last-wins semantics is documented but the duplicate-detection short-circuits before last-wins resolution applies.

The `<label>` parameter carries the source's display name (e.g., `"Dockerfile.dev"` or `"tools/opencode-docker/Dockerfile"`) for use in fail-line formatting and INFRA error messages.

Returns via two global shell variables: `DOCKER_NODE`, `DOCKER_PNPM`. The main flow invokes `parse_dockerfile` once per Dockerfile source and immediately saves the results into per-source variable pairs (`DOCKER_DEV_NODE`/`DOCKER_DEV_PNPM` for `Dockerfile.dev`; `DOCKER_OC_NODE`/`DOCKER_OC_PNPM` for `tools/opencode-docker/Dockerfile`) before the next invocation overwrites the globals.

#### `compare <tool> <mise_value> <docker_value>`

Strips quotes (`"`, `'`), CRLF (`\r`), and leading/trailing whitespace from both values, then compares. Returns 0 (match) or 1 (mismatch). Pure function; no I/O.

#### `aggregate <ok_count> <fail_count>`

Accumulates ok/fail counts across all 4 comparisons (2 pins × 2 Dockerfiles). Emits the final `summary: N ok, M fail` line to both stdout and stderr (same stream as the per-comparison lines; N+M=4 when no INFRA condition). Exit code selection: 0 if `fail_count=0` AND no INFRA condition detected; 1 if `fail_count>0`; 2 if any INFRA condition (missing file, duplicate key, unparseable source) was detected during parsing. INFRA precedence: if both INFRA and mismatch conditions exist, exit 2 wins (the validator's inability to trust the source takes precedence over any mismatch finding).

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                   | What it is                                                                                                                       | Test location                                                                          | Test type                                                                                           |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Validator script** (`scripts/check-pin-sync.sh`)     | Pure bash-3 function of three source files (`.mise.toml` reference + two Dockerfiles) → ok/fail/infra + summary. Four functions: parse_reference / parse_dockerfile (invoked per Dockerfile source) / compare / aggregate. 4 comparisons total. | `scripts/__tests__/check-pin-sync.bats` (Gate A) + `make check-pin-sync` (Gate B)      | Gate A: FAKE-mock behavioral (13 cases, bats uses fixture trees only). Gate B: real-host.           |
| **Makefile `check-pin-sync` target**                   | CLI entry point for the validator. Now a prerequisite of `test-shell`.                                                           | Invoked by `make test-shell` (Gate B prereq).                                          | Implicit: if the target fails, `test-shell` fails before any bats run.                              |
| **Shared test-helper fixture** (`test-helper.bash`)    | `setup_pin_sync_tree()` helper for FAKE-mock bats suites. Reused by `check-pin-sync.bats` and `check-tools.bats` (after refactor). | Consumed by `check-pin-sync.bats` + `check-tools.bats`.                                | No direct test — it is test infrastructure, tested indirectly via every bats case that uses it.     |
| **DIA-050 ticket closure**                             | Markdown record of the fix + re-verify. No automated test.                                                                       | Visual review by `@reviewer` (Standards axis).                                         | Markdown checklist; no automation by design.                                                        |

### Test seam — the `install_fakes()` / `setup_tree()` fixture pattern

The existing `scripts/__tests__/check-tools.bats` establishes the FAKE-mock fixture pattern:

- `install_fakes <dir>` — plants fake `mise` / `node` / `pnpm` binaries in `<dir>` and prepends it to `PATH`. Behavior driven by env vars (`FAKE_MISE_WHICH_FAIL`, `FAKE_NODE_MISMATCH`, etc.).
- `setup_tree <with_mise_toml 0|1>` — copies `check-tools.sh` into an isolated temp tree under `$BATS_TEST_TMPDIR` and optionally seeds it with the real repo's `.mise.toml`. Returns the tree root.

This change **promotes these helpers to `scripts/__tests__/test-helper.bash`** for reuse across both the `check-tools.bats` and `check-pin-sync.bats` suites. The promotion is a pure refactor: existing `check-tools.bats` behavior is unchanged, but the helper definitions move from `check-tools.bats`'s inline block to `test-helper.bash`. A new `setup_pin_sync_tree` helper is added to `test-helper.bash` that extends the tree-builder pattern with a `.mise.toml` fixture AND two Dockerfile fixtures (`Dockerfile.dev` + `tools/opencode-docker/Dockerfile`) with configurable pin values per source.

This seam is the test-seam anchor for the whole change — every behavioral test in `check-pin-sync.bats` flows through `setup_pin_sync_tree`.

### New seams vs. existing seams

- **Validator script** — **new seam**. Justified: the validator is a standalone source-parity check, distinct from `check-tools.sh` (which probes runtime activation) and `check-host-jq.sh` (which probes host tool presence). Source-parity is a different concern with a different failure mode (drift between two files vs. tool missing vs. version mismatch against a hardcoded pin). A new script + new bats file is the right location.
- **Test-helper promotion** — **existing seam extended**. The `install_fakes()` / `setup_tree()` pattern already exists in `check-tools.bats`; promoting it to `test-helper.bash` is a pure refactor that strengthens the seam by making it reusable.
- **Makefile target, bats-wrapper allowlist, DIA-050 closure** — existing seams extended.

### Seams split — why Gate A (FAKE) vs. Gate B (real-host)

The seam map reflects the same deliberate two-seam split as the LSP/jq probes:

- **Gate A (FAKE-mock seam):** every test in `check-pin-sync.bats` plants fixture files under `$BATS_TEST_TMPDIR` and drives behavior via controlled content. Fast, hermetic, CI-runnable, covers the validator's branching logic (match across both Dockerfiles, mismatch in either Dockerfile, missing files, duplicate keys, quote/CRLF/whitespace normalization). Does NOT verify the validator runs against the real repo files.
- **Gate B (real-host seam):** the owner runs `bash scripts/check-pin-sync.sh` (or `make check-pin-sync`) against the real `.mise.toml`, `Dockerfile.dev`, and `tools/opencode-docker/Dockerfile`. Slow, non-hermetic, only runs on the owner's machine. DOES verify the validator runs against the real repo files.

The two seams are complementary: Gate A covers logic, Gate B covers reality. The invariant — Gate A bats NEVER read the real repo `.mise.toml` / `Dockerfile.dev` / `tools/opencode-docker/Dockerfile` (with the documented exception of one S4-style structural assertion) — is the enforcement line between them.

## Design constraints and trade-offs

### Why a standalone validator instead of extending `check-tools.sh`

- **Separation of concerns:** `check-tools.sh`'s job is to probe the mise-managed runtime (activation + version parity with `.mise.toml` pins). The new validator's job is to assert parity BETWEEN `.mise.toml` (the source of truth) and each Dockerfile. Mixing the two conflates runtime probing with source-parity checking.
- **Fail-early UX:** the validator runs as a `make test-shell` prereq, failing before any bats run if the sources drift. An inline extension of `check-tools.sh` would conflate two unrelated failure modes in a single output stream.
- **Pattern reuse:** `check-host-jq.sh` and `check-host-lsp.sh` already established the standalone-probe + `make test-shell` prereq + FAKE-mock bats pattern for dev-infra host-tool checks. A third probe in the same shape is cheaper to learn and maintain than a one-off inline extension.
- **Confirmed interview ruling:** owner explicitly chose standalone validator over `check-tools.sh` extension.

### Why grep/awk parsing (no TOML library)

- **No external runtime dependency:** the validator is bash-only. Adding a TOML parser would require either a Python/Node runtime (unavailable on a bare host) or a bash TOML library (no stable one exists; would add hundreds of lines for a 12-line file).
- **Intentionally narrow surface:** the validator only cares about the `[tools]` section's `node` / `pnpm` keys. It does NOT need to parse arbitrary TOML — it needs to extract two specific lines from a file with a known shape. `awk` between `/^\[tools\]/` and the next `^\[` is sufficient.
- **Defense in depth:** quote/CRLF/whitespace stripping in `compare()` handles the three known variants (double-quoted, single-quoted, unquoted) that could appear across the sources. The normalization is cheap (a `sed` pipeline) and robust.
- **Risk accepted:** if `.mise.toml` evolves to use features outside the narrow `[tools] node/pnpm` surface (e.g., inline tables, multi-line strings), the validator's parser will need updating. This is acceptable — the file is small and stable, and any parser breakage surfaces as exit 2 (INFRA: unparseable), not a silent wrong-answer.

### Why last-wins ARG semantics (with duplicate-detection short-circuit)

- **Docker's own resolution:** Docker treats multiple `ARG NAME=...` declarations as last-wins (the last declaration overrides earlier ones). The validator mirrors this behavior to avoid disagreeing with Docker on the effective value.
- **INFRA ruling override:** per the developer-confirmed INFRA ruling, duplicate `ARG NAME=...` for the same NAME is treated as a source defect (exit 2), not a silent last-wins resolution. This converts "which one wins?" ambiguity into a loud failure that forces the author to clean up the Dockerfile.
- **Practical reality:** the current `Dockerfile.dev` has exactly one `ARG NODE_VERSION=...` and one `ARG PNPM_VERSION=...`. Duplicates have never occurred; the rule is a prophylactic against future drift.

### Why exit precedence 2 > 1 > 0 (not 1 > 2 > 0)

- **Source trust is foundational:** if the validator cannot trust the source files (they're missing or structurally defective), no mismatch comparison is meaningful. Exit 2 (INFRA) must precede exit 1 (mismatch) — reporting a mismatch against a defective source would be misleading.
- **Pattern reuse:** mirrors `validate-skills.sh` (0 pass, 1 HARD failure, 2 infra error) — the same precedence convention already established in the dev-infra validator surface.
- **CI signal clarity:** exit 2 means "the validator itself is broken or the sources are unparseable — fix the infrastructure before asking about pin parity." Exit 1 means "the sources are fine but parity is violated — fix the drift." These are categorically different remediations; the exit code distinguishes them.

### Why report-ALL (not fail-fast on first mismatch)

- **Single-round-trip remediation:** if both `node` and `pnpm` have drifted, reporting both in a single run lets the developer fix both at once. Fail-fast would require two runs to discover both mismatches.
- **Pattern reuse:** mirrors the `validate-skills.sh` accumulation pattern — all findings reported, exit code reflects the aggregate.
- **Confirmed interview ruling:** owner explicitly chose report-ALL over fail-fast.

### Why ~70–90 line budget

- **Sufficient for the surface:** four functions (parse_reference / parse_dockerfile / compare / aggregate) + main flow (parses three sources, runs 4 comparisons) + headers/comments fits comfortably in 70–90 lines. Going above 90 would indicate over-engineering (e.g., reaching for associative arrays or dynamic key lists).
- **Maintainability cap:** a validator under 90 lines is readable in a single screen; code review is cheap. A validator over 100 lines starts to invite "why is this so complicated?" questions.
- **Bash readability:** bash scripts longer than ~100 lines without clear function decomposition become difficult to follow. The four-function shape + main flow is the natural decomposition for this surface.

### Why the test-helper promotion (not duplicate helpers)

- **DRY principle:** the `install_fakes()` / `setup_tree()` pattern in `check-tools.bats` is identical in shape to what `check-pin-sync.bats` needs. Duplicating the pattern across two bats files would be a maintenance hazard (any bug fix must be applied twice).
- **Precedent:** `test-helper.bash` already hosts shared helpers (`mock_docker`, `setup_dev_stack_tree`, `require_unshare`, etc.). Adding `setup_pin_sync_tree` and promoting `install_fakes()` / `setup_tree()` follows the established pattern.
- **Refactor safety:** the promotion is a pure refactor — existing `check-tools.bats` behavior is unchanged (it just calls the shared helper instead of its inline version). The existing 7 `check-tools.bats` tests continue to pass post-refactor; if any regress, the refactor is broken.
