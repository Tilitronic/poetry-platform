#!/usr/bin/env bash
# Re-validates a vendored bats-core checkout against the version pinned in
# bats-wrapper.sh (DIA-121).
#
# The vendor dir (scripts/__tests__/vendor/bats-core) is git-ignored and
# cloned once on first run; nothing re-checks it afterwards, so a machine can
# silently drift to a different bats version with no detection (this actually
# happened: the dir sat at v1.14.0 while the wrapper pin claimed v1.11.0).
# bats-wrapper.sh calls this script on every run to close that gap.
#
# Usage: check-bats-vendor-drift.sh <pin-version> <vendor-dir>
#   <pin-version>  expected bats version in package.json format (e.g. 1.14.0,
#                  NO leading "v" - the "version" field of the bats package.json
#                  is tagless; the git tag is "v1.14.0"). This is the wrapper's
#                  BATS_VENDOR_VERSION constant.
#   <vendor-dir>   path to the vendored bats-core checkout.
#
# Exit codes:
#   0  vendor dir absent (nothing vendored yet -> nothing to validate) OR the
#      vendored version matches the pin.
#   1  vendored version differs from the pin, or the checkout is unverifiable
#      (no package.json / no version field). A warning is printed to stderr.
#   2  usage error (missing arguments).
#
# Why compare package.json and not `git describe --tags` / rev-parse: the
# wrapper clones with `--depth 1 --branch`, so the shallow clone has NO tags
# and `git describe` fails on it; package.json is the one reliable version
# signal present in every checkout.
set -euo pipefail

PIN="${1:-}"
VENDOR_DIR="${2:-}"

if [ -z "$PIN" ] || [ -z "$VENDOR_DIR" ]; then
  echo "error: usage: $0 <pin-version> <vendor-dir>" >&2
  exit 2
fi

if [ ! -d "$VENDOR_DIR" ]; then
  # First-run state: the fresh clone is what establishes the version, so there
  # is no drift to detect yet.
  exit 0
fi

PACKAGE_JSON="$VENDOR_DIR/package.json"
if [ ! -f "$PACKAGE_JSON" ]; then
  echo "warning: vendored bats at $VENDOR_DIR has no package.json - cannot verify version against pin v$PIN; expected a bats-core checkout" >&2
  exit 1
fi

# Extract the TOP-LEVEL "version" field only. The naive "first version match"
# (a plain sed) breaks when a nested object carries its own "version" key
# before the root one (e.g. a "scripts" block with a version task) - it would
# read the nested value as the bats version (DIA-121 FAL-1). This awk state
# machine tracks brace depth and only accepts a "version" key at depth 1 (a
# direct child of the root object). Brace counting is string-aware (quoted
# braces are ignored), so string values containing "{" / "}" cannot corrupt
# the depth signal. Dependency-light: awk is POSIX, no jq/node required.
VENDORED_VERSION="$(awk '
  BEGIN { depth = 0 }
  {
    if (depth == 1 && $0 ~ /^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"/) {
      line = $0
      sub(/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*/, "", line)
      if (match(line, /^"[^"]*"/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
    t = $0
    gsub(/"([^"\\]|\\.)*"/, "", t)
    opens = gsub(/\{/, "&", t)
    closes = gsub(/\}/, "&", t)
    depth += opens - closes
  }
' "$PACKAGE_JSON" | head -n 1)"

if [ -z "$VENDORED_VERSION" ]; then
  echo "warning: cannot read a \"version\" field from $PACKAGE_JSON - cannot verify against pin v$PIN" >&2
  exit 1
fi

# Normalize: strip a leading "v" from either side so the comparison is
# tag-format-agnostic (the pin is stored tagless, package.json is tagless,
# but a future editor could introduce a "v" on either side).
if [ "${VENDORED_VERSION#v}" != "${PIN#v}" ]; then
  echo "warning: vendored bats version mismatch: $VENDOR_DIR is at v${VENDORED_VERSION#v} but bats-wrapper.sh pins v${PIN#v} (DIA-121 drift check)" >&2
  exit 1
fi

exit 0
