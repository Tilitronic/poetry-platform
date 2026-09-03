#!/usr/bin/env bash
# check-opencode-docker.sh — static integrity gate for tools/opencode-docker
# (`make test-opencode-docker`, wired into `make test-shell`; DIA-044).
#
# WHY: tools/opencode-docker is a self-contained dev-tooling subproject with its
# own Makefile/Dockerfile/bin wrapper/bootstrap.py/config, and it was NOT
# referenced by any root Makefile gate — test-shell / test-config / test-infra
# never exercised it, so its content could drift independently (the openspec
# 1.6.0 vs Dockerfile.dev 1.7.0 skew in inventory N4 is a live example).
#
# This gate is deliberately STATIC and host-runnable: it needs no podman/docker
# daemon (the subproject's real build/run path is exercised manually via its own
# Makefile), so it runs on every `make test-shell` — and therefore on
# `make test-infra`, which pulls in test-shell — without slowing the gate or
# requiring a container runtime.
#
# Checks: required files exist, shell artifacts pass bash -n, bootstrap.py
# parses (AST — no pycache written), config/opencode.json is valid JSON, and the
# subproject Makefile declares its canonical targets.
#
# Exit codes: 0 all pass, 1 any check failed, 2 infra error (bad tree layout).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCD="$ROOT_DIR/tools/opencode-docker"

if [ ! -d "$OCD" ]; then
  echo "error: tools/opencode-docker directory missing (expected $OCD)." >&2
  exit 2
fi

status=0
fail() { echo "fail: $1" >&2; status=1; }

# --- 1. Required subproject files present --------------------------------
for f in Makefile Dockerfile bin/opencode-docker bootstrap.py scripts/collect-runtime-deps.sh config/opencode.json AGENTS.md; do
  if [ ! -e "$OCD/$f" ]; then
    fail "tools/opencode-docker/$f missing"
  fi
done
[ "$status" = "0" ] && echo "ok: required subproject files present"

# --- 2. Shell artifacts pass bash -n -------------------------------------
for s in bin/opencode-docker scripts/collect-runtime-deps.sh; do
  if [ -e "$OCD/$s" ] && ! bash -n "$OCD/$s"; then
    fail "bash -n $s failed"
  fi
done
[ "$status" = "0" ] && echo "ok: shell artifacts pass bash -n"

# --- 3. bootstrap.py parses (AST parse, no pycache written) --------------
if command -v python3 >/dev/null 2>&1; then
  if [ -e "$OCD/bootstrap.py" ] && ! python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$OCD/bootstrap.py"; then
    fail "bootstrap.py failed Python syntax parse"
  fi
  [ "$status" = "0" ] && echo "ok: bootstrap.py parses (AST)"
else
  echo "warn: python3 not on PATH; skipping bootstrap.py + JSON parse"
fi

# --- 4. config/opencode.json is valid JSON -------------------------------
if command -v python3 >/dev/null 2>&1; then
  if [ -e "$OCD/config/opencode.json" ] && ! python3 -c 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$OCD/config/opencode.json"; then
    fail "config/opencode.json is not valid JSON"
  fi
  [ "$status" = "0" ] && echo "ok: config/opencode.json is valid JSON"
fi

# --- 5. Subproject Makefile declares the canonical targets ---------------
if [ -e "$OCD/Makefile" ]; then
  for t in build run shell clean; do
    if ! grep -qE "^${t}:" "$OCD/Makefile"; then
      fail "tools/opencode-docker/Makefile missing target '$t'"
    fi
  done
  [ "$status" = "0" ] && echo "ok: subproject Makefile declares build/run/shell/clean"
fi

if [ "$status" = "0" ]; then
  echo "ok: tools/opencode-docker static integrity passed"
fi
exit "$status"
