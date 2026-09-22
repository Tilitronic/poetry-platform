# Design: dev-infra-jq-probe

> **Proposal:** `openspec/changes/dev-infra-jq-probe/proposal.md`
> **Scope:** dev-infra only — no system architecture decisions, no `.sdd/` escalation required, no §10 routing (Q1).
> **Companion to:** `openspec/changes/dev-infra-language-servers/` (the LSP probe established the pattern this change mirrors).

## Approach

This change stays within the existing dev-infra module boundary and replicates the de-facto contract established by `scripts/check-host-lsp.sh`: a small standalone bash probe, wired as a `make test-shell` prerequisite, with a FAKE-mock bats counterpart for spec-logic coverage and a real-host seam for integration coverage. No new module is introduced, no cross-cutting technology decision is made, `architecture.md` is not affected.

### Patterns reused (no new patterns introduced)

- **Probe line shape:** mirrors `check-host-lsp.sh` (`ok:` / `fail:` / `summary:` lines; every exit-1 preceded by a what/why/how-to-fix remediation pointer; no bare `exit 1`). Deviations per Q5/Q6: ok→stdout, fail→stderr, summary emitted on both; NO skip line (jq is not skippable — contrast with `SKIP_RUST=1` in `check-host-lsp.sh`).
- **Two-step probe contract:** `command -v <tool>` for presence (handles non-executable files per Q2), then `<tool> -n '1+1'` for functional smoke (Q2: presence alone is insufficient). NO version check (Q1/Q2: no pin exists; a version check would invent one = scope creep).
- **bats FAKE-mock pattern:** mirrors `check-tools.bats` `install_fakes()` shape — FAKE binaries planted on `PATH`, env vars drive behavior, the script under test never shells a real host binary. 3-case matrix per Q7 (no 4th case; wrong-arg-shape is covered by case 3).
- **Makefile wiring pattern:** mirrors the LSP probe — new target adjacent to the existing `check-host-lsp` target, `.PHONY` appended alphabetically, `test-shell:` prereq prepended alphabetically.
- **Troubleshooting documentation pattern:** mirrors the existing `check-host-lsp` Q7a block in `host-lsp-setup.md` §Troubleshooting.

### Bash-3 compatibility (Q-contract)

`scripts/check-host-jq.sh` must run on macOS's stock bash 3.2. The script uses only:

- `set -euo pipefail`
- `command -v`
- `$(...)` command substitution
- `if`/`then`/`else`/`fi`
- Arithmetic expansion `$((...))`
- Basic string comparison `[ ... = ... ]`

It does NOT use (and the coder must not introduce):

- Associative arrays (`declare -A`)
- Indirect expansion (`${!var}`)
- `[[ ... ]]` bashisms (use `[ ... ]` or `test`)
- Arrays of any kind beyond positional parameters
- `**` globstar
- `printf -v`

Contrast with `check-host-lsp.sh` line 27 (`${!key:-}` indirect expansion) — that pattern is bash-4-only and is NOT replicated here. This is a deliberate design choice, not a regression: jq has no version pin to compare against, so the indirect-expansion machinery used by the LSP probe's env-file-sourced pin loop is unnecessary.

## Files changed

