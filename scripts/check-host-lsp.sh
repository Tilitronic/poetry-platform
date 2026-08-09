#!/usr/bin/env bash
# check-host-lsp.sh — host-runnable language-server integrity probe (Gate B).
#
# WHY: mirrors scripts/check-tools.sh (ok:/fail:/skip: line shape) for the
# three language servers that scripts/install-host-lsp.sh installs on the host.
# It is wired into `make test-shell` as a prerequisite so host-tool drift fails
# loudly BEFORE any bats run. Aggregate probe: all three tools are probed and
# all failures reported before any exit — one run gives the complete picture.
# Exit 0 if all pass (SKIP_RUST=1 is neutral); exit 1 if any fail. Every
# exit-1 is preceded by per-failure remediation pointers (no bare exit 1).
# Requires bash 4+; runs from any cwd (lsp-versions.env resolved relative to
# this script). The probe is install-method-agnostic: it checks the binary on
# PATH and its --version, not how it was installed (rustup or apt).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/lsp-versions.env"

# --- Guard: the pin source of truth must exist and define all keys -----------
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

SKIP_RUST="${SKIP_RUST:-0}"

ok=0
fail=0
skip=0
status=0

# probe_tool <tool> <pinned>: emits ok:/fail: for one tool and aggregates.
probe_tool() {
  local tool="$1"
  local pinned="$2"

  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "fail: ${tool} — not found on PATH. Run scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)" >&2
    fail=$((fail + 1))
    status=1
    return
  fi

  # Extract the first dotted-number token from `--version` output — works
  # across output shapes (TS LS: "5.3.0"; pyright: "pyright 1.1.411";
  # rust-analyzer: "rust-analyzer 1.83.0 (hash 2026-01-01)").
  local actual
  actual="$("${tool}" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)"
  if [ "${actual}" != "${pinned}" ]; then
    echo "fail: ${tool} — ${actual:-<unknown>} on PATH, expected ${pinned}. Run scripts/install-host-lsp.sh" >&2
    fail=$((fail + 1))
    status=1
    return
  fi

  echo "ok: ${tool} ${pinned} (host, version matches scripts/lsp-versions.env)"
  ok=$((ok + 1))
}

probe_tool typescript-language-server "${TYPESCRIPT_LANGUAGE_SERVER_VERSION}"
probe_tool pyright "${PYRIGHT_VERSION}"
if [ "${SKIP_RUST}" = "1" ]; then
  echo "skip: rust-analyzer (SKIP_RUST=1 set; not required for TS/Python LSP work)"
  skip=$((skip + 1))
else
  probe_tool rust-analyzer "${RUST_ANALYZER_VERSION}"
fi

if [ "${fail}" -gt 0 ]; then
  echo "summary: ${ok} ok, ${fail} fail, ${skip} skip — see above"
else
  echo "summary: ${ok} ok, ${fail} fail, ${skip} skip"
fi
exit "${status}"
