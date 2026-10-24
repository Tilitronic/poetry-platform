#!/usr/bin/env bash
# Active OMO runtime pin parity (opencode.jsonc vs tui.json vs Dockerfile.dev)
# plus prompt-override layer guards (DIA-261022-5n2v).
# The vendored source snapshot was removed 2026-10-22 (DIA-261022-5n2v); the
# npm package is the only runtime copy.
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

# Prompt-override layer guards (DIA-261022-5n2v). OMO discovers overrides by
# exact filename under this directory: a missing file silently falls back to
# the built-in prompt, and a near-miss name (orchestrator-append.md) is never
# loaded at all -- so both conditions must fail loud here.
override_dir="$root/.opencode/oh-my-opencode-slim"
required_overrides=(analyzer_append.md coder.md coder_append.md orchestrator_append.md reviewer.md)
# REFERENCE-ONLY.md is the deliberate vendored-snapshot marker, not a prompt
# override; it is the only tolerated extra *.md at the directory root.
allowed_extra_md=(REFERENCE-ONLY.md)

for name in "${required_overrides[@]}"; do
  if [ ! -s "$override_dir/$name" ]; then
    echo "fail: OMO prompt override missing or empty: ${override_dir#"$root/"}/$name" >&2
    exit 2
  fi
done

extras=""
for file in "$override_dir"/*.md; do
  base="$(basename "$file")"
  case " ${required_overrides[*]} ${allowed_extra_md[*]} " in
    *" $base "*) ;;
    *) extras="$extras $base" ;;
  esac
done
if [ -n "$extras" ]; then
  echo "fail: unexpected OMO prompt override file(s) at root:${extras}" >&2
  exit 2
fi

for name in knowledge/ai-assist-sources.yaml knowledge/opencode-best-practices.md; do
  if [ ! -s "$override_dir/$name" ]; then
    echo "fail: OMO knowledge file missing or empty: ${override_dir#"$root/"}/$name" >&2
    exit 2
  fi
done

echo "ok: active OMO pins aligned at $config_pin"
