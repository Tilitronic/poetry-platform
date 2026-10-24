# Proposal: dev-infra-jq-probe

> **Status:** proposed · **Scope:** dev-infra (host probe + Makefile + bats + docs)
> **Escalation:** none — change is within existing dev-infra module boundaries (per AGENTS.md §2.4). §10 (AI Devtools Modernization Workflow) is N/A per Q1: jq is a host-runtime dependency, not an AI-tooling config surface.

## Motivation

The dev container ships `jq` (it is consumed by `scripts/gen-jsconfig.sh` to emit `jsconfig.json`). The **host** has no such guarantee. Two consequences surface today:

1. **`make test-infra` fails at `gen-jsconfig` on host** — the generator invokes `jq`, which is absent on a fresh developer laptop; the failure is a late, cryptic `jq: command not found` buried in the generator's stdout, not a clear remediation pointer.
2. **5 `gen-jsconfig.bats` failures on host** — the bats test shells `jq` to validate the generator's output shape; without `jq`, every case fails identically at the missing-binary step, masking any real generator regression.

The container and CI paths are **unaffected** (`jq` ships in `Dockerfile.dev` and the CI runner inherits the container's PATH). This is purely a **host-side environmental gap** — the developer editing in host mode (VSCode-on-host, opencode-on-host, or running `make test-infra` directly on the laptop) has no signal that `jq` is missing until the generator or its tests crash.

This change closes the gap with a single **gated presence-and-functional probe** (`scripts/check-host-jq.sh`), wired into `make test-shell` as a prerequisite so `jq`'s absence fails loudly **before** any bats run — mirroring the established `check-host-lsp.sh` pattern (see `openspec/changes/dev-infra-language-servers/proposal.md`). The probe adds no version pin (Q1/Q2: a version check would invent a pin that does not exist in the repo today = scope creep). It adds no install automation (install-method-agnostic remediation pointer only).

## Scope

### In scope

1. **Standalone probe — `scripts/check-host-jq.sh`** (~40 lines, new file, executable). Bash-3 compatible (no bash-4 features — no associative arrays, no `${!var}` indirection). Two-step check:
   - Presence: `command -v jq` (handles non-executable files per Q2).
   - Functional smoke: `jq -n '1+1'` must return `2` (Q2: presence alone is not enough — a broken `jq` on PATH must also fail).
   - NO version check, NO pin, NO comparison against any source of truth. The ok line reports `jq`'s self-reported version as informational only (Q1/Q2).
   - Exit `0` iff present + functional; exit `1` otherwise with exactly one `fail:` line plus a remediation pointer to `docs/dev-infra/host-lsp-setup.md` (Q2/Q5).
   - Aggregate `summary: N ok, M fail` line always emitted, on both stdout (ok path) and stderr (fail path) (Q6). No skip line (Q6: `jq` is not skippable).
2. **bats test — `scripts/__tests__/check-host-jq.bats`** (~60 lines, new file). 3-case FAKE-mock matrix (Q7, no 4th case — wrong-arg-shape is covered by case 3):
   - `all-ok` — functional `jq` on PATH → exit 0, `ok:` line, summary.
   - `jq-missing` — no `jq` on PATH → exit 1, missing-`jq` `fail:` line + pointer.
   - `jq-non-functional` — `jq` on PATH but `jq -n '1+1'` does not return 2 → exit 1, non-functional `fail:` line + pointer.
   - FAKE-jq hermetic pattern (Q2): `FAKE_JQ_MISSING` / `FAKE_JQ_BROKEN` env vars drive the FAKE binary; `PATH=fakes:/usr/bin:/bin` isolates from system `jq`; bats NEVER shells a real `jq` binary.
3. **Makefile wiring**:
   - `.PHONY` line (25): append `check-host-jq` alphabetically — placed adjacent to `check-host-lsp`, jq before lsp per Q4.
   - New target `check-host-jq` adjacent to `check-host-lsp` target (lines 80-87), jq before lsp.
   - `test-shell:` prereq line (91): from `test-shell: check-host-lsp test-opencode-docker` to `test-shell: check-host-jq check-host-lsp test-opencode-docker` (alphabetical per Q4).
4. **bats-wrapper allowlist — `scripts/__tests__/bats-wrapper.sh`** (lines 20-38): add `scripts/check-host-jq.sh` to the `bash -n` syntax-check loop, placed adjacent to `check-host-lsp.sh` per Q4. bats auto-discovery (line 65) picks up the new `.bats` file with no further wiring.
5. **Docs — `docs/dev-infra/host-lsp-setup.md`** (fold-in per Q1; no new `host-toolchain.md`):
   - Add a `jq` prerequisite bullet (host `jq` is required by `scripts/gen-jsconfig.sh`; the probe verifies it).
   - Add a `jq` install section with install-method-agnostic pointers (`apt install jq`, `brew install jq`, `mise install jq` — none privileged, all equivalent from the probe's perspective).
   - Add a Troubleshooting entry mirroring the existing `check-host-lsp` Q7a block: "pre-install `make test-shell` fails at `check-host-jq` — accepted live-state; run the install pointers above; post-install green".

### Out of scope (by ruling)

- **`gen-jsconfig.sh` / `gen-jsconfig.bats` changes** (Q1): the generator is unchanged; the probe is a standalone pre-check, not an inline generator edit.
- **`host-toolchain.md`** (Q1): `jq` is folded into the existing `host-lsp-setup.md`, no new doc.
- **`Dockerfile.dev` changes** (Q1): the container already ships `jq`; no RUN/ARG/comment edits.
- **§10 (AI Devtools Modernization Workflow)** (Q1): `jq` is a host-runtime dependency, not AI-tooling config.
- **`jq` version pin** (Q1/Q2): no pin exists in the repo today; introducing one is scope creep. The probe is presence + functional smoke only.
- **`check-host-lsp.sh` rename** (Q1): the existing LSP probe is untouched; `jq` gets its own probe.
- **Windows host support** — Windows developers use the dev container, where `jq` is already present.
- **CI host-jq enforcement** — CI runs in the dev container; the probe is a developer-convenience gate on host.
- **New `.sdd/` document** — dev-infra is within existing module boundaries; the `.sdd/` gap is logged in the language-servers proposal and re-logged here for continuity. No escalation needed.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation. This change reuses the de-facto contract established by `scripts/check-host-lsp.sh` + the language-servers artifacts (`openspec/changes/dev-infra-language-servers/`) as its governing pattern — no new authority layer required.

**`.sdd/` gap flag (carried forward from language-servers proposal, not a blocker):**

- No `.sdd/dev-infra/architecture.md` exists. dev-infra is not yet represented in the SDD layer. This change does not author one (out of scope; dev-infra's module boundary is stable, no cross-cutting technology decision is being made here). The gap is logged as a follow-up candidate for when dev-infra grows its next non-trivial module.

## Rollback plan

Every artifact added by this change is independently revertable. The probe + its wiring is one conceptual unit; rolling back any piece does not force rollback of the others.

| Artifact                                                               | Revert                          |
| ---------------------------------------------------------------------- | ------------------------------- |
| `scripts/check-host-jq.sh`                                             | Delete file                     |
| `scripts/__tests__/check-host-jq.bats`                                 | Delete file                     |
| Makefile `.PHONY` / `check-host-jq` target / `test-shell:` prereq edit | `git checkout` to prior version |
| `scripts/__tests__/bats-wrapper.sh` allowlist edit                     | `git checkout` to prior version |
| `docs/dev-infra/host-lsp-setup.md` jq section + troubleshooting entry  | `git checkout` to prior version |

All rollbacks are file deletions or `git checkout` to prior versions. No existing production code, Dockerfile.dev, or configuration is modified. Rollback restores prior `test-shell` behavior (probe absent, prereq absent) — the pre-change live-state. No data migrations. No side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra — the test verifies **tool presence and functional shape**, not business logic. A good test is one that fails loudly when `jq` goes missing or is broken, and passes quietly otherwise. We do NOT test `jq`'s correctness (it is a third-party binary) or its version (no pin exists per Q1/Q2).

### Two-gate acceptance (Gate A FAKE-mock / Gate B real-host)

The verification splits along the same seam established by `check-host-lsp.sh` (see `openspec/changes/dev-infra-language-servers/proposal.md` §Host-scope 3-gate acceptance).

#### Gate A — spec-logic bats (FAKE-mocked, no host install required)

- **Location:** `scripts/__tests__/check-host-jq.bats`
- **Pattern:** FAKE-mock from `check-tools.bats` — `install_fakes()` plants a FAKE `jq` on `PATH` in a temp dir, `PATH=fakes:/usr/bin:/bin` isolates from the system `jq`, env vars (`FAKE_JQ_MISSING`, `FAKE_JQ_BROKEN`) drive the FAKE binary's behavior. The script under test never shells a real `jq` binary.
- **3-case matrix (Q7, no extras):**
  1. `all-ok` — FAKE `jq` is on PATH, `jq -n '1+1'` returns `2` → exit 0, `ok: jq <version> (host, functional)` line, summary line.
  2. `jq-missing` — no `jq` on PATH (FAKE not planted, or `FAKE_JQ_MISSING` removes it) → exit 1, `fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md`, summary line.
  3. `jq-non-functional` — FAKE `jq` is on PATH but `jq -n '1+1'` does not return 2 (`FAKE_JQ_BROKEN` set) → exit 1, `fail: jq — present on PATH but non-functional (jq -n '1+1' did not return 2). Reinstall jq — see docs/dev-infra/host-lsp-setup.md`, summary line. This case also covers wrong-arg-shape / silent-corruption — any invocation anomaly is non-functional.
- **Invariant:** bats NEVER shells a real `jq` binary. If any test invokes a real system `jq`, the test is broken.
- **Runs under:** `make test-shell` (via bats-wrapper auto-discovery at line 65; baseline → baseline+3).

#### Gate B — host-integration, owner-run

- **Runs manually:** `bash scripts/check-host-jq.sh`, `make check-host-jq`, `make test-shell`.
- **Pass criteria:** `check-host-jq.sh` exits 0; `make check-host-jq` exits 0; `make test-shell` passes with the new prereq.
- **Live-state acceptance (Q7, mirroring check-host-lsp Q7a):** on a host without `jq`, `make test-shell` fails at the `check-host-jq` prereq before any bats run. This is accepted, not a blocker; documented in `docs/dev-infra/host-lsp-setup.md` §Troubleshooting with install-method-agnostic remediation pointers (apt/brew/mise).
- **Gate B is the real-host probe seam** — the counterpart to Gate A's FAKE-mock seam.

### What we explicitly do NOT test

- `jq`'s version (no pin; Q1/Q2 scope boundary).
- `jq`'s correctness on non-trivial inputs (third-party binary; out of scope).
- `gen-jsconfig.sh` behavior changes (untouched per Q1).
- CI host-jq enforcement (CI runs in the container where `jq` ships; Q1 scope boundary).
- Extra bats cases beyond the 3-case matrix (Q7 explicit: no 4th case).

### Prior art in the codebase

- **Probe line shape + aggregate-summary pattern:** existing `scripts/check-host-lsp.sh` (ok:/fail:/summary: line shapes; every exit-1 preceded by a remediation pointer).
- **bats FAKE-mock pattern:** existing `scripts/__tests__/check-tools.bats` (`install_fakes()` plants FAKE binaries on `PATH`, env vars drive behavior).
- **Makefile prereq wiring pattern:** existing `test-shell: check-host-lsp test-opencode-docker` (line 91).
- **bats-wrapper `bash -n` allowlist pattern:** existing `scripts/__tests__/bats-wrapper.sh` lines 20-38 (syntax-check loop over plain shell artifacts).
- **bats auto-discovery:** existing `scripts/__tests__/bats-wrapper.sh` line 65 (`exec "$BATS" ... "$TESTS_DIR"`).
- **Troubleshooting live-state documentation pattern:** existing `docs/dev-infra/host-lsp-setup.md` §Troubleshooting ("`make test-shell` fails at `check-host-lsp` on an unconfigured host" — Q7a block).

### Test risk and mitigation

**Risk:** the FAKE-mock invariant breaks (a test accidentally shells the system `jq`). **Mitigation:** every test sets `PATH=fakes:/usr/bin:/bin` via `install_fakes()`, isolating from the system `jq` by construction. The same invariant is enforced in `check-tools.bats` for `mise`/`node`/`pnpm`.

**Risk:** Gate B live-state breaks `make test-shell` for developers who have not installed `jq` yet. **Mitigation:** documented in `host-lsp-setup.md` §Troubleshooting with three install-method-agnostic pointers (apt/brew/mise); none are privileged (the `sudo apt install jq` form is the common Debian/Ubuntu idiom, documented as such; `brew` and `mise` forms are non-sudo). The probe surfaces a remediation pointer in the fail line itself, so the developer is never left without a next step.

**Risk:** the probe is bash-4-only (e.g. uses associative arrays or `${!var}` indirection), breaking it on macOS's stock bash 3. **Mitigation:** design.md §Design constraints mandates bash-3 compatibility; `check-host-jq.sh` uses only basic `if/then`, `$()`, `command -v`, all of which are bash-3 safe. No associative arrays, no `${!var}` indirection (contrast with `check-host-lsp.sh` line 27 which uses `${!key}` — that pattern is NOT replicated here).
