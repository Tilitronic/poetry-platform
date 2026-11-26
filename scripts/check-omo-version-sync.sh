#!/usr/bin/env bash
# Active OMO runtime pin parity resolved PER SERVICE (DIA-261119-vioa task
# 1.3, design D2 / ADR 11 decision 4): each service's opencode.jsonc /
# tui.json / Dockerfile.dev declarations must agree WITHIN that service, and
# the loaded package cache must hold the declared pin.
#   V1 = this root (stays 2.2.19)
#   V2 = .worktrees/opencode-v2 while it exists (ADR 11 dev-v2 working_dir):
#        config required, image build file / tui.json / prompt-override layer
#        checked while they exist (task 8.5 deletes tui.json).
# A cross-service equality check is forbidden: it would force V1 onto V2's
# pin. The vendored source snapshot was removed 2026-10-22 (DIA-261022-5n2v);
# the npm package is the only runtime copy.
set -euo pipefail

root="${OMO_SYNC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
v2_root="$root/.worktrees/opencode-v2"
v2_tag="V2 worktree .worktrees/opencode-v2"

# ---- pin extraction (one implementation, reused per service) ---------------
config_pin_of() { # <opencode.jsonc>
  sed -nE 's/^[[:space:]]*"oh-my-opencode-slim@([0-9]+\.[0-9]+\.[0-9]+)"[,]?[[:space:]]*$/\1/p' "$1"
}

tui_pin_of() { # <tui.json>
  grep -oE '"oh-my-opencode-slim@[0-9]+\.[0-9]+\.[0-9]+"' "$1" | sed -E 's/^"oh-my-opencode-slim@//; s/"$//' || true
}

image_pin_of() { # <Dockerfile.dev>
  sed -nE 's/^[[:space:]]*ARG[[:space:]]+OMO_VERSION=([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' "$1"
}

require_source() { # <abs path>: a required pin source is missing -> exit 2
  [ -f "$1" ] || { echo "fail: OMO pin source missing: ${1#"$root/"}" >&2; exit 2; }
}

# require_one_pin <service tag> <file label> <value>. Empty tag = V1 so the
# legacy message stays byte-identical; the V2 tag names the service.
require_one_pin() {
  local tag="$1" label="$2" value="$3" count
  count="$(printf '%s\n' "$value" | awk 'NF { count++ } END { print count + 0 }')"
  if [ -z "$value" ] || [ "$count" -ne 1 ]; then
    echo "fail: ${tag:+${tag}: }${label} must declare exactly one active OMO version pin" >&2
    exit 2
  fi
}

# check_drift <service tag> <config pin> <tui pin or empty> <image pin or
# empty>: all present legs of ONE service must agree; an absent optional leg
# is skipped, never compared. V1 (empty tag) keeps the legacy single-line
# message byte-for-byte; the V2 tag names the service and the drifting file.
check_drift() {
  local tag="$1" c="$2" t="$3" i="$4" msg drifting=""
  [ -z "$t" ] || [ "$t" = "$c" ] || drifting=" tui.json=$t"
  [ -z "$i" ] || [ "$i" = "$c" ] || drifting=" Dockerfile.dev=$i"
  [ -n "$drifting" ] || return 0
  msg="opencode.jsonc=$c"
  [ -z "$t" ] || msg="$msg tui.json=$t"
  [ -z "$i" ] || msg="$msg Dockerfile.dev=$i"
  if [ -n "$tag" ]; then
    echo "fail: OMO version drift: $msg [$tag; drifting file:$drifting]" >&2
  else
    echo "fail: OMO version drift: $msg" >&2
  fi
  exit 1
}

