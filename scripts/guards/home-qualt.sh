#!/usr/bin/env bash
# guard_no_home_qualt: blocks a recurring-writer regression. An unidentified
# local writer periodically rewrites .opencode/commands/*.md from the portable
# ${HOME:?HOME must be set} back to the literal /home/qualt path (PR #2
# comments #2/#3 fixed the original; the writer is unknown, so the regression
# is made impossible to commit instead of being chased). The guard greps
# $COMMANDS_DIR/*.md for the literal path and fails the hook when it is found.
#
# Sourced (not executed) by the husky hooks scripts/verify-pre-commit.sh and
# scripts/verify-pre-push.sh (F-6, DIA-179). Caller contract: $ROOT (used to
# strip the repo prefix from error output) and $COMMANDS_DIR (the directory to
# scan) must be set by the caller first; the hooks set both, with $COMMANDS_DIR
# defaulting to $ROOT/.opencode/commands. The hooks fire the guard on the HOST
# before any container detection so dirty files are rejected even when the dev
# container is down.
guard_no_home_qualt() {
  local hits file
  # grep -l lists the offending files (full paths); no match exits 1 - the
  # clean case, so nothing is printed and the guard passes.
  hits="$(grep -lF '/home/qualt' "$COMMANDS_DIR"/*.md 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r file; do
      echo "ERROR: literal '/home/qualt' found in ${file#$ROOT/} - use \${HOME:?HOME must be set} (portability; PR #2 comments #2/#3 fix)" >&2
    done <<< "$hits"
    exit 1
  fi
}
