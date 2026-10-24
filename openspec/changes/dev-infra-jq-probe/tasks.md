# Tasks: dev-infra-jq-probe

> **Proposal:** `openspec/changes/dev-infra-jq-probe/proposal.md`
> **Design:** `openspec/changes/dev-infra-jq-probe/design.md`
> **Companion to:** `openspec/changes/dev-infra-language-servers/` (the LSP probe established the pattern this change mirrors)
> **Workflow:** per `openspec/config.yaml`, the single task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one sub-step at a time.
> **Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity). §10 is N/A per Q1 (jq is a host-runtime dependency, not AI-tooling config).

## Dependency graph

```
T1 — jq host probe + FAKE-mock bats + Makefile wiring + bats-wrapper + docs fold-in
 │  creates scripts/check-host-jq.sh (~40L, new, bash-3 compatible)
 │  creates scripts/__tests__/check-host-jq.bats (~60L, new, 3-case FAKE-mock)
 │  edits Makefile: .PHONY (25), new target adjacent to check-host-lsp (80-87),
 │                  test-shell prereq (91): check-host-jq check-host-lsp test-opencode-docker
 │  edits scripts/__tests__/bats-wrapper.sh: bash -n allowlist (20-38)
 │  edits docs/dev-infra/host-lsp-setup.md: jq prereq + install section + troubleshooting
 │
 │  verification gate: bash -n, make check-host-jq, make test-shell, make test-infra,
 │                     make test-config, make test-skills, openspec validate (coder lane)
```

**Critical path:** T1 is the only task. The change is 5 files (2 new, 3 edits) and fits in a single context window.

**Rationale for single task:** the change is one conceptual unit — "add a standalone jq presence-and-functional probe, wire it into `make test-shell`, cover it with FAKE-mock bats, document it in the existing host-setup doc". Splitting into multiple tasks would create artificial boundaries with no independent demoability or verifiability (the probe has no value without its wiring; the wiring has no value without the probe; the bats test has no value without the probe; the docs have no value without the probe). This matches the `dev-infra-copilot-fixes-2` precedent of a single-task vertical slice for a tightly-coupled change.

---

## T1 — jq host probe + FAKE-mock bats + Makefile wiring + bats-wrapper + docs fold-in

**Blockers:** none
**Vertical slice:** the complete change — both new files, all three edits, the full verification gate. After T1, `make test-shell` passes with the new prereq + 3 new bats cases, `make check-host-jq` exits 0 on a host with functional `jq`, `make test-infra` passes end-to-end, and `host-lsp-setup.md` documents the jq prereq + Troubleshooting entry.

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `feat(dev-infra): add jq host probe wired into make test-shell (jq-gap resolution)`

### Sub-steps (implementation order within the single task)

