#!/usr/bin/env bash
# Active OMO runtime pin parity. The vendored src/ tree is reference-only.
set -euo pipefail

root="${OMO_SYNC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
config="$root/.opencode/opencode.jsonc"
tui="$root/.opencode/tui.json"
dockerfile="$root/Dockerfile.dev"

for file in "$config" "$tui" "$dockerfile"; do
  if [ ! -f "$file" ]; then
    echo "fail: OMO pin source missing: ${file#"$root/"}" >&2
    exit 2
  fi
done

config_pin="$(sed -nE 's/^[[:space:]]*"oh-my-opencode-slim@([0-9]+\.[0-9]+\.[0-9]+)"[,]?[[:space:]]*$/\1/p' "$config")"
tui_pin="$(grep -oE '"oh-my-opencode-slim@[0-9]+\.[0-9]+\.[0-9]+"' "$tui" | sed -E 's/^"oh-my-opencode-slim@//; s/"$//' || true)"
image_pin="$(sed -nE 's/^[[:space:]]*ARG[[:space:]]+OMO_VERSION=([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' "$dockerfile")"

for pair in "opencode.jsonc:$config_pin" "tui.json:$tui_pin" "Dockerfile.dev:$image_pin"; do
  label="${pair%%:*}"
  value="${pair#*:}"
  count="$(printf '%s\n' "$value" | awk 'NF { count++ } END { print count + 0 }')"
  if [ -z "$value" ] || [ "$count" -ne 1 ]; then
    echo "fail: ${label} must declare exactly one active OMO version pin" >&2
    exit 2
  fi
done

if [ "$config_pin" != "$tui_pin" ] || [ "$config_pin" != "$image_pin" ]; then
  echo "fail: OMO version drift: opencode.jsonc=$config_pin tui.json=$tui_pin Dockerfile.dev=$image_pin" >&2
  exit 1
fi

echo "ok: active OMO pins aligned at $config_pin"
