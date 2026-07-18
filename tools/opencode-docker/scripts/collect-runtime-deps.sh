#!/usr/bin/env bash
set -euo pipefail
trap 'echo "=== FAILED at line $LINENO (exit code $?) ===" >&2' ERR

ROOTFS="$1"; shift
mkdir -p "$ROOTFS"

declare -A PROCESSED=()
declare -A CP_VISITED=()

_cp_skip_visited=0

cp_with_parents() {
  local src="$1"
  local real_src; real_src="$(readlink -f "$src" 2>/dev/null)" || real_src="$src"

  # Skip if already processed (but not when following a symlink from caller)
  if [ "$_cp_skip_visited" -eq 0 ] && [ -n "${CP_VISITED[$real_src]:-}" ]; then
    return
  fi
  _cp_skip_visited=0

  local dst="${ROOTFS}${src}"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$src" ]; then
    cp -a "$src" "$dst"
    local resolved; resolved="$(readlink -f "$src")"
    if [ -n "$resolved" ] && [ -e "$resolved" ]; then
      [ -z "${CP_VISITED[$resolved]:-}" ] && { CP_VISITED[$resolved]=1; _cp_skip_visited=1; cp_with_parents "$resolved"; }
    fi
  elif [ -d "$src" ]; then
    cp -a "$src/." "$dst"
  else
    CP_VISITED[$real_src]=1
    cp -a "$src" "$dst"
  fi
}

collect_ldd() {
  while IFS= read -r line; do
    for token in $line; do
      [[ "$token" == /* ]] || continue
      local p="${token%%(*}"
      p="${p%)}"
      [ -e "$p" ] && cp_with_parents "$p"
    done
  done < <(ldd "$1" 2>/dev/null || true)
}

process() {
  local resolved; resolved="$(readlink -f "$1")"
  [ -n "${PROCESSED[$resolved]:-}" ] && return
  PROCESSED[$resolved]=1
  cp_with_parents "$1"
  collect_ldd "$1"
  local first; IFS= read -r first < "$1" 2>/dev/null || true
  if [[ "$first" == '#!'* ]]; then
    local interp="${first#\#!}"; interp="${interp%% *}"
    [ -e "$interp" ] && process "$interp"
  fi
  local name; name="$(basename "$resolved")"
  case "$name" in python|python3|python3.*) collect_python "$resolved" ;; esac
  case "$name" in node|nodejs|npm|npx|corepack|pnpm|bun) collect_node ;; esac
}

collect_python() {
  while IFS= read -r p; do
    [ -n "$p" ] && [ -e "$p" ] && cp_with_parents "$p"
  done < <("$1" -c "
import os, sysconfig, site
paths = set()
for k in ('stdlib','platstdlib','purelib','platlib'):
    v = sysconfig.get_paths().get(k)
    if v: paths.add(v)
for e in __import__('sys').path:
    if 'site-packages' in e or 'dist-packages' in e:
        paths.add(e)
func = getattr(site, 'getsitepackages', None)
if callable(func):
    for e in func(): paths.add(e)
for p in sorted(paths):
    print(p)
" 2>/dev/null || true)
}

collect_node() {
  # ponytail: dash needed for Node.js child_process.spawn; negligible size, huge convenience
  [ -n "${_COLLECT_NODE_DONE:-}" ] && return
  _COLLECT_NODE_DONE=1
  [ -e /bin/sh ] && process /bin/sh
  for d in /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/lib/node_modules/pnpm /usr/local/lib/node_modules/bun \
           /usr/local/lib/node_modules/@tarquinen/opencode-dcp \
           /usr/local/lib/node_modules/@fission-ai/openspec; do
    [ -e "$d" ] && cp_with_parents "$d"
  done
}

for exe in "$@"; do
  echo ">>> $exe"
  p="$(command -v "$exe")" && process "$p"
done

for p in /etc/ssl/certs /etc/passwd /etc/group /etc/ld.so.cache \
         /etc/ld.so.conf /etc/ld.so.conf.d /usr/share/zoneinfo; do
  [ -e "$p" ] && cp_with_parents "$p"
done