> Per `openspec/config.yaml` apply guidance: "Write the failing test BEFORE any production code" and "Work one slice at a time". The sub-steps below are ordered RED-GREEN: the bats tests are written first (they fail because the probe script doesn't yet exist), then the probe is implemented until they pass, then the wiring and docs are added.

**Sub-step (a): Create the FAKE-mock bats test — `scripts/__tests__/check-host-jq.bats`**

- New file, ~60 lines.
- Header comment describing the FAKE-mock pattern + the 3-case matrix.
- `load test-helper` (existing helper from `scripts/__tests__/test-helper.bash`).
- `install_fakes()` plants a FAKE `jq` binary on `PATH` in a temp dir; `PATH=fakes:/usr/bin:/bin` isolates from system `jq`; env vars drive behavior:
  - **default (no env):** FAKE `jq` returns `2` for `jq -n '1+1'` (functional); reports a plausible version for `jq --version` (e.g., `jq-1.7.1`).
  - **`FAKE_JQ_BROKEN=1`:** FAKE `jq` returns `3` (or any non-2 value) for `jq -n '1+1'`, or exits non-zero. The probe must treat this as non-functional.
  - **`FAKE_JQ_MISSING` setup:** test case 2 does NOT call `install_fakes()` (or equivalently, `install_fakes()` skips planting the FAKE `jq`) — `command -v jq` fails because no `jq` is on PATH. (The env-var label is for test-setup clarity; the mechanism is the absence of the FAKE binary on PATH.)
- Three `@test` blocks (Q7, no extras):
  1. `@test "check-host-jq: functional jq on PATH -> exit 0 + ok line + summary"` — default FAKE setup; asserts exit 0, `ok: jq 1.7.1 (host, functional)` line, `summary: 1 ok, 0 fail` line.
  2. `@test "check-host-jq: jq missing from PATH -> exit 1 + fail line + summary"` — FAKE not planted; asserts exit 1, `fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md` line, `summary: 0 ok, 1 fail` line.
  3. `@test "check-host-jq: jq present but non-functional -> exit 1 + fail line + summary"` — `FAKE_JQ_BROKEN=1`; asserts exit 1, `fail: jq — present on PATH but non-functional (jq -n '1+1' did not return 2). Reinstall jq — see docs/dev-infra/host-lsp-setup.md` line, `summary: 0 ok, 1 fail` line.
- **Invariant:** no test shells a real `jq` binary. If any test invokes a system `jq`, the test is broken.
- **Status after this sub-step:** all 3 tests FAIL because `scripts/check-host-jq.sh` does not yet exist. This is the RED state.

**Sub-step (b): Implement `scripts/check-host-jq.sh`**

- New file, executable, ~40 lines, bash-3 compatible.
- Shebang: `#!/usr/bin/env bash`. Header comment explaining the probe's purpose and contract.
- `set -euo pipefail`.
- Presence check: `if ! command -v jq >/dev/null 2>&1; then ... fail + exit 1; fi`.
- Functional check: capture `jq -n '1+1'` output; compare to `2`; if not equal, fail + exit 1.
- ok path: emit `ok: jq <version> (host, functional)` where `<version>` is extracted from `jq --version` (e.g., `jq-1.7.1` → `1.7.1`).
- Aggregate summary: track `ok` and `fail` counters; emit `summary: N ok, M fail` on both ok and fail paths (ok→stdout, fail→stderr per Q6).
- Every exit-1 is preceded by exactly one `fail:` line + remediation pointer + summary. No bare `exit 1`.
- Bash-3 only: no associative arrays, no `${!var}`, no `[[ ... ]]`, no arrays, no `**`, no `printf -v`.
- **Status after this sub-step:** the 3 bats tests from sub-step (a) now PASS. GREEN.

**Sub-step (c): Edit `scripts/__tests__/bats-wrapper.sh`**

- Add `"$ROOT/scripts/check-host-jq.sh" \` to the `bash -n` syntax-check loop (lines 20-38), placed adjacent to `check-host-lsp.sh` per Q4.
- **Status after this sub-step:** `bash -n` covers the new probe script; any syntax error surfaces before the bats run.

**Sub-step (d): Edit `Makefile`**

- `.PHONY` line (25): append `check-host-jq` adjacent to `check-host-lsp` (jq before lsp per Q4). Result: `... check-tools check-host-jq check-host-lsp gen-jsconfig ...`.
- New target `check-host-jq` adjacent to `check-host-lsp` target (lines 80-87, jq before lsp):
  ```makefile
  # Host-runnable jq integrity check (scripts/check-host-jq.sh). Verifies jq is on
  # PATH and functional (jq -n '1+1' returns 2). Wired into test-shell so `make
  # test-shell` fails fast on host-tool drift — Gate B of the jq probe acceptance
  # (proposal.md). No version pin; presence + functional smoke only. See
  # docs/dev-infra/host-lsp-setup.md.
  check-host-jq:
  	bash scripts/check-host-jq.sh
  ```
- `test-shell:` prereq line (91): from `test-shell: check-host-lsp test-opencode-docker` to `test-shell: check-host-jq check-host-lsp test-opencode-docker` (alphabetical per Q4).
- **Status after this sub-step:** `make check-host-jq` runs the probe; `make test-shell` runs the probe as prereq before bats.

**Sub-step (e): Edit `docs/dev-infra/host-lsp-setup.md`**

- Add a `jq` prerequisite bullet in the Prerequisites section (after the existing bash/node/npm/rustup bullets):
  - `- **jq** on \`PATH\` — required by \`scripts/gen-jsconfig.sh\` (the workspace-layout → \`jsconfig.json\` generator). The \`scripts/check-host-jq.sh\` probe verifies both presence and functional correctness (\`jq -n '1+1'\` returns \`2\`). No version pin.`
- Add a new top-level section **before** "Step 1 — Install" (or as a peer section): `## jq — generic host dependency` with install-method-agnostic pointers:
  - ```bash
    # Debian/Ubuntu
    sudo apt install jq

    # macOS / Linux via Homebrew
    brew install jq

    # via mise (version manager)
    mise install jq
    ```

  - Note: the probe is install-method-agnostic; it checks the binary on PATH, not how it got there.

- Add a new Troubleshooting entry mirroring the existing `check-host-lsp` Q7a block:
  - `### \`make test-shell\` fails at \`check-host-jq\` on an unconfigured host`
  - Explanation: expected on hosts that have not installed `jq` yet (Gate B live-state consequence, not a bug).
  - Fix: run one of the install pointers above; post-install, `make test-shell` passes.
  - Link to the probe's fail-line remediation pointer.
- **Status after this sub-step:** the docs reflect the new prereq + Troubleshooting entry. No automated test; visual review by `@reviewer` (Standards axis).

**Sub-step (f): Verification gate**

The coder runs the following checks and reports the results in the handoff evidence:

1. **`bash -n scripts/check-host-jq.sh`** — syntax check. Exit 0 required.
2. **`make check-host-jq`** — real-host probe. On a host with functional `jq`: exit 0, `ok: jq <version> (host, functional)` + `summary: 1 ok, 0 fail`. On a host without `jq`: exit 1, fail line + pointer + summary. (Gate B — owner-runnable.)
3. **`make test-shell`** — full bats suite. Expected: exit 0, including the 3 new `check-host-jq.bats` cases. The prereq `check-host-jq` passes first (Gate B), then bats runs (Gate A) with the 3 new cases passing.
4. **`make test-infra`** — end-to-end dev-infra validation. Expected: exit 0 (jq probe + bats + Docker smoke + Python tests).
5. **`make test-config`** — OpenCode config validators. Expected: exit 0, unaffected by this change.
6. **`make test-skills`** — skill frontmatter validators. Expected: exit 0, unaffected by this change.
7. **`openspec validate dev-infra-jq-probe`** — routed through a coder lane (the openspec CLI is blocked in @openspec-plan's lane via permission shadowing). The orchestrator dispatches a coder lane to run this validation; the result feeds back into T1's verification evidence. Exit 0 required.
8. **Visual inspection of `docs/dev-infra/host-lsp-setup.md`** — the coder confirms the `jq` prereq + install section + Troubleshooting entry are present and correctly worded.
9. **Bash-3 compatibility check** — the coder confirms `scripts/check-host-jq.sh` contains no bash-4-only constructs (no associative arrays, no `${!var}`, no `[[ ... ]]`, no arrays, no `**`, no `printf -v`). A `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/check-host-jq.sh` should return no matches.

### Acceptance criteria (user perspective)

1. `bash scripts/check-host-jq.sh` on a host with functional `jq` exits 0 with `ok: jq <version> (host, functional)` + `summary: 1 ok, 0 fail` (both to stdout).
2. `bash scripts/check-host-jq.sh` on a host without `jq` exits 1 with the missing-`jq` `fail:` line + remediation pointer + `summary: 0 ok, 1 fail` (all to stderr).
3. `bash scripts/check-host-jq.sh` on a host with non-functional `jq` (present but `jq -n '1+1'` does not return 2) exits 1 with the non-functional `fail:` line + remediation pointer + `summary: 0 ok, 1 fail` (all to stderr).
4. `make check-host-jq` runs the probe and surfaces the same exit code + lines as direct invocation.
5. `make test-shell` runs `check-host-jq` as prereq BEFORE bats; bats auto-discovery runs `check-host-jq.bats` with 3 cases. Post-install: all pass. Pre-install: fails at the prereq.
6. `make test-infra` passes end-to-end post-install (probe + bats + Docker smoke + Python tests).
7. `make test-config` and `make test-skills` are unaffected (no regressions from this change).
8. `scripts/check-host-jq.sh` is bash-3 compatible (no bash-4-only constructs).
9. `docs/dev-infra/host-lsp-setup.md` documents the `jq` prereq + install-method-agnostic pointers + Troubleshooting entry mirroring the `check-host-lsp` Q7a block.
10. `openspec validate dev-infra-jq-probe` passes (coder lane).

### Testing

- **RED-GREEN:** sub-step (a) writes the failing tests first (RED — the probe script doesn't yet exist). Sub-step (b) applies the production fix (GREEN — the 3 bats cases pass). Sub-steps (c), (d), (e) add the wiring and docs (no behavioral change to the probe; the existing bats tests continue to pass). Sub-step (f) is the verification gate.
- **FAKE-mock strategy:** the `install_fakes()` function plants a FAKE `jq` on `PATH` in a temp dir; `PATH=fakes:/usr/bin:/bin` isolates from system `jq`. Default FAKE `jq` returns `2` for `jq -n '1+1'` and a plausible version for `jq --version`. `FAKE_JQ_BROKEN=1` makes the FAKE `jq` return non-2. Test case 2 does not plant the FAKE (absence = missing).
- **Invariant enforcement:** no test shells a real `jq` binary. The coder must verify this by inspection (no automated enforcement beyond the PATH isolation).

### Verification evidence (coder handoff to @reviewer)

The coder's handoff must include:

- `bash -n scripts/check-host-jq.sh` exit code (expected: 0).
- `make check-host-jq` exit code + probe output (expected: exit 0 + `ok: jq <version> (host, functional)` + `summary: 1 ok, 0 fail` on a host with functional `jq`). If the host lacks `jq`, the coder installs it first (per the docs) or runs the "missing" branch verification explicitly.
- `make test-shell` exit code + summary line (expected: exit 0, test count increases by 3 from the baseline). If the count differs, the coder explains the delta.
- `make test-infra` exit code + summary line (expected: exit 0).
- `make test-config` exit code (expected: 0, unaffected).
- `make test-skills` exit code (expected: 0, unaffected).
- `openspec validate dev-infra-jq-probe` exit code (coder lane — expected: 0).
- Bash-3 compliance confirmation: `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/check-host-jq.sh` returns no matches.
- Confirmation that `docs/dev-infra/host-lsp-setup.md` contains the `jq` prereq bullet + install section + Troubleshooting entry (coder's visual inspection; one-line grep confirmation per section).

---

## Out of scope for this task

- **`gen-jsconfig.sh` / `gen-jsconfig.bats` changes** — explicitly deferred per Q1.
- **`host-toolchain.md` creation** — explicitly deferred per Q1 (jq folds into existing `host-lsp-setup.md`).
- **`Dockerfile.dev` edits** — explicitly deferred per Q1 (container already ships `jq`).
- **§10 routing** — explicitly N/A per Q1.
- **`jq` version pin** — explicitly deferred per Q1/Q2.
- **`check-host-lsp.sh` rename** — explicitly deferred per Q1.
- **Any `.sdd/` document authoring** — gap flagged in proposal, not filled here.
- **Extra bats cases beyond the 3-case matrix** — explicitly excluded per Q7.
- **Windows host support** — out of scope; Windows developers use the dev container.
- **CI host-jq enforcement** — CI runs in the dev container; probe is a developer-convenience gate.

## Verification gate summary

| Gate                                    | When         | Required                                                             |
| --------------------------------------- | ------------ | -------------------------------------------------------------------- |
| `bash -n scripts/check-host-jq.sh`      | Sub-step (f) | Exit 0 (syntax valid, bash-3 compatible)                             |
| `make check-host-jq`                    | Sub-step (f) | Exit 0 on host with functional `jq` (Gate B real-host)               |
| `make test-shell`                       | Sub-step (f) | Exit 0; includes 3 new `check-host-jq.bats` cases (Gate A FAKE-mock) |
| `make test-infra`                       | Sub-step (f) | Exit 0 (end-to-end dev-infra)                                        |
| `make test-config`                      | Sub-step (f) | Exit 0 (unaffected)                                                  |
| `make test-skills`                      | Sub-step (f) | Exit 0 (unaffected)                                                  |
| `openspec validate dev-infra-jq-probe`  | Sub-step (f) | Exit 0 (coder lane — openspec CLI blocked in @openspec-plan's lane)  |
| Bash-3 compliance grep                  | Sub-step (f) | No matches for `declare -A\|\$\{!\|\[\[ \|\*\*\|printf -v`           |
| Visual: `host-lsp-setup.md` jq sections | Sub-step (f) | `jq` prereq + install section + Troubleshooting entry present        |