| File                                   | Change                                                                                                                                                                                                                                                                                                                                           | Notes                                                                                                          |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| `scripts/check-host-jq.sh`             | **New file** — bash-3 compatible, `set -euo pipefail`, standalone presence + functional probe. NO env-file sourcing, NO version pin. `command -v jq` → presence; `jq -n '1+1'` returns `2` → functional. Aggregate summary always emitted.                                                                                                       | Exit 0 iff present + functional; exit 1 otherwise with exactly one `fail:` line + pointer. ~40 lines.          |
| `scripts/__tests__/check-host-jq.bats` | **New file** — 3-case FAKE-mock matrix (all-ok / jq-missing / jq-non-functional). `install_fakes()` plants FAKE `jq` on `PATH`; env vars (`FAKE_JQ_MISSING`, `FAKE_JQ_BROKEN`) drive behavior; `PATH=fakes:/usr/bin:/bin` isolates from system `jq`.                                                                                             | bats NEVER shells a real `jq` binary. Wired into `make test-shell` via bats-wrapper auto-discovery. ~60 lines. |
| `Makefile`                             | `.PHONY` line (25): append `check-host-jq` adjacent to `check-host-lsp` (jq before lsp per Q4). New `check-host-jq` target adjacent to `check-host-lsp` target (lines 80-87, jq before lsp). `test-shell:` prereq (91): from `check-host-lsp test-opencode-docker` to `check-host-jq check-host-lsp test-opencode-docker` (alphabetical per Q4). | Gate B prereq: `make test-shell` now fails fast if jq probe fails.                                             |
| `scripts/__tests__/bats-wrapper.sh`    | `bash -n` syntax-check loop (lines 20-38): add `scripts/check-host-jq.sh` adjacent to `check-host-lsp.sh` per Q4. bats auto-discovery (line 65) picks up the new `.bats` file with no further wiring.                                                                                                                                            | Pure allowlist edit; no other logic change.                                                                    |
| `docs/dev-infra/host-lsp-setup.md`     | Fold jq into the existing host-setup doc (Q1: no new `host-toolchain.md`). Add: (a) `jq` prerequisite bullet; (b) `jq` install section with install-method-agnostic pointers (apt/brew/mise); (c) Troubleshooting entry mirroring the `check-host-lsp` Q7a block for the pre-install live-state.                                                 | File keeps its `host-lsp-setup.md` name; the jq section lives alongside the LSP content.                       |

### Files NOT changed (by ruling)

- **`scripts/gen-jsconfig.sh`** — the generator is unchanged (Q1). The probe is a standalone pre-check, not an inline generator edit.
- **`scripts/__tests__/gen-jsconfig.bats`** — unchanged (Q1).
- **`docs/dev-infra/host-toolchain.md`** — not created (Q1). jq folds into existing `host-lsp-setup.md`.
- **`Dockerfile.dev`** — no RUN/ARG/comment edits (Q1). Container already ships `jq`.
- **`scripts/check-host-lsp.sh`** — not renamed, not edited (Q1). jq gets its own probe.
- **`opencode.jsonc`** / **`oh-my-opencode-slim.jsonc`** / **`.opencode/agents/*.md`** / **`.opencode/skills/*/SKILL.md`** — not touched. §10 routing is N/A per Q1.
- **`.sdd/`** — no new document authored (gap carried forward from language-servers proposal, not a blocker).

## Data flow

### jq probe logic

```
make test-shell
   │
   ├── prereq: check-host-jq  (Gate B — real-host)
   │        │
   │        ▼
   │   scripts/check-host-jq.sh
   │        │
   │        ├── command -v jq ─── fail ──▶ fail: jq — not found on PATH. Install jq (...)
   │        │                             — see docs/dev-infra/host-lsp-setup.md
   │        │                             exit 1 (summary: 0 ok, 1 fail)
   │        │
   │        ├── jq -n '1+1' ─── ≠ 2 ──▶ fail: jq — present on PATH but non-functional
   │        │                             (jq -n '1+1' did not return 2).
   │        │                             Reinstall jq — see docs/dev-infra/host-lsp-setup.md
   │        │                             exit 1 (summary: 0 ok, 1 fail)
   │        │
   │        └── returns 2 ───────────▶ ok: jq <version> (host, functional)
   │                                    exit 0 (summary: 1 ok, 0 fail)
   │
   ├── prereq: check-host-lsp  (existing)
   │
   ├── prereq: test-opencode-docker  (existing)
   │
   └── bash scripts/__tests__/bats-wrapper.sh
            │
            ├── bash -n scripts/check-host-jq.sh  (allowlist edit)
            └── exec bats __tests__/
                   │
                   └── check-host-jq.bats  (Gate A — FAKE-mock, 3 cases)
                          auto-discovered via bats-wrapper.sh:65
```

The probe's input contract:

