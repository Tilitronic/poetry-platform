#!/usr/bin/env bash
# Active OMO runtime pin parity resolved PER SERVICE (DIA-261119-vioa task
# 1.3, design D2 / ADR 11 decision 4): each service's opencode.jsonc /
# tui.json / Dockerfile.dev declarations must agree WITHIN that service, and
# the loaded package cache must hold the declared pin.
#   V1 = this root (stays 2.2.19)
#   V2 = the docker-compose dev-v2 service's working_dir, mapped from the
#        /workspace mount to its repo-relative directory (default /workspace,
#        i.e. this root, when the key is absent; DIA-261125-p1kd): config
#        required, image build file / tui.json / prompt-override layer checked
#        while they exist (task 8.5 deletes tui.json).
# A cross-service equality check is forbidden: it would force V1 onto V2's
# pin. The vendored source snapshot was removed 2026-10-22 (DIA-261022-5n2v);
# the npm package is the only runtime copy.
set -euo pipefail

root="${OMO_SYNC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
compose="$root/docker-compose.yml"

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
# already name the service (resolved V2 tree for the V2 service).
check_override_layer() {
  local omo="$1" display="$2" name base file extras=""
  # orchestrator.md is the empty-suffix prompt override the 3.0.7 loader
  # resolves from this ROOT directory (the preset subdir is only an overlay
  # that is tried first); it is a required override, not a tolerated extra.
  local required_overrides=(analyzer_append.md coder.md coder_append.md orchestrator.md orchestrator_append.md reviewer.md)
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

# ---- V2 (docker-compose dev-v2 service): resolve its working_dir ----------
# Resolve the V2 tree from the compose service so the gate reads the SAME tree
# the container runs (DIA-261125-p1kd). dev-v2 mounts .:/workspace, so a
# working_dir of /workspace or /workspace/<sub> maps to the repo root or the
# matching repo-relative directory. Absent compose / service / key degrades to
# a skip message, never a hard failure; no new dependency (PyYAML only).
resolve_v2_working_dir() { # <compose file>: echo working_dir or a sentinel
  [ -f "$1" ] || { printf 'NO_COMPOSE\n'; return 0; }
  python3 - "$1" <<'PY' 2>/dev/null || printf 'RESOLVE_FAILED\n'
import sys
try:
    import yaml
except Exception:
    print("NO_PYYAML")
    raise SystemExit(0)
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
except Exception:
    print("BAD_COMPOSE")
    raise SystemExit(0)
svc = (data.get("services") or {}).get("dev-v2")
if svc is None:
    print("NO_DEV_V2")
else:
    print(svc.get("working_dir") or "/workspace")
PY
}

v2_root="" v2_tag=""
v2_wd="$(resolve_v2_working_dir "$compose")"
[ -n "$v2_wd" ] || v2_wd="RESOLVE_FAILED"
case "$v2_wd" in
  NO_COMPOSE)
    echo "skip: docker-compose.yml not found (V2 pin check skipped)" ;;
  NO_DEV_V2)
    echo "skip: dev-v2 service not found in docker-compose.yml (V2 pin check skipped)" ;;
  NO_PYYAML | BAD_COMPOSE | RESOLVE_FAILED)
    echo "skip: could not resolve dev-v2 working_dir from docker-compose.yml (V2 pin check skipped)" ;;
  /workspace)
    v2_root="$root"
    v2_tag="V2 service dev-v2 at /workspace" ;;
  /workspace/*)
    v2_root="$root/${v2_wd#/workspace/}"
    v2_tag="V2 service dev-v2 at $v2_wd" ;;
  *)
    echo "skip: dev-v2 working_dir '$v2_wd' is outside /workspace (V2 pin check skipped)" ;;
esac

if [ -n "$v2_root" ]; then
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
# Layout-aware (DIA-261119-vioa): a pnpm bake writes the versioned store
# directory <cache>/oh-my-opencode-slim@<pin>, but the image bake runs npm
# (Dockerfile.dev `npm install oh-my-opencode-slim@${OMO_VERSION}`), which
# writes <cache>/oh-my-opencode-slim and records the pin as a dependency in
# the package.json beside node_modules -- so a store-directory-only probe can
# never pass on the image. Both layouts are accepted; metadata that is absent
# or unreadable fails loud and names every path it probed (never a silent
# success, never a silent skip).
# ponytail: one cache root, one declared pin (the root service's); add
# per-service cache roots only if a V2-side cache must be probed separately
# (the V2 dev_v2_cache volume is only visible when the gate runs in dev-v2,
# where the repo root IS this root).
cache_root="${OMO_CACHE_ROOT:-${HOME:-}/.cache/opencode/node_modules}"
cache_pkg_near="$(dirname "$cache_root")/package.json"
cache_pkg_up="$(dirname "$(dirname "$cache_root")")/package.json"

# cache_metadata_pin <package.json>: echo the declared oh-my-opencode-slim
# version and exit 0, or exit 1 when the file is unreadable or never names
# the package with a semver. Reads dependencies / devDependencies, including
# npm-alias spellings (value `npm:<name>@<ver>`, or an alias key whose value
# points at <name>@<ver>). The top-level "version" field is deliberately
# ignored: `npm init -y` seeds it with 1.0.0, which would be a false match.
cache_metadata_pin() {
  node -e '
const pkg = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const name = "oh-my-opencode-slim";
for (const section of ["dependencies", "devDependencies"]) {
  const deps = pkg[section];
  if (!deps) continue;
  for (const key of Object.keys(deps)) {
    const spec = String(deps[key]).replace(/^npm:/, "");
    if (key !== name && !key.startsWith(name + "@") && !spec.startsWith(name + "@")) continue;
    const m = spec.match(/\d+\.\d+\.\d+/);
    if (m) { process.stdout.write(m[0]); process.exit(0); }
  }
}
process.exit(1);
' "$1" 2>/dev/null
}

if [ ! -d "$cache_root" ]; then
  # S1: name the path that was probed -- a silent skip hid that nothing ran.
  echo "skip: OMO cache root absent: ${cache_root} (loaded-cache pin check skipped)"
elif [ -d "$cache_root/oh-my-opencode-slim@$config_pin" ]; then
  : # pnpm-style store entry: the directory name already carries the pin.
else
  cache_pin="" cache_meta=""
  for pkg in "$cache_pkg_near" "$cache_pkg_up"; do
    if [ -f "$pkg" ] && cache_pin="$(cache_metadata_pin "$pkg")"; then
      cache_meta="$pkg"
      break
    fi
  done
  if [ -z "$cache_pin" ]; then
    echo "fail: OMO loaded cache missing declared pin: oh-my-opencode-slim@$config_pin ($cache_root; probed package.json: $cache_pkg_near, $cache_pkg_up - absent or unreadable)" >&2
    exit 1
  fi
  if [ "$cache_pin" != "$config_pin" ]; then
    echo "fail: OMO loaded cache pin mismatch: declared oh-my-opencode-slim@$config_pin, cache metadata says oh-my-opencode-slim@$cache_pin ($cache_root; via $cache_meta)" >&2
    exit 1
  fi
fi

echo "ok: active OMO pins aligned at $config_pin"