# check_override_layer <omo dir> <display label>: prompt-override + knowledge
# guards (DIA-261022-5n2v). OMO discovers overrides by exact filename under
# this directory: a missing file silently falls back to the built-in prompt,
# and a near-miss name (orchestrator-append.md) is never loaded at all -- so
# both conditions must fail loud here. The relative paths in the messages
# already name the service (worktree path for V2).
check_override_layer() {
  local omo="$1" display="$2" name base file extras=""
  local required_overrides=(analyzer_append.md coder.md coder_append.md orchestrator_append.md reviewer.md)
  # REFERENCE-ONLY.md is the deliberate vendored-snapshot marker, not a prompt
  # override; it is the only tolerated extra *.md at the directory root.
  local allowed_extra_md=(REFERENCE-ONLY.md)

  for name in "${required_overrides[@]}"; do
    if [ ! -s "$omo/$name" ]; then
      echo "fail: OMO prompt override missing or empty: ${omo#"$root/"}/$name" >&2
      exit 2
    fi
  done

  extras=""
  for file in "$omo"/*.md; do
    base="$(basename "$file")"
    case " ${required_overrides[*]} ${allowed_extra_md[*]} " in
      *" $base "*) ;;
      *) extras="$extras $base" ;;
    esac
  done
  if [ -n "$extras" ]; then
    echo "fail: unexpected OMO prompt override file(s) at ${display}:${extras}" >&2
    exit 2
  fi

  for name in knowledge/ai-assist-sources.yaml knowledge/opencode-best-practices.md; do
    if [ ! -s "$omo/$name" ]; then
      echo "fail: OMO knowledge file missing or empty: ${omo#"$root/"}/$name" >&2
      exit 2
    fi
  done
}

# ---- V1 (root service): all three declarations are required ----------------
config="$root/.opencode/opencode.jsonc"
tui="$root/.opencode/tui.json"
dockerfile="$root/Dockerfile.dev"

require_source "$config"
require_source "$tui"
require_source "$dockerfile"

config_pin="$(config_pin_of "$config")"
tui_pin="$(tui_pin_of "$tui")"
image_pin="$(image_pin_of "$dockerfile")"

require_one_pin "" "opencode.jsonc" "$config_pin"
require_one_pin "" "tui.json" "$tui_pin"
require_one_pin "" "Dockerfile.dev" "$image_pin"
check_drift "" "$config_pin" "$tui_pin" "$image_pin"

check_override_layer "$root/.opencode/oh-my-opencode-slim" "root"

# ---- V2 (worktree service): resolved while the worktree exists -------------
if [ -d "$v2_root" ]; then
  v2_config="$v2_root/.opencode/opencode.jsonc"
  v2_tui="$v2_root/.opencode/tui.json"
  v2_dockerfile="$v2_root/Dockerfile.dev"
  v2_omo="$v2_root/.opencode/oh-my-opencode-slim"

  require_source "$v2_config"
  v2_config_pin="$(config_pin_of "$v2_config")"
  v2_tui_pin=""
  if [ -f "$v2_tui" ]; then
    v2_tui_pin="$(tui_pin_of "$v2_tui")"
  fi
  v2_image_pin=""
  if [ -f "$v2_dockerfile" ]; then
    v2_image_pin="$(image_pin_of "$v2_dockerfile")"
    require_one_pin "$v2_tag" "Dockerfile.dev" "$v2_image_pin"
  fi
  require_one_pin "$v2_tag" "opencode.jsonc" "$v2_config_pin"
  if [ -n "$v2_tui_pin" ]; then
    require_one_pin "$v2_tag" "tui.json" "$v2_tui_pin"
  fi
  check_drift "$v2_tag" "$v2_config_pin" "$v2_tui_pin" "$v2_image_pin"

  if [ -d "$v2_omo" ]; then
    check_override_layer "$v2_omo" "${v2_omo#"$root/"}"
  fi
  echo "ok: OMO pins aligned at $v2_config_pin ($v2_tag)"
fi

# ---- Loaded cache (ADR 11 decision 4) --------------------------------------
# The declared pin must be present in the package cache the runtime loads
# from. Probed against the ROOT declaration: that is the cache this run can
# see, and it is asserted after every pin/override guard so a missing-source
# or drift report keeps its own failure class. The real image cache root is
# ~/.cache/opencode/node_modules (Dockerfile.dev OMO pre-population layer).
# ponytail: presence-only probe of one cache root; add per-service cache roots
# and a version comparison if a stale-but-present pin ever becomes a risk
# (the V2 dev_v2_cache volume is only visible when the gate runs in dev-v2,
# where the worktree IS this root).
cache_root="${OMO_CACHE_ROOT:-${HOME:-}/.cache/opencode/node_modules}"
if [ ! -d "$cache_root" ]; then
  # S1: name the path that was probed -- a silent skip hid that nothing ran.
  echo "skip: OMO cache root absent: ${cache_root} (loaded-cache pin check skipped)"
elif [ ! -d "$cache_root/oh-my-opencode-slim@$config_pin" ]; then
  echo "fail: OMO loaded cache missing declared pin: oh-my-opencode-slim@$config_pin ($cache_root)" >&2
  exit 1
fi

echo "ok: active OMO pins aligned at $config_pin"