- `jq` may or may not be on `PATH` — that is what the probe checks.
- No env file is sourced (no pin to resolve).
- No env vars are consulted by the script itself (env vars `FAKE_JQ_MISSING` / `FAKE_JQ_BROKEN` are consumed by the FAKE binary in the bats test, not by the probe).

The probe's output contract (verbatim per Q5/Q6):

- **ok path:** one `ok: jq <version> (host, functional)` line to stdout + `summary: 1 ok, 0 fail` to stdout. Exit 0.
- **missing path:** one `fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md` line to stderr + `summary: 0 ok, 1 fail` to stderr. Exit 1.
- **non-functional path:** one `fail: jq — present on PATH but non-functional (jq -n '1+1' did not return 2). Reinstall jq — see docs/dev-infra/host-lsp-setup.md` line to stderr + `summary: 0 ok, 1 fail` to stderr. Exit 1.

There is no fourth output shape. Every exit-1 carries exactly one `fail:` line plus a remediation pointer plus the summary line. There is no bare `exit 1` (no exit without a what/why/how-to-fix message preceding it).

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                              | What it is                                                                                                               | Test location                                                                   | Test type                                                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **jq probe script** (`scripts/check-host-jq.sh`)  | Pure bash-3 function of host `PATH` → ok/fail + summary. Two-step: presence (`command -v`) + functional (`jq -n '1+1'`). | `scripts/__tests__/check-host-jq.bats` (Gate A) + `make check-host-jq` (Gate B) | Gate A: FAKE-mock behavioral (3 cases, bats NEVER shells real `jq`). Gate B: real-host. |
| **Makefile `check-host-jq` target**               | CLI entry point for the probe. Now a prerequisite of `test-shell`.                                                       | Invoked by `make test-shell` (Gate B prereq).                                   | Implicit: if the target fails, `test-shell` fails before any bats run.                  |
| **`docs/dev-infra/host-lsp-setup.md` jq section** | Owner-runnable install pointers + Troubleshooting entry. No automated test.                                              | Gate B (owner-run real-host probe).                                             | Markdown checklist; no automation by design (Q1).                                       |

### New seams vs. existing seams

- **jq probe script** — **new seam**. Justified: the probe is a standalone host-tool check, distinct from `check-host-lsp.sh` (which probes three LS binaries with a version pin). jq has no version pin, no env-file sourcing, no skippable branch; its probe logic is simpler but occupies its own seam because it verifies a different tool with a different failure mode (functional smoke vs version match). A new bats file is the right location (matches `check-tools.bats` precedent for FAKE-mock host-tool testing).
- **Makefile `check-host-jq` target, host-lsp-setup.md jq section** — existing seams extended (Makefile target + docs file).

### Seams split — why Gate A (FAKE) vs. Gate B (real-host)

The seam map reflects the same deliberate two-seam split as the LSP probe:

- **Gate A (FAKE-mock seam):** every test in `check-host-jq.bats` plants a FAKE `jq` on `PATH` and drives behavior via env vars. Fast, hermetic, CI-runnable, covers the probe's branching logic (present+functional, missing, non-functional). Does NOT verify the real `jq` binary runs.
- **Gate B (real-host seam):** the owner runs `bash scripts/check-host-jq.sh` (or `make check-host-jq`) against the real installed binary. Slow, non-hermetic, only runs on the owner's machine. DOES verify the real binary runs.

The two seams are complementary: Gate A covers logic, Gate B covers reality. The invariant — bats NEVER shells a real `jq` binary — is the enforcement line between them.

## Design constraints and trade-offs

### Why a standalone probe instead of an inline `gen-jsconfig.sh` edit

- **Separation of concerns:** the generator's job is to produce `jsconfig.json`; the probe's job is to assert host prerequisites. Mixing the two conflates production and verification.
- **Fail-early UX:** the probe runs as a `make test-shell` prereq, failing before any bats test runs. An inline edit would fail mid-generator with a cryptic `jq: command not found` buried in stdout.
- **Pattern reuse:** `check-host-lsp.sh` already established the standalone-probe + `make test-shell` prereq + FAKE-mock bats pattern for dev-infra host-tool checks. A second probe in the same shape is cheaper to learn and maintain than a one-off inline edit.
- **Q1 ruling:** owner explicitly chose standalone probe over inline edit.

