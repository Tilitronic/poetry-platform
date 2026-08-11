#!/usr/bin/env bash
# install-host-lsp.sh — installs the three language servers on the HOST.
#
# WHY: the dev container ships LS binaries (Dockerfile.dev), but developers
# editing outside the container (host mode, no Docker) have none. This script
# mirrors the container installs onto the host, pinned by the same single
# source of truth (scripts/lsp-versions.env). Idempotent: every tool is
# version-checked before install, so re-runs emit `already installed:` and
# skip. Exit codes are 0/1 only: 0 on full or partial success (rust-analyzer
# may be skipped via SKIP_RUST=1 or rustup-absent), 1 only on unrecoverable
# errors (env file missing, npm absent, EACCES, install failure). Requires
# bash 4+ and npm on PATH; rustup is OPTIONAL (rust-analyzer branch only).
# No sudo, no shell-rc mutation — npm installs into $HOME/.local by default
# (override with NPM_PREFIX).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/lsp-versions.env"

# --- Guard 1: the pin source of truth must exist and define all keys ---------
if [ ! -f "${ENV_FILE}" ]; then
  echo "error: ${ENV_FILE} not found. scripts/lsp-versions.env is the single source of truth for host LS versions; restore it (git checkout scripts/lsp-versions.env) and re-run. See docs/dev-infra/host-lsp-setup.md." >&2
  exit 1
fi
source "${ENV_FILE}"
for key in TYPESCRIPT_LANGUAGE_SERVER_VERSION PYRIGHT_VERSION RUST_ANALYZER_VERSION; do
  if [ -z "${!key:-}" ]; then
    echo "error: ${key} is not set in ${ENV_FILE}. Restore the key (single source of truth) and re-run. See docs/dev-infra/host-lsp-setup.md." >&2
    exit 1
  fi
done

# --- Guard 2: npm must be on PATH (TS/Python LS installs need it) -------------
if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not found on PATH. Install Node.js >=18 (https://nodejs.org) and re-run. See docs/dev-infra/host-lsp-setup.md." >&2
  exit 1
fi

NPM_PREFIX="${NPM_PREFIX:-$HOME/.local}"
SKIP_RUST="${SKIP_RUST:-0}"

# tool_version <tool>: prints the tool's version as the first dotted-number
# token from `--version`, or nothing. Works across output shapes: TS LS prints
# a bare version ("5.3.0"), pyright prints "pyright 1.1.411", rust-analyzer
# prints "rust-analyzer 1.97.1 (hash 2026-01-01)".
tool_version() {
  "${1}" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true
}

# install_npm_ls <tool> <version>: idempotent npm -g install into NPM_PREFIX.
# Emits `installed:` / `already installed:` lines; exits 1 with an EACCES
# remediation pointer (never sudo) or a generic failure pointer.
install_npm_ls() {
  local tool="$1"
  local version="$2"
  local method="npm -g --prefix ${NPM_PREFIX}"

  if command -v "${tool}" >/dev/null 2>&1 && [ "$(tool_version "${tool}")" = "${version}" ]; then
    echo "already installed: ${tool} ${version} (${method}; skipping)"
    return 0
  fi

  local err=""
  if ! err="$(npm install -g --prefix "${NPM_PREFIX}" "${tool}@${version}" 2>&1)"; then
    if printf '%s' "${err}" | grep -q EACCES; then
      echo "error: npm install failed with EACCES. See docs/dev-infra/host-lsp-setup.md for remediation (do NOT use sudo)." >&2
      exit 1
    fi
    echo "error: npm install of ${tool}@${version} failed: ${err}. See docs/dev-infra/host-lsp-setup.md." >&2
    exit 1
  fi

  echo "installed: ${tool} ${version} (${method})"
}

# install_rust_analyzer: rustup-conditional. SKIP_RUST=1 skips (stdout line);
# rustup absent without SKIP_RUST emits a stderr warning + returns 0 (partial
# install acceptable); rustup present installs via `rustup component add`.
install_rust_analyzer() {
  local version="${RUST_ANALYZER_VERSION}"

  if [ "${SKIP_RUST}" = "1" ]; then
    echo "skip: rust-analyzer (SKIP_RUST=1)"
    return 0
  fi

  if ! command -v rustup >/dev/null 2>&1; then
    echo "warning: rustup not found; rust-analyzer not installed. Install from https://rustup.rs or set SKIP_RUST=1 to suppress." >&2
    return 0
  fi

  if command -v rust-analyzer >/dev/null 2>&1 && [ "$(tool_version rust-analyzer)" = "${version}" ]; then
    echo "already installed: rust-analyzer ${version} (rustup; skipping)"
    return 0
  fi

  if ! rustup component add rust-analyzer; then
    echo "error: rustup component add rust-analyzer failed. See docs/dev-infra/host-lsp-setup.md." >&2
    exit 1
  fi

  echo "installed: rust-analyzer ${version} (rustup component add)"
}

install_npm_ls typescript-language-server "${TYPESCRIPT_LANGUAGE_SERVER_VERSION}"
install_npm_ls pyright "${PYRIGHT_VERSION}"
install_rust_analyzer
