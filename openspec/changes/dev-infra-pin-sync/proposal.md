# Proposal: dev-infra-pin-sync

> **Status:** proposed · **Scope:** dev-infra (standalone validator + bats suite + Makefile wiring)
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/DIA-050.md` (OPEN since 2026-08-05 — this change CLOSES it)
> **Companion to:** `openspec/changes/volta-to-mise/` (established the `.mise.toml`-as-source-of-truth contract in §2.1)
> **Escalation:** none — change is within existing dev-infra module boundaries (per AGENTS.md §2.4). §10 (AI Devtools Modernization Workflow) is N/A: the validator is a pure dev-infra artifact (bash script + bats + Makefile), not AI-tooling config.

## Motivation

The dev container toolchain pins `node` and `pnpm` in **two** sources that must stay in parity:

1. `.mise.toml` — `[tools]` section (the single source of truth, per `volta-to-mise` §2.1 contract).
2. `Dockerfile.dev` — `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...` consumed by the node/pnpm install blocks.

`openspec/changes/volta-to-mise/design.md` §2.1 documents the current **one-time manual sync** contract: the `.mise.toml` header comment states the node/pnpm versions are "derived from Dockerfile.dev ARGs at spec-author time" and that bumping either version requires updating BOTH the Dockerfile ARGs and the `[tools]` entry. The gap — tracked as **DIA-050** since 2026-08-05 — is that **no automated validator enforces parity**. Today, drift between the two sources can accumulate silently with zero signal until a developer notices by accident.

The existing `scripts/check-tools.sh` is a red herring for this gap: it probes the mise-managed runtime tools (activation + version parity with `.mise.toml`), but it does NOT cross-check `.mise.toml` against `Dockerfile.dev`. It hardcodes `NODE_PIN="24.18.0"` / `PNPM_PIN="10.33.0"` and compares the live mise-declared pins against those hardcoded values — it never reads `Dockerfile.dev` at all. So even when `check-tools.sh` passes, the `.mise.toml` ↔ `Dockerfile.dev` parity is **unverified**.

Present drift: **none** (all three sync points currently agree at 24.18.0 / 10.33.0). Enforcement: **none**. This change closes the enforcement gap with a standalone validator that reads both sources and asserts parity — making drift **impossible to commit without CI signal**.

## Approach

A single standalone bash script `scripts/check-pin-sync.sh` (~60–80 lines) that:

1. Parses `.mise.toml`'s `[tools]` section for `node` / `pnpm` pins (grep/awk-based; no TOML library — dev-infra shell scripts in this repo do not depend on external language runtimes for parsing).
2. Parses `Dockerfile.dev` for `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...` declarations (last-wins semantics, matching Docker's own resolution).
3. Compares the two parsed reference maps after stripping quotes, CRLF, and extraneous whitespace (defensive normalization — the same pin value can be written `node = "24.18.0"`, `node='24.18.0'`, or `node=24.18.0` across the two files).
4. Aggregates all mismatches into a single report (report-ALL, not fail-fast) and exits with precedence `2 > 1 > 0`:
   - **Exit 0** — all pins match.
   - **Exit 1** — at least one pin mismatches (source files are valid, parity violated).
   - **Exit 2** — infrastructure error (source of truth is structurally defective: file missing, unparseable, or — per the developer-confirmed INFRA ruling — duplicate `[tools]` key for the same tool). Exit 2 takes precedence over exit 1: a defective source is reported before any mismatch comparison runs.

The script is wired into `make test-shell` as a prerequisite (same shape as `check-host-jq` / `check-host-lsp`) and exposed as a standalone `make check-pin-sync` target for direct invocation. A 10-scenario bats suite covers every branch (match, mismatch, missing files, duplicate keys, quote/CRLF/whitespace variations).

## Scope

### In scope

1. **Standalone validator — `scripts/check-pin-sync.sh`** (~60–80 lines, new file, executable). Bash-3 compatible (no associative arrays, no `${!var}` indirection, no `[[ ... ]]` bashisms). Responsibilities:
   - Parse `.mise.toml` for `[tools]` pins (node/pnpm).
   - Parse `Dockerfile.dev` for `ARG NODE_VERSION=...` / `ARG PNPM_VERSION=...`.
   - Normalize both sides (quote/CRLF/whitespace stripping).
   - Report-ALL mismatches (never fail-fast on the first mismatch).
   - Exit precedence `2 > 1 > 0` (defective source > mismatch > match).
   - Output contract: ok lines → stdout, fail lines → stderr, aggregate `summary: N ok, M fail` on both streams.
2. **bats suite — `scripts/__tests__/check-pin-sync.bats`** (~120 lines, new file). 10 scenarios (T1–T10) covering every branch of the validator. Shared fixture helpers (`install_fakes()`-style tree builders) promoted to `scripts/__tests__/test-helper.bash` for reuse across the check-tools / check-pin-sync bats files.
3. **Makefile wiring**:
   - `.PHONY` line: append `check-pin-sync` alphabetically (adjacent to `check-tools`).
   - New `check-pin-sync` target (standalone invocation).
   - `test-shell:` prereq chain: insert `check-pin-sync` before `check-host-jq` (the validator runs before any bats, failing fast on pin drift).
4. **bats-wrapper allowlist — `scripts/__tests__/bats-wrapper.sh`**: add `scripts/check-pin-sync.sh` to the `bash -n` syntax-check loop, adjacent to `check-tools.sh`.
5. **DIA-050 ticket — `docs/dev-infra-audit/tickets/DIA-050.md`**: status → CLOSED, `Fix` / `Re-verify` sections populated, `updated` date set to closure date.

### Out of scope (by ruling)

- **`.mise.toml` edits** — the file is the single source of truth (per `volta-to-mise` §2.1); this change reads it, not modifies it.
- **`Dockerfile.dev` edits** — the validator consumes it as-is.
- **`scripts/check-tools.sh` edits** — orthogonal concern (runtime activation probe vs. source-parity probe). Both scripts coexist.
- **`tools/opencode-docker/Dockerfile` parity check** — DIA-050 explicitly scopes this change to the primary `.mise.toml` ↔ `Dockerfile.dev` pair. The opencode-docker Dockerfile has its own `MISE_VERSION` pin (not a node/pnpm tool pin); its parity is a separate concern, out of scope here.
- **§10 routing** — N/A. The validator is a pure dev-infra artifact (bash/bats/Makefile), not AI-tooling config.
- **New `.sdd/` document** — dev-infra is within existing module boundaries; no cross-cutting technology decision is being made. The `.sdd/` gap is flagged below (carried forward from prior dev-infra proposals, not a blocker for this change).
- **`bun` / `uv` / `snip` / `mise` pin parity** — DIA-050 tracks node/pnpm only (the two tools with both `.mise.toml` AND `Dockerfile.dev` pin declarations). Other tools have only one source each.
- **Windows host support** — Windows developers use the dev container, where `Dockerfile.dev` is the source of truth.
- **CI gate extension beyond `test-shell`** — `make test-shell` is already the dev-infra CI gate; no additional wiring needed.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. The only file under `.sdd/` today is `.sdd/README.md`, which documents the three-layer model itself — no module-level `.sdd/<module>/architecture.md` documents exist yet (dev-infra included). Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation. This change reuses the de-facto contract established by `volta-to-mise` §2.1 (`.mise.toml`-as-source-of-truth) and the `check-host-jq` / `check-tools` probe patterns as its governing precedent.

**`.sdd/` gap flag (carried forward from jq-probe / language-servers proposals, not a blocker):**

- No `.sdd/dev-infra/architecture.md` exists. dev-infra is not yet represented in the SDD layer. This change does not author one (out of scope; dev-infra's module boundary is stable, no cross-cutting technology decision is being made here). The gap is logged as a follow-up candidate for when dev-infra grows its next non-trivial module.

## Rollback plan

Every artifact added by this change is independently revertable. The validator + its wiring is one conceptual unit; rolling back any piece does not force rollback of the others.

| Artifact                                                                       | Revert                          |
| ------------------------------------------------------------------------------ | ------------------------------- |
| `scripts/check-pin-sync.sh`                                                    | Delete file                     |
| `scripts/__tests__/check-pin-sync.bats`                                        | Delete file                     |
| `scripts/__tests__/test-helper.bash` (helper promotions)                       | `git checkout` to prior version |
| Makefile `.PHONY` / `check-pin-sync` target / `test-shell:` prereq edit        | `git checkout` to prior version |
| `scripts/__tests__/bats-wrapper.sh` allowlist edit                             | `git checkout` to prior version |
| `docs/dev-infra-audit/tickets/DIA-050.md` (reopened)                           | `git checkout` to prior version |

All rollbacks are file deletions or `git checkout` to prior versions. No existing production code, Dockerfile.dev, or `.mise.toml` content is modified. Rollback restores prior `test-shell` behavior (validator absent, prereq absent, DIA-050 re-OPEN) — the pre-change live-state. No data migrations. No side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra — the test verifies **source-file parity and structural integrity**, not business logic. A good test is one that fails loudly when `.mise.toml` and `Dockerfile.dev` drift apart or when either source is structurally defective, and passes quietly otherwise. We do NOT test the validator's parsing against arbitrary TOML / Dockerfile syntax (the validator is intentionally narrow: only the specific keys and patterns used by this repo). We do NOT fix either source file on drift — the validator only reports.

### 10-scenario matrix (T1–T10)

The verification covers every branch of the validator in a FAKE-mock bats suite (Gate A) plus a real-host seam (Gate B), mirroring the established `check-host-jq` / `check-tools` pattern.

#### Gate A — spec-logic bats (FAKE-mocked, no real toolchain required)

- **Location:** `scripts/__tests__/check-pin-sync.bats`
- **Pattern:** mirrors `check-tools.bats` — `install_fakes()`-style temp tree builder, fixture files planted under `$BATS_TEST_TMPDIR`, the script under test invoked against the fixture tree. Fixture helpers promoted to `scripts/__tests__/test-helper.bash` for reuse.
- **10-case matrix (T1–T10):**
  1. **T1 — all pins match** → exit 0, `ok: node 24.18.0 (parity)` + `ok: pnpm 10.33.0 (parity)` + `summary: 2 ok, 0 fail`.
  2. **T2 — single pin mismatch (node)** → exit 1, `fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0` + `summary: 1 ok, 1 fail`.
  3. **T3 — multiple pin mismatches (report-ALL, not fail-fast)** → exit 1, BOTH node and pnpm fail lines emitted + `summary: 0 ok, 2 fail`.
  4. **T4 — `.mise.toml` missing** → exit 2 (INFRA), `fail: source defective: .mise.toml not found at <path>` + summary.
  5. **T5 — `Dockerfile.dev` missing** → exit 2 (INFRA), `fail: source defective: Dockerfile.dev not found at <path>` + summary.
  6. **T6 — duplicate `[tools]` key in `.mise.toml` (INFRA ruling)** → exit 2 (INFRA), `fail: source defective: .mise.toml has duplicate key 'node' under [tools]` + summary. Exit 2 takes precedence over any mismatch that would otherwise be detected.
  7. **T7 — duplicate `ARG NODE_VERSION=...` in `Dockerfile.dev`** → exit 2 (INFRA, last-wins source is structurally suspicious) — per INFRA ruling, the validator refuses to operate on a Dockerfile with multiple ARG declarations for the same pin.
  8. **T8 — quote variations** (`node = "24.18.0"` vs `pnpm='10.33.0'` vs unquoted) → exit 0 after stripping. Verifies the parser's defensive normalization.
  9. **T9 — CRLF line endings** (Windows-authored fixture) → exit 0 after stripping. Verifies CR removal in both parsers.
  10. **T10 — whitespace variations** (extra spaces around `=`, leading/trailing spaces in values) → exit 0 after stripping.
- **Invariant:** bats NEVER reads the real repo `.mise.toml` or `Dockerfile.dev`. Every test operates on a fixture tree planted under `$BATS_TEST_TMPDIR`. (Exception: one structural-integrity test — see below — that asserts the real `.mise.toml` is well-formed. This is the S4-style assertion mirroring `check-tools.bats` line 137.)
- **Runs under:** `make test-shell` (via bats-wrapper auto-discovery; baseline → baseline+10).

#### Gate B — host-integration, owner-run

- **Runs manually:** `bash scripts/check-pin-sync.sh`, `make check-pin-sync`, `make test-shell`.
- **Pass criteria:** on the current repo (where both sources agree at 24.18.0 / 10.33.0), exit 0 with both ok lines + summary.
- **Gate B is the real-host seam** — the counterpart to Gate A's FAKE-mock seam.

### What we explicitly do NOT test

- `.mise.toml` TOML spec compliance beyond `[tools]` key extraction (out of scope; the validator is intentionally narrow).
- `Dockerfile.dev` Dockerfile spec compliance beyond `ARG <NAME>=<VALUE>` extraction.
- `tools/opencode-docker/Dockerfile` parity (DIA-050 scope boundary).
- `bun` / `uv` / `snip` / `mise` pin parity (DIA-050 scope boundary).
- Extra bats cases beyond the 10-case matrix (T1–T10 cover every branch; no 11th case).
- Real-tool version probes (the validator does not invoke `node --version` or `pnpm --version` — that is `check-tools.sh`'s job).

### Prior art in the codebase

- **Probe line shape + aggregate-summary pattern:** existing `scripts/check-host-jq.sh` (ok:/fail:/summary: line shapes; every exit-1/2 preceded by a remediation pointer).
- **Exit-code precedence (2>1>0):** mirrors `validate-skills.sh` (0 pass, 1 HARD failure, 2 infra error).
- **bats FAKE-mock pattern:** existing `scripts/__tests__/check-tools.bats` (`install_fakes()` + `setup_tree()` — these are the fixtures this change promotes to `test-helper.bash` for reuse).
- **Makefile prereq wiring pattern:** existing `test-shell: check-host-jq check-host-lsp test-opencode-docker` (line 99).
- **bats-wrapper `bash -n` allowlist pattern:** existing `scripts/__tests__/bats-wrapper.sh` lines 20-38.
- **DIA ticket closure pattern:** existing `docs/dev-infra-audit/tickets/archive/DIA-030.md` (DIA-030 closure by `volta-to-mise`).

### Test risk and mitigation

**Risk:** the fixture tree builder diverges from the real repo layout, masking a real-world parsing bug. **Mitigation:** one structural-integrity test (S4-style) asserts the real `.mise.toml` has `[tools]` + `node = "24.18.0"` + `pnpm = "10.33.0"` + header comment. This catches the most likely real-world drift (header removal, key rename) even though the behavioral tests run on fixtures.

**Risk:** the last-wins ARG semantics silently hides a duplicate ARG as "the second one wins". **Mitigation:** the INFRA ruling (T6/T7) — duplicate key = exit 2 = source defective. The validator refuses to operate on a Dockerfile with multiple ARG declarations for the same pin. This converts a silent wrong-answer into a loud failure.

**Risk:** the bash-3 compatibility constraint is violated (coder reaches for associative arrays to hold the parsed pin map). **Mitigation:** design.md §Design constraints mandates bash-3 compatibility; the parsed pin map is represented as a pair of shell variables (`MISE_NODE`, `MISE_PNPM`, `DOCKER_NODE`, `DOCKER_PNPM`) — no arrays, no indirection. Coder must verify with `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/check-pin-sync.sh` returning no matches.
