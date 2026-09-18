#!/usr/bin/env bash
# check-tools.sh — host-runnable tool integrity check (seam S2; `make check-tools`).
#
# WHY: the dev-container toolchain pins node/pnpm in TWO places — the
# Dockerfile.dev ARGs (tarball installs) and the repo-root .mise.toml (mise
# declares). This script verifies both agree and that the mise-managed tools are
# actually active on this machine. It is a developer convenience, NOT a CI gate
# (design.md §2.8: check-tools is deliberately NOT wired into test-shell or
# test-infra — it requires mise on PATH, which means the dev container or a host
# mise install, both out of scope for this change).
#
# Flag-a resolution (verified 2026-08-03 against mise v2026.8.0):
#   - `mise current <tool>` prints the .mise.toml pin even when the tool is NOT
#     mise-installed (it only reads the config), so it CANNOT prove the tool is
#     active — it is a declaration probe, not an activation probe.
#   - `mise which <tool>` exits 1 with "not a mise bin" when the tool is not
#     mise-installed — it IS the shim-active probe.
#   We therefore probe BOTH: `mise which` asserts the mise-managed tool exists,
#   and the version comparison (mise current vs <tool> --version vs pin) asserts
#   parity between the two sources of truth.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MISE_TOML="${ROOT_DIR}/.mise.toml"

# Hardcoded expected pins — mirrors .mise.toml + Dockerfile.dev ARGs (node
# 24.18.0, pnpm 10.33.0) at spec-author time (2026-08-03). There is no automated
# sync (see the .mise.toml header comment); bumping either version requires
# updating BOTH sources.
NODE_PIN="24.18.0"
PNPM_PIN="10.33.0"

# Step 1 — mise must be on PATH. mise ships inside the dev container, so running
# this on a host without mise is an expected error path, not a bug.
if ! command -v mise >/dev/null 2>&1; then
  echo "error: mise not found on PATH. Run 'make build' first — mise ships inside the dev container." >&2
  exit 1
fi

# Step 2 — the single source of tool pins must exist at the repo root.
if [ ! -f "${MISE_TOML}" ]; then
  echo "error: no .mise.toml at repo root (expected ${MISE_TOML})." >&2
  exit 1
fi

# Step 3 — trust + resolve the [tools] pins. `mise trust` is idempotent (exit 0
# on repeat); failing fast here avoids a later `mise install` that prompts or
# hangs on an untrusted config in a non-interactive shell.
if ! mise trust "${MISE_TOML}" >/dev/null 2>&1; then
  echo "error: mise trust failed for ${MISE_TOML}." >&2
  exit 1
fi
if ! mise install >/dev/null 2>&1; then
  echo "error: mise install failed — could not resolve the [tools] pins in ${MISE_TOML}." >&2
  exit 1
fi

# Step 4+5 — probe each pinned tool. Per flag-a resolution: `mise which` asserts
# the mise-managed tool is active (it fails loudly when not), and both the mise
# declaration (`mise current`) and the real binary on PATH (<tool> --version)
# must match the pin.
status=0
probe_tool() {
  local tool="$1"
  local expected="$2"
  local version_flag="$3" # --version; node prints a leading "v" that is stripped
  local strip_v="$4"      # 1 => strip the leading "v" from the real tool output

  if ! mise which "${tool}" >/dev/null 2>&1; then
    echo "fail: ${tool} shim not active (mise which ${tool} failed). Run 'mise install' then re-run check-tools." >&2
    status=1
    return
  fi

  local mise_current actual
  mise_current="$(mise current "${tool}" 2>/dev/null || true)"
  actual="$("${tool}" ${version_flag} 2>/dev/null | head -n1 || true)"
  if [ "${strip_v}" = "1" ]; then
    actual="${actual#v}"
  fi

  if [ "${mise_current}" != "${expected}" ]; then
    echo "fail: ${tool} — mise current is '${mise_current:-<empty>}', expected ${expected} (per .mise.toml / Dockerfile.dev ARG)." >&2
    status=1
    return
  fi
  if [ "${actual}" != "${expected}" ]; then
    echo "fail: ${tool} — ${tool} --version is '${actual:-<empty>}', expected ${expected}. The tool on PATH does not match the pinned version." >&2
    status=1
    return
  fi
  echo "ok: ${tool} ${actual} (mise-declared, version matches)"
}

probe_tool node "${NODE_PIN}" "--version" 1
probe_tool pnpm "${PNPM_PIN}" "--version" 0

exit "${status}"
