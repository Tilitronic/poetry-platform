#!/usr/bin/env bash
# Generate jsconfig.json for the poetry-platform monorepo.
#
# Reads the workspace layout (pnpm-workspace.yaml + each package's
# package.json) and emits a jsconfig.json to STDOUT mapping every
# @poetry/* package to its real entry point. The caller redirects stdout to
# the target file (see the Makefile `gen-jsconfig` target and the
# devcontainer postCreateCommand).
#
# Why a generated file instead of a committed one: a committed jsconfig.json
# silently goes stale when the workspace layout changes. Regenerating on every
# devcontainer create and validating the output shape with bats
# (scripts/__tests__/gen-jsconfig.bats) catches drift in CI.
#
# Entry-point resolution: a package's ACTUAL entry is read from package.json
# main/types (stripped of any leading ./), falling back to the src/index.ts
# convention only when neither is declared. This is intentional — several
# packages (phonetics-core -> src/atlas/load-atlas.ts, visualizer-2d ->
# src/interactive/index.ts) do NOT
# use src/index.ts as their entry, so assuming that path would produce
# mappings to files that exist but are not the package's public surface.
#
# Exit codes: 0 on success; 1 on missing pnpm-workspace.yaml, a malformed
# package.json, a missing name, a declared entry that does not exist on disk,
# or an empty @poetry package set.
#
# Non-package directories (no package.json — e.g. the Python-only
# apps/api-server and packages/analytics-pipeline) and non-@poetry-scoped
# names (apps/author-studio) are SKIPPED with a note on stderr, not failed:
# pnpm itself does not treat them as workspace packages, and a package with no
# entry point cannot contribute a path mapping (historical example:
# apps/publishing-platform, a deps-only placeholder -- deleted 2026-08-25,
# re-scaffold when W1 lands). The strict failures above are reserved for drift
# that should stop CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# jq is required; it is installed in the dev container (Dockerfile.dev base
# packages) and expected on hosts that run the bats tests / Makefile targets.
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not on PATH" >&2
  exit 1
fi

WORKSPACE_YAML="$ROOT/pnpm-workspace.yaml"
if [ ! -f "$WORKSPACE_YAML" ]; then
  echo "error: pnpm-workspace.yaml not found at $WORKSPACE_YAML" >&2
  exit 1
fi

# Extract the globs under the `packages:` key (e.g. "apps/*", "packages/*"),
# stopping at the next top-level key. Handles quoted values.
mapfile -t GLOBS < <(awk '
  /^packages:/ { in_packages=1; next }
  in_packages && /^[[:space:]]+-/ {
    line=$0
    sub(/^[[:space:]]*-[[:space:]]*/, "", line)
    gsub(/["'"'"']/, "", line)
    print line
    next
  }
  in_packages && /^[^[:space:]-]/ { exit }
' "$WORKSPACE_YAML")

if [ "${#GLOBS[@]}" -eq 0 ]; then
  echo "error: no packages: globs found in pnpm-workspace.yaml" >&2
  exit 1
fi

# MAPPINGS holds triples: name, package dir (absolute), entry path (relative
# to the package dir). Built with an array so we can sort deterministically
# before emitting.
declare -a MAPPINGS=()

for glob in "${GLOBS[@]}"; do
  # Intentionally unquoted $glob: the glob must be expanded by bash.
  # shellcheck disable=SC2086
  for dir in "$ROOT"/$glob; do
    [ -d "$dir" ] || continue
    rel_dir="${dir#"$ROOT"/}"
    pkg_file="$dir/package.json"

    if [ ! -f "$pkg_file" ]; then
      echo "note: skipping $rel_dir: no package.json (not a pnpm workspace package)" >&2
      continue
    fi
    if ! jq -e . "$pkg_file" >/dev/null 2>&1; then
      echo "error: malformed package.json in $rel_dir" >&2
      exit 1
    fi

    name="$(jq -r '.name // empty' "$pkg_file")"
    if [ -z "$name" ]; then
      echo "error: package.json in $rel_dir has no name field" >&2
      exit 1
    fi
    case "$name" in
      @poetry/*) ;;
      *)
        echo "note: skipping $rel_dir: name '$name' is not @poetry/*-scoped" >&2
        continue
        ;;
    esac

    # Actual entry: types > main from package.json; fall back to src/index.ts
    # only when neither is declared.
    entry="$(jq -r '[.types, .main] | map(select(. != null)) | .[0] // empty' "$pkg_file")"
    entry="${entry#./}"
    if [ -z "$entry" ]; then
      if [ -f "$dir/src/index.ts" ]; then
        entry="src/index.ts"
      else
        echo "warning: skipping $name ($rel_dir): no main/types declared and no src/index.ts" >&2
        continue
      fi
    fi
    if [ ! -f "$dir/$entry" ]; then
      echo "error: $name declares entry '$entry' but $rel_dir/$entry does not exist" >&2
      exit 1
    fi

    MAPPINGS+=("$name" "$dir" "$entry")
  done
done

if [ "${#MAPPINGS[@]}" -eq 0 ]; then
  echo "error: no @poetry/* packages with an entry point found in the workspace" >&2
  exit 1
fi

# Build the paths object from sorted name\trel-entry lines (LC_ALL=C keeps the
# sort byte-stable across machines), then emit the document. jq -S sorts all
# keys so output is byte-identical run to run (determinism test).
paths_json="$(
  for ((i = 0; i < ${#MAPPINGS[@]}; i += 3)); do
    printf '%s\t%s/%s\n' "${MAPPINGS[i]}" "${MAPPINGS[i + 1]#"$ROOT"/}" "${MAPPINGS[i + 2]}"
  done | LC_ALL=C sort | jq -Rr 'split("\t") | { (.[0]): [ .[1] ] }' | jq -s 'add'
)"

jq -S -n \
  --arg baseUrl "." \
  --argjson paths "$paths_json" \
  '{ compilerOptions: { baseUrl: $baseUrl, paths: $paths } }'
