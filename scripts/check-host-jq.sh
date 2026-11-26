#!/usr/bin/env bash
# check-host-jq.sh — host-runnable jq presence + functional probe (Gate B).
#
# WHY: scripts/gen-jsconfig.sh invokes jq to emit jsconfig.json, but a fresh
# host has no guarantee jq is installed (the dev container ships it). This
# probe is wired into `make test-shell` as a prerequisite so a missing or
# broken jq fails loudly BEFORE any bats run — mirroring check-host-lsp.sh but
# with no version pin (none exists in the repo; presence + functional smoke
# only). Exit 0 iff jq is on PATH and `jq -n '1+1'` returns 2; exit 1
# otherwise with exactly one fail: line + remediation pointer + summary (no
# bare exit 1). Bash-3 compatible (macOS stock bash 3.2) — no bash-4-only
# constructs (no associative arrays, no indirect expansion, no test-bracket
# bashisms, no arrays, no globstar, no printf into variables). Runs from any
# cwd; reads no env vars (the FAKE_JQ_* vars in the bats tests drive the FAKE
# binary, not this probe).
set -euo pipefail

ok=0
fail=0
status=0

# Presence: `command -v` also handles non-executable files on PATH (Q2).
if ! command -v jq >/dev/null 2>&1; then
  echo "fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md" >&2
  fail=$((fail + 1))
  status=1
# Functional smoke: `jq -n '1+1'` must evaluate to 2. A present-but-broken jq
# (corrupt install, wrong binary shadowing PATH) fails here, not at
# gen-jsconfig. Any invocation anomaly (wrong args, silent corruption) is
# non-functional — this branch also covers Q7's rejected 4th case.
elif [ "$(jq -n '1+1' 2>/dev/null)" != "2" ]; then
  echo "fail: jq — present on PATH but non-functional (jq -n '1+1' did not return 2). Reinstall jq — see docs/dev-infra/host-lsp-setup.md" >&2
  fail=$((fail + 1))
  status=1
else
  # Informational version only (no pin): first dotted token of `jq --version`
  # output, mirroring check-host-lsp.sh's extraction for the LS binaries
  # (works across output shapes: "jq-1.7.1" -> "1.7.1").
  version="$(jq --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)"
  if [ -z "${version}" ]; then
    version="<unknown>"
  fi
  echo "ok: jq ${version} (host, functional)"
  ok=$((ok + 1))
fi

# Aggregate summary: stdout on pass, stderr on fail (mirrors check-host-lsp.sh).
if [ "${fail}" -gt 0 ]; then
  echo "summary: ${ok} ok, ${fail} fail — see above" >&2
else
  echo "summary: ${ok} ok, ${fail} fail"
fi
exit "${status}"
