#!/usr/bin/env bats
# Static regression guard (DIA-260824-a3mk): detect any `docker compose exec`
# that launches `opencode` as root directly (not via the entrypoint), which
# would re-own the OpenCode log and defeat the self-healing model.
#
# SAFE patterns (the only supported ways to launch opencode):
#   - `--user dev` present               -> runs as dev directly (never re-owns log)
#   - routes through `dev-entrypoint.sh` -> entrypoint chowns then gosu dev
#     (self-healing; the only supported root launch)
# VIOLATION: launches `opencode` directly without `--user dev` and not via the
#   entrypoint.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "no root opencode launcher outside entrypoint self-heal" {
  local violations=0
  local f line
  while IFS= read -r -d '' f; do
    while IFS= read -r line; do
      # Only consider lines that exec opencode directly (opencode as a command).
      if printf '%s\n' "$line" | grep -Eq 'docker compose exec[^|]*opencode( |$)'; then
        if printf '%s\n' "$line" | grep -Eq -- '--user dev' \
           || printf '%s\n' "$line" | grep -q 'dev-entrypoint.sh'; then
          continue
        fi
        echo "VIOLATION: root opencode launcher not via entrypoint: $f: $line" >&2
        violations=1
      fi
    done < "$f"
  # Coverage ceiling: -maxdepth 2 + single-line Makefile/*.sh patterns only; nested
  # launcher scripts or multi-line invocations are out of scope for this static guard.
  done < <(find "$REPO_ROOT" -maxdepth 2 \( -name Makefile -o -name '*.sh' \) -print0)
  [ "$violations" -eq 0 ]
}
