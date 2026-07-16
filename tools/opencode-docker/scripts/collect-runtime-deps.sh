#!/usr/bin/env bash
set -euo pipefail

ROOTFS="$1"; shift
mkdir -p "$ROOTFS"

declare -A PROCESSED=()

cp_with_parents() {
  local src="$1"
  local dst="${ROOTFS}${src}"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$src" ]; then
    cp -a "$src" "$dst"
    local resolved; resolved="$(readlink -f "$src")"
    [ -n "$resolved" ] && [ -e "$resolved" ] && cp_with_parents "$resolved"
  elif [ -d "$src" ]; then
    cp -a "$src/." "$dst"
  else
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
  [ -e /bin/sh ] && process /bin/sh
  for d in /usr/bin/npm /usr/bin/npx /usr/bin/corepack \
           /usr/lib/node_modules/npm /usr/lib/node_modules/corepack \
           /usr/lib/node_modules/pnpm /usr/lib/node_modules/bun \
           /usr/lib/node_modules/opencode-snip \
           /usr/lib/node_modules/@tarquinen/opencode-dcp; do
    [ -e "$d" ] && cp_with_parents "$d"
  done
}

for exe in "$@"; do
  p="$(command -v "$exe")" && process "$p"
done

for p in /etc/ssl/certs /etc/passwd /etc/group /etc/ld.so.cache \
         /etc/ld.so.conf /etc/ld.so.conf.d /usr/share/zoneinfo; do
  [ -e "$p" ] && cp_with_parents "$p"
done
