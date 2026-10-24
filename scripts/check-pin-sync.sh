#!/usr/bin/env bash
# check-pin-sync.sh — .mise.toml ↔ Dockerfile.dev pin-parity validator (Gate B).
# WHY: node/pnpm/opencode/bun pins live in .mise.toml [tools] (single source of
# truth, ADR 11 line 99) and in the ARG declarations of Dockerfile.dev; asserts
# parity (4 comparisons: 4 pins x 1 Dockerfile), reads only. MISE_VERSION
# parity is out of scope. Legacy tools/opencode-docker/Dockerfile removed
# (DIA-260824-8k62 PHASE 3 retirement).
# Exit precedence 2>1>0: 0 match; 1 parity violated; 2 INFRA (missing/dup). Bash-3.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MISE_TOML="${ROOT_DIR}/.mise.toml"
DOCKERFILE_DEV="${ROOT_DIR}/Dockerfile.dev"

ok=0 fail=0
strip_value() { # remove quotes, CR, surrounding whitespace
  printf '%s' "$1" | tr -d '\r' | sed "s/['\"]//g" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

infra_summary() { # INFRA summary on both streams, exit 2
  echo "summary: ${ok} ok, ${fail} fail (infra)"
  echo "summary: ${ok} ok, ${fail} fail (infra)" >&2
  exit 2
}

# parse_reference <file>: [tools] node/pnpm/opencode/bun ->
# MISE_NODE/MISE_PNPM/MISE_OPENCODE/MISE_BUN. Dup => INFRA. Missing key => INFRA.
parse_reference() {
  local file="$1" tools node_count pnpm_count opencode_count bun_count
  tools="$(awk '/^\[tools\]/ { in_tools=1; next } /^\[/ { in_tools=0 } in_tools { print }' "$file")"
  node_count="$(printf '%s\n' "$tools" | grep -c '^node[[:space:]]*=' || true)"
  pnpm_count="$(printf '%s\n' "$tools" | grep -c '^pnpm[[:space:]]*=' || true)"
  opencode_count="$(printf '%s\n' "$tools" | grep -c '^opencode[[:space:]]*=' || true)"
  bun_count="$(printf '%s\n' "$tools" | grep -c '^bun[[:space:]]*=' || true)"
  [ "${node_count}" -le 1 ] || { echo "fail: source defective: .mise.toml has duplicate key 'node' under [tools]" >&2; return 1; }
  [ "${pnpm_count}" -le 1 ] || { echo "fail: source defective: .mise.toml has duplicate key 'pnpm' under [tools]" >&2; return 1; }
  [ "${opencode_count}" -le 1 ] || { echo "fail: source defective: .mise.toml has duplicate key 'opencode' under [tools]" >&2; return 1; }
  [ "${bun_count}" -le 1 ] || { echo "fail: source defective: .mise.toml has duplicate key 'bun' under [tools]" >&2; return 1; }
  [ "${node_count}" -eq 1 ] || { echo "fail: source defective: .mise.toml is missing key 'node' under [tools]" >&2; return 1; }
  [ "${pnpm_count}" -eq 1 ] || { echo "fail: source defective: .mise.toml is missing key 'pnpm' under [tools]" >&2; return 1; }
  [ "${opencode_count}" -eq 1 ] || { echo "fail: source defective: .mise.toml is missing key 'opencode' under [tools]" >&2; return 1; }
  [ "${bun_count}" -eq 1 ] || { echo "fail: source defective: .mise.toml is missing key 'bun' under [tools]" >&2; return 1; }
  MISE_NODE="$(strip_value "$(printf '%s\n' "$tools" | grep -m1 '^node[[:space:]]*=' | sed 's/^node[[:space:]]*=[[:space:]]*//' || true)")"
  MISE_PNPM="$(strip_value "$(printf '%s\n' "$tools" | grep -m1 '^pnpm[[:space:]]*=' | sed 's/^pnpm[[:space:]]*=[[:space:]]*//' || true)")"
  MISE_OPENCODE="$(strip_value "$(printf '%s\n' "$tools" | grep -m1 '^opencode[[:space:]]*=' | sed 's/^opencode[[:space:]]*=[[:space:]]*//' || true)")"
  MISE_BUN="$(strip_value "$(printf '%s\n' "$tools" | grep -m1 '^bun[[:space:]]*=' | sed 's/^bun[[:space:]]*=[[:space:]]*//' || true)")"
}

# parse_dockerfile <file> <label>: ARG NODE_VERSION=/PNPM_VERSION=/OPENCODE_VERSION=/BUN_VERSION= ->
# DOCKER_NODE/DOCKER_PNPM/DOCKER_OPENCODE/DOCKER_BUN. Dup/missing ARG is INFRA.
parse_dockerfile() {
  local file="$1" label="$2" node_count pnpm_count opencode_count bun_count
  node_count="$(grep -cE '^[[:space:]]*ARG[[:space:]]+NODE_VERSION=' "$file" || true)"
  pnpm_count="$(grep -cE '^[[:space:]]*ARG[[:space:]]+PNPM_VERSION=' "$file" || true)"
  opencode_count="$(grep -cE '^[[:space:]]*ARG[[:space:]]+OPENCODE_VERSION=' "$file" || true)"
  bun_count="$(grep -cE '^[[:space:]]*ARG[[:space:]]+BUN_VERSION=' "$file" || true)"
  [ "${node_count}" -le 1 ] || { echo "fail: source defective: ${label} has duplicate ARG 'NODE_VERSION'" >&2; return 1; }
  [ "${pnpm_count}" -le 1 ] || { echo "fail: source defective: ${label} has duplicate ARG 'PNPM_VERSION'" >&2; return 1; }
  [ "${opencode_count}" -le 1 ] || { echo "fail: source defective: ${label} has duplicate ARG 'OPENCODE_VERSION'" >&2; return 1; }
  [ "${bun_count}" -le 1 ] || { echo "fail: source defective: ${label} has duplicate ARG 'BUN_VERSION'" >&2; return 1; }
  [ "${node_count}" -eq 1 ] || { echo "fail: source defective: ${label} is missing ARG 'NODE_VERSION'" >&2; return 1; }
  [ "${pnpm_count}" -eq 1 ] || { echo "fail: source defective: ${label} is missing ARG 'PNPM_VERSION'" >&2; return 1; }
  [ "${opencode_count}" -eq 1 ] || { echo "fail: source defective: ${label} is missing ARG 'OPENCODE_VERSION'" >&2; return 1; }
  [ "${bun_count}" -eq 1 ] || { echo "fail: source defective: ${label} is missing ARG 'BUN_VERSION'" >&2; return 1; }
  DOCKER_NODE="$(strip_value "$(grep -m1 '^[[:space:]]*ARG[[:space:]]\+NODE_VERSION=' "$file" | sed 's/^[^=]*=//' || true)")"
  DOCKER_PNPM="$(strip_value "$(grep -m1 '^[[:space:]]*ARG[[:space:]]\+PNPM_VERSION=' "$file" | sed 's/^[^=]*=//' || true)")"
  DOCKER_OPENCODE="$(strip_value "$(grep -m1 '^[[:space:]]*ARG[[:space:]]\+OPENCODE_VERSION=' "$file" | sed 's/^[^=]*=//' || true)")"
  DOCKER_BUN="$(strip_value "$(grep -m1 '^[[:space:]]*ARG[[:space:]]\+BUN_VERSION=' "$file" | sed 's/^[^=]*=//' || true)")"
}

# compare <tool> <mise_val> <docker_val> <label>: normalize both, emit ok:/fail:
# carrying the source label (report-ALL, never fail-fast).
compare() {
  local tool="$1" mise_val="$(strip_value "$2")" docker_val="$(strip_value "$3")" label="$4"
  if [ "${mise_val}" = "${docker_val}" ]; then
    echo "ok: ${tool} ${docker_val} (parity @ ${label})"
    ok=$((ok + 1))
    return 0
  fi
  echo "fail: ${tool} — .mise.toml=${mise_val} ${label}=${docker_val}" >&2
  fail=$((fail + 1))
  return 1
}

# aggregate: summary on BOTH streams; exit 0 iff no mismatches.
aggregate() {
  echo "summary: ${ok} ok, ${fail} fail"
  echo "summary: ${ok} ok, ${fail} fail" >&2
  [ "${fail}" -eq 0 ] || exit 1
  exit 0
}

# Preflight: sources must exist before parsing (INFRA short-circuit).
[ -f "${MISE_TOML}" ] || { echo "fail: source defective: .mise.toml not found at ${MISE_TOML}" >&2; infra_summary; }
[ -f "${DOCKERFILE_DEV}" ] || { echo "fail: source defective: Dockerfile.dev not found at ${DOCKERFILE_DEV}" >&2; infra_summary; }

parse_reference "${MISE_TOML}" || infra_summary
parse_dockerfile "${DOCKERFILE_DEV}" "Dockerfile.dev" || infra_summary

compare node "${MISE_NODE}" "${DOCKER_NODE}" "Dockerfile.dev" || true
compare pnpm "${MISE_PNPM}" "${DOCKER_PNPM}" "Dockerfile.dev" || true
compare opencode "${MISE_OPENCODE}" "${DOCKER_OPENCODE}" "Dockerfile.dev" || true
compare bun "${MISE_BUN}" "${DOCKER_BUN}" "Dockerfile.dev" || true
aggregate
