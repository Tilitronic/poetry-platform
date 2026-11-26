#!/usr/bin/env bash
# check-tools.sh — host-runnable tool integrity check (seam S2; `make check-tools`).
#
# WHY: the dev-container toolchain pins node/pnpm/bun in the repo-root
# .mise.toml (mise declares). This script verifies .mise.toml pins match the
# Dockerfile.dev ARGs and that the mise-managed tools are actually active on
# this machine. opencode is NOT a mise tool (DIA-261119-vioa: the image installs
# it from the Dockerfile.dev ARG), so its pin comes from the optional .mise.toml
# key when that key exists, else from the OPENCODE_VERSION ARG, and only its
# binary version is asserted. It is a developer convenience, NOT a CI gate
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
DOCKERFILE_DEV="${ROOT_DIR}/Dockerfile.dev"

# Read expected pins from .mise.toml [tools] section (the single source of
# truth). Each pin is extracted by grepping for the exact key and stripping
# the TOML syntax. Fails loud if the file is missing or a key is absent
# (opencode excepted: its key is optional, see parse_dockerfile_arg below).
parse_mise_pin() {
  local key="$1"
  grep -m1 "^${key}" "${MISE_TOML}" 2>/dev/null | sed "s/.*['\"]\\(.*\\)['\"].*/\\1/"
}

# Read a pin from the Dockerfile.dev ARG block - the fallback source for
# opencode, mirroring scripts/check-pin-sync.sh (DIA-261119-vioa). Empty output
# when the ARG is absent (the caller decides whether that is fatal).
parse_dockerfile_arg() {
  local arg="$1"
  grep -m1 "^[[:space:]]*ARG[[:space:]]\+${arg}=" "${DOCKERFILE_DEV}" 2>/dev/null \
    | sed "s/^[^=]*=//; s/['\"]//g; s/^[[:space:]]*//; s/[[:space:]]*$//" || true
}

NODE_PIN="$(parse_mise_pin node)" || { echo "error: cannot read node pin from ${MISE_TOML} (file missing or key absent)" >&2; exit 2; }
PNPM_PIN="$(parse_mise_pin pnpm)" || { echo "error: cannot read pnpm pin from ${MISE_TOML} (file missing or key absent)" >&2; exit 2; }
# opencode: optional .mise.toml key, else the Dockerfile.dev ARG. 1 = the pin is
# a mise declaration (probe mise too), 0 = image-installed (binary check only).
OPENCODE_PIN="$(parse_mise_pin opencode || true)"
OPENCODE_IS_MISE_TOOL=1
if [ -z "${OPENCODE_PIN}" ]; then
  OPENCODE_PIN="$(parse_dockerfile_arg OPENCODE_VERSION)"
  OPENCODE_IS_MISE_TOOL=0
fi
[ -n "${OPENCODE_PIN}" ] || { echo "error: cannot read opencode pin from ${MISE_TOML} (key absent) or ${DOCKERFILE_DEV} (ARG OPENCODE_VERSION absent)" >&2; exit 2; }
BUN_PIN="$(parse_mise_pin bun)" || { echo "error: cannot read bun pin from ${MISE_TOML} (file missing or key absent)" >&2; exit 2; }

# Step 1 — mise must be on PATH. mise ships inside the dev container, so running
# this on a host without mise is an expected error path, not a bug.
if ! command -v mise >/dev/null 2>&1; then
  echo "error: mise not found on PATH. Run 'make build' first — mise ships inside the dev container." >&2
  exit 1
fi

# Step 2 — trust + resolve the [tools] pins. `mise trust` is idempotent (exit 0
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

# Step 3 — probe each pinned tool. Per flag-a resolution: `mise which` asserts
# the mise-managed tool is active (it fails loudly when not), and both the mise
# declaration (`mise current`) and the real binary on PATH (<tool> --version)
# must match the pin. A pin resolved from the Dockerfile ARG has no mise
# declaration behind it, so only the binary is compared (5th arg 0).
status=0
probe_tool() {
  local tool="$1"
  local expected="$2"
  local version_flag="$3" # --version; node prints a leading "v" that is stripped
  local strip_v="$4"      # 0 = as printed; 1 = strip a leading "v";
                          # 2 = keep the first x.y.z token (opencode prints "opencode vX.Y.Z")
  local mise_managed="${5:-1}" # 0 => image-installed tool: skip the mise probes

  local mise_current actual
  if [ "${mise_managed}" = "1" ]; then
    if ! mise which "${tool}" >/dev/null 2>&1; then
      echo "fail: ${tool} shim not active (mise which ${tool} failed). Run 'mise install' then re-run check-tools." >&2
      status=1
      return
    fi

    mise_current="$(mise current "${tool}" 2>/dev/null || true)"
    if [ "${mise_current}" != "${expected}" ]; then
      echo "fail: ${tool} - mise current is '${mise_current:-<empty>}', expected ${expected} (per .mise.toml / Dockerfile.dev ARG)." >&2
      status=1
      return
    fi
  fi

  actual="$("${tool}" ${version_flag} 2>/dev/null | head -n1 || true)"
  case "${strip_v}" in
    1) actual="${actual#v}" ;;
    2) actual="$(printf '%s\n' "${actual}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)" ;;
  esac

  if [ "${actual}" != "${expected}" ]; then
    echo "fail: ${tool} — ${tool} --version is '${actual:-<empty>}', expected ${expected}. The tool on PATH does not match the pinned version." >&2
    status=1
    return
  fi
  local via="mise-declared"
  [ "${mise_managed}" = "1" ] || via="Dockerfile.dev ARG"
  echo "ok: ${tool} ${actual} (${via}, version matches)"
}

probe_tool node "${NODE_PIN}" "--version" 1
probe_tool pnpm "${PNPM_PIN}" "--version" 0
probe_tool opencode "${OPENCODE_PIN}" "--version" 2 "${OPENCODE_IS_MISE_TOOL}"
probe_tool bun "${BUN_PIN}" "--version" 0

exit "${status}"