### Why no version pin

- **No existing pin:** no file in the repo declares a `jq` version. `Dockerfile.dev` installs `jq` via the Debian package (whatever the base image ships), with no ARG pin. Introducing a pin in the probe would create a new source of truth that disagrees with the container's unpinned install — a net increase in drift surface.
- **Version-agnostic contract:** the probe only needs `jq` to be functional (`jq -n '1+1'` returns `2`). Any `jq` version that passes the functional smoke is acceptable. Pinning adds no safety.
- **Q1/Q2 ruling:** owner explicitly deferred the version pin ("a version check would invent one = scope creep").

### Why bash-3 compatible (not bash-4+)

- **macOS stock bash:** macOS ships bash 3.2 as `/bin/bash` (Apple refuses to update past GPLv3). Developers editing on macOS hosts without a brew-installed bash 4+ must still be able to run `make test-shell`.
- **Pattern divergence from `check-host-lsp.sh`:** `check-host-lsp.sh` requires bash 4+ because it uses `${!key}` indirect expansion to loop over env-file-sourced pin keys. The jq probe has no env-file-sourced pin loop, so the bash-4 machinery is unnecessary. Keeping jq bash-3 compatible expands the probe's reach without cost.
- **Q-contract:** owner explicitly mandated bash-3 compat in Phase 3 ("bash-3 compatible — NO bash-4 features — no associative arrays / ${!var} indirection").

### Why install-method-agnostic remediation pointer

- **Legit multiple install paths:** `jq` is available via `apt` (Debian/Ubuntu), `brew` (macOS/Linux), `mise` (version-manager), `dnf` (Fedora), binary download from github.com/jqlang/jq/releases. No single install method is canonical.
- **No privilege assumption:** the probe cannot know whether the owner has sudo, or prefers brew, or uses mise. Listing multiple methods without privileging any avoids steering the owner toward a specific toolchain.
- **Parity with `check-tools.sh`:** the existing `check-tools.sh` remediation pointer ("Run 'make build' first — mise ships inside the dev container.") is equally non-prescriptive about how the owner gets there.

### Why the `jq` section folds into `host-lsp-setup.md` instead of a new `host-toolchain.md`

- **File count minimization:** `host-lsp-setup.md` already exists, already covers host-setup prerequisites, already has a Troubleshooting section. Adding a `jq` section is one PR's worth of edits; creating a new file + renaming + cross-linking is more churn for the same information.
- **Q1 ruling:** owner explicitly chose "fold jq into `docs/dev-infra/host-lsp-setup.md` (no `host-toolchain.md`)".
- **Trade-off accepted:** the file's name (`host-lsp-setup.md`) no longer describes its full contents. This is a known debt; a future change can rename the file when the host-setup surface grows its next non-jq entry.

### Why 3 bats cases (not more)

- **Sufficiency:** the 3 cases cover every branch of the probe script — success path, missing path, non-functional path. There is no fourth branch to cover.
- **Wrong-arg-shape covered by case 3:** any invocation anomaly (wrong args, silent corruption, exit-non-zero-on-valid-input) is treated as non-functional and caught by case 3. No separate "wrong-arg-shape" case is needed.
- **Invariant protection:** the 3 cases together enforce the "bats NEVER shells a real `jq` binary" invariant. Adding more cases would not strengthen the invariant.
- **Maintenance cost:** every additional case is a FAKE binary state to maintain. 3 cases are enough to keep the probe's logic honest.
- **Q7 ruling:** owner explicitly confirmed "3-case matrix ONLY; no 4th case".

### Why summary on both stdout and stderr (not one or the other)

- **Visibility in piped contexts:** `make test-shell 2>&1 | tee log` should capture the summary regardless of whether the probe passed or failed. Emitting the summary on the same stream as the per-tool lines guarantees the summary is visible in the same context as the lines it summarizes.
- **Q6 ruling:** owner explicitly confirmed "ok→stdout, fail→stderr, `summary: N ok, M fail` on both".
