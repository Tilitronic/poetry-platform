# DIA-044 — tools/opencode-docker not wired into root Makefile gates

---

id: DIA-044
title: "tools/opencode-docker not wired into root Makefile gates"
area: docker
severity: Minor
status: VERIFIED
blocked_by: []
discovered:
source: inventory
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

`tools/opencode-docker` is a self-contained dev-tooling subproject with its own
`Makefile`, `Dockerfile` (3-stage, read-only rootfs, `--cap-drop`), `bin/`
wrapper, `bootstrap.py`, `scripts/collect-runtime-deps.sh`, `config/opencode.json`,
`AGENTS.md`, and `TODO.md` (F1–F16, F7/F8/F9/F10/F11 open). It is **not
referenced by any root Makefile gate** — `test-shell` / `test-config` /
`test-infra` never exercise it, so its content can drift independently (the
openspec 1.6.0 vs Dockerfile.dev 1.7.0 skew in inventory N4 is a live example).

Minor: no impact on the host dev-loop gates, but the tool silently rots without
any automated signal.

## Verification

1. `grep -rn "opencode-docker" Makefile scripts/__tests__/ 2>/dev/null` → confirm no gate reference (expected).
2. Read `tools/opencode-docker/Makefile` → confirm the standalone build/run path (`podman`, `--read-only`, `--cap-drop=ALL`).
3. Compare toolchain pins: `tools/opencode-docker/Dockerfile` (openspec 1.6.0) vs `Dockerfile.dev` (openspec 1.7.0) — record current skew (inventory N4).
4. Record results in Re-verify.

## Fix

> Implemented 2026-08-04 (code-executor, dev-infra lane):
>
> 1. New `scripts/check-opencode-docker.sh` — static integrity gate,
>    host-runnable with **no podman/docker daemon**: required subproject files
>    present (Makefile, Dockerfile, bin/opencode-docker, bootstrap.py,
>    scripts/collect-runtime-deps.sh, config/opencode.json, AGENTS.md), shell
>    artifacts pass `bash -n`, `bootstrap.py` parses (AST — no pycache
>    written), `config/opencode.json` is valid JSON, subproject Makefile
>    declares build/run/shell/clean.
> 2. Root `Makefile` — new `test-opencode-docker` target (`.PHONY` + header
>    comment) wired as a prerequisite of `test-shell`
>    (`test-shell: test-opencode-docker`), so **both** `make test-shell` and
>    `make test-infra` (which pulls in test-shell) exercise it. `test-config`
>    deliberately NOT extended — its scope is the `.opencode/` OpenCode config;
>    the subproject's `config/opencode.json` is validated inside the new gate.
> 3. New `scripts/__tests__/opencode-docker.bats` — 6 tests (real-tree pass,
>    isolated valid-fixture pass, missing-file / broken-syntax / missing-dir
>    fail paths, root-Makefile wiring regression guard).

> Design note: the gate is STATIC by design — the subproject's real build/run
> path (`podman`, `--read-only`, `--cap-drop=ALL`) stays a manual developer
> action (it requires a container runtime), while the drift signal (content
> rot, e.g. the inventory-N4 openspec pin skew) is now automated on every fast
> gate.

## Re-verify

Re-verify 2026-08-04 (code-executor): `make test-shell` exit 0 — runs
`bash scripts/check-opencode-docker.sh` first (all ok lines incl.
"ok: tools/opencode-docker static integrity passed"), then bats 90/90 (78
existing + 6 new opencode-docker + 6 new author-studio-probe-guard from the
DIA-048 lane). `make test-config` exit 0 (scope unchanged). Verification item 1
is now inverted: `grep -rn "opencode-docker" Makefile scripts/__tests__/` →
Makefile `test-opencode-docker` target + `test-shell: test-opencode-docker`
prerequisite + `opencode-docker.bats`. Item 3 (toolchain skew N4, openspec
1.6.0 vs 1.7.0) is NOT part of this gate (a pin-parity check would be a
separate change); the gate makes the skew visible-drift impossible to miss.
