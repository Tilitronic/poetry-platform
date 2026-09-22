#!/usr/bin/env bash
# check-secrets-ownership.sh — secrets ownership preflight (DIA-260821-x5nj)
#
# Verifies a secrets directory and its DIRECT files are owned by the invoking
# user (resolved dynamically via `id -u`, never hardcoded) and that each file
# is exactly mode 0600. On any violation it prints an ACTIONABLE remediation
# command (chown/chmod) but NEVER executes it, and never uses the recursive -R
# form. SSH agent forwarding is orthogonal and never inspected.
#
# Usage: check-secrets-ownership.sh [SECRETS_DIR]   # default: secrets
#   exit 0 -> safe (dir owned by `id -u`, every file owner==`id -u`, mode 600)
#   exit 1 -> unsafe/missing (prints remediation, does NOT fix)
set -u

SECRETS_DIR="${1:-secrets}"

uid="$(id -u)"
gid="$(id -g)"

fail=0

# check one path: owner must equal the invoking uid; regular files must be
# exactly mode 0600. The directory's mode is intentionally not checked — only
# its ownership matters for the preflight boundary.
check_path() {
  local path owner mode
  path="$1"
  owner="$(stat -c %u "$path")"
  mode="$(stat -c %a "$path")"
  if [ "$owner" != "$uid" ]; then
    echo "UNSAFE: $path is owned by uid $owner, expected uid $uid"
    echo "  fix: chown $uid:$gid $path"
    fail=1
  fi
  if [ -f "$path" ] && [ "$mode" != "600" ]; then
    echo "UNSAFE: $path is mode $mode, expected 0600"
    echo "  fix: chmod 0600 $path"
    fail=1
  fi
}

if [ ! -d "$SECRETS_DIR" ]; then
  echo "UNSAFE: secrets directory not found: $SECRETS_DIR"
  echo "  fix: create it and ensure it is owned by uid $uid ($uid:$gid)"
  exit 1
fi

check_path "$SECRETS_DIR"

for f in "$SECRETS_DIR"/*; do
  [ -f "$f" ] || continue
  # README.md is documentation, not a secret — exclude from ownership/mode checks
  [ "$(basename "$f")" = "README.md" ] && continue
  check_path "$f"
done

if [ "$fail" -eq 0 ]; then
  echo "secrets ownership OK: $SECRETS_DIR owned by uid $uid, all files mode 0600"
  exit 0
fi

exit 1
