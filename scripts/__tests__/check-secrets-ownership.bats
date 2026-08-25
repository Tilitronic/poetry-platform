#!/usr/bin/env bats
# RED-phase unit tests for scripts/check-secrets-ownership.sh
# (DIA-260821-x5nj, Option-A unified Docker dev runtime, Slice 7 / tasks.md
# T7.0a + T7.0c — "secure Option-A secrets ownership sub-slice").
#
# Scope of THIS slice (secrets ownership preflight, design.md "Seam 5: Secrets
# Ownership Preflight Boundary" + tasks.md T7.0a):
#   - `secrets/` directory is owned by the INVOKING user (the rootless-Podman
#     user whose UID `keep-id` maps; resolved dynamically via `id -u`, NOT a
#     hardcoded value)
#   - each secret FILE is exactly mode 0600 (no group/other read bits)
#   - unsafe OR missing paths fail with ACTIONABLE diagnostics
#     (e.g. `chown <uid>:<gid> <path>` / `chmod 0600 <path>`)
#   - the script NEVER performs automatic remediation: it must not execute
#     `chown`/`chmod` at all, and must not use the recursive `-R` form
#   - SSH agent forwarding is ORTHOGONAL: the preflight must not read, forward,
#     or fail on `SSH_AUTH_SOCK` / `ssh-agent`
#
# GREEN state: scripts/check-secrets-ownership.sh exists (T7.0a) and is wired
# into scripts/opencode-dev ahead of 'compose up' (T7.0b); these tests pin the
# standalone contract the launcher relies on.
#
# Seam under test (design.md "Seam 5"):
#   check-secrets-ownership.sh [SECRETS_DIR]   # default: secrets
#     exit 0  -> safe (dir owned by `id -u`, every file owner==`id -u`, mode 600)
#     exit 1  -> unsafe/missing, prints actionable remediation, does NOT fix
#
# Mocking strategy (mock-based, hermetic — no real container, no real stat):
#   - `id` is faked: `id -u` -> $FAKE_UID, `id -g` -> $FAKE_GID (the invoking
#     user the preflight must compare against).
#   - `stat` is faked: answers owner/mode from a DB file ($FAKE_STAT_DB),
#     keyed by the exact path the script probes. This lets tests drive
#     ownership/mode independently of the real filesystem.
#   - A real fixture `secrets/` tree (empty regular files) is created so the
#     script's file enumeration (glob / find) works; the mocked `stat` overrides
#     the reported owner/mode for each entry.
#   - `chown`/`chmod` are faked to RECORD invocations to $FAKE_REMEDIATION_LOG
#     so we can prove the preflight never remediates.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check-secrets-ownership.sh"

# mock_id: fake `id` — `id -u` -> $FAKE_UID, `id -g` -> $FAKE_GID.
mock_id() {
  local bindir="$BATS_TEST_TMPDIR/idbin"
  mkdir -p "$bindir"
  cat > "$bindir/id" <<'FAKEID'
#!/usr/bin/env bash
case "${1:-}" in
  -u) printf '%s\n' "${FAKE_UID:-1000}" ;;
  -g) printf '%s\n' "${FAKE_GID:-1000}" ;;
  *)  printf '%s\n' "${FAKE_UID:-1000}" ;;
esac
FAKEID
  chmod +x "$bindir/id"
  PATH="$bindir:$PATH"
}

# mock_stat: fake `stat` — answers owner/mode from $FAKE_STAT_DB (tab-separated
# "<path>\t<owner>\t<mode>" lines), keyed by the exact probed path. Supports
# `-c %u` (owner), `-c %a` (mode), and combined `-c '%u %a'`.
mock_stat() {
  local bindir="$BATS_TEST_TMPDIR/statbin"
  mkdir -p "$bindir"
  cat > "$bindir/stat" <<'FAKESTAT'
#!/usr/bin/env bash
fmt="%a"; path=""
while [ $# -gt 0 ]; do
  case "$1" in
    -c) fmt="$2"; shift 2 ;;
    -L|--|--) shift; path="${1:-}"; break ;;
    -*) shift ;;
    *) path="$1"; break ;;
  esac
done
[ -n "$path" ] || { echo "mock stat: missing path" >&2; exit 1; }
owner="0"; mode="000"
db="${FAKE_STAT_DB:-}"
if [ -n "$db" ] && [ -f "$db" ]; then
  while IFS=$'\t' read -r p o m; do
    [ "$p" = "$path" ] && { owner="$o"; mode="$m"; break; }
  done < "$db"
fi
case "$fmt" in
  %u) printf '%s\n' "$owner" ;;
  %a) printf '%s\n' "$mode" ;;
  *)  printf '%s %s\n' "$owner" "$mode" ;;
esac
FAKESTAT
  chmod +x "$bindir/stat"
  PATH="$bindir:$PATH"
}

# mock_remediation: fake `chown`/`chmod` that RECORD every invocation to
# $FAKE_REMEDIATION_LOG (and succeed). Proves the preflight never remediates.
mock_remediation() {
  local bindir="$BATS_TEST_TMPDIR/rembin"
  mkdir -p "$bindir"
  FAKE_REMEDIATION_LOG="${FAKE_REMEDIATION_LOG:-$BATS_TEST_TMPDIR/remediation.log}"
  : > "$FAKE_REMEDIATION_LOG"
  export FAKE_REMEDIATION_LOG
  cat > "$bindir/chown" <<'FAKECHOWN'
#!/usr/bin/env bash
printf '%s\n' "chown $*" >> "${FAKE_REMEDIATION_LOG:?}"
exit 0
FAKECHOWN
  cat > "$bindir/chmod" <<'FAKECHMOD'
#!/usr/bin/env bash
printf '%s\n' "chmod $*" >> "${FAKE_REMEDIATION_LOG:?}"
exit 0
FAKECHMOD
  chmod +x "$bindir/chown" "$bindir/chmod"
  PATH="$bindir:$PATH"
}

# seed_stat <path> <owner> <mode>: append one DB row for the fake `stat`.
seed_stat() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$FAKE_STAT_DB"
}

# assert_no_remediation: fails if the preflight executed any chown/chmod.
assert_no_remediation() {
  if [ -s "$FAKE_REMEDIATION_LOG" ]; then
    echo "assert_no_remediation: preflight executed remediation:" >&2
    cat "$FAKE_REMEDIATION_LOG" >&2
    return 1
  fi
}

setup() {
  mock_id
  mock_stat
  mock_remediation
  SECRETS_FIXTURE="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$SECRETS_FIXTURE"
  touch "$SECRETS_FIXTURE/api.key" "$SECRETS_FIXTURE/db.token" "$SECRETS_FIXTURE/ssh.pem"
  export FAKE_UID=1000 FAKE_GID=1000
  FAKE_STAT_DB="$BATS_TEST_TMPDIR/statdb"
  export FAKE_STAT_DB
}

# --- RED trigger ------------------------------------------------------------

@test "RED trigger: scripts/check-secrets-ownership.sh exists and is executable" {
  assert_file_exists "$SCRIPT"
  [ -x "$SCRIPT" ] || { echo "$SCRIPT is not executable" >&2; return 1; }
}

# --- Happy path: safe ownership/mode ----------------------------------------

@test "preflight passes when dir+files owned by invoking user and all files mode 0600" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700   # dir owner 1000 (mode not required on dir)
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 600
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 0
  assert_no_remediation
}

# --- Owner check: must equal the INVOKING user's uid (dynamic, not hardcoded) -

@test "preflight compares owner to the INVOKING user's uid (not a hardcoded value)" {
  export FAKE_UID=1001
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700   # owned by 1000, but invoking user is 1001
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 600
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chown"
  assert_no_remediation
}

@test "preflight fails with chown diagnostic when secrets dir owned by wrong user" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 0 700     # dir owned by root (0), invoking user 1000
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 600
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chown"
  assert_output_contains "1000"          # tells the user the target uid
  assert_output_contains "secrets"       # names the offending path
  assert_no_remediation
}

@test "preflight fails with chown diagnostic when a secret file owned by wrong user" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 0 600   # file owned by root
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chown"
  assert_output_contains "api.key"
  assert_no_remediation
}

# --- Mode check: each file must be EXACTLY 0600 (no group/other read) --------

@test "preflight fails with chmod diagnostic when a secret file is mode 0644" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 644   # group+other read
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chmod"
  assert_output_contains "0600"
  assert_output_contains "api.key"
  assert_no_remediation
}

@test "preflight fails when a secret file has group read bit (mode 0640)" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 640
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chmod"
  assert_no_remediation
}

@test "preflight fails when a secret file has other read bit (mode 0604)" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 604
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chmod"
  assert_no_remediation
}

@test "preflight fails when a secret file is mode 0700 (only exactly 0600 passes)" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 700   # owner-exec, no group/other read
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_output_contains "chmod"
  assert_no_remediation
}

# --- Documentation files in secrets/ are NOT secrets -----------------------

@test "preflight ignores secrets/README.md (documentation) and passes when only README.md would otherwise fail" {
  # README.md is documentation, not a secret: it may be owned by a different
  # user and carry a non-0600 mode. The preflight must NOT treat it as a
  # secret to be owner-matched / chmod 0600.
  touch "$SECRETS_FIXTURE/README.md"
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 600
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  # README.md is intentionally NOT seeded -> mock stat reports owner 0 / mode
  # 000, which would be "unsafe" for a real secret. If the preflight wrongly
  # treats README.md as a secret it will fail; correct behavior is to ignore it.
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 0
  assert_no_remediation
}

# --- Missing path: actionable diagnostic -------------------------------------

@test "preflight fails with diagnostic naming the path when secrets dir is missing" {
  local missing="$BATS_TEST_TMPDIR/does-not-exist"
  run bash "$SCRIPT" "$missing"
  assert_status 1
  assert_output_contains "does-not-exist"
  assert_no_remediation
}

# --- No automatic remediation (dynamic) --------------------------------------

@test "preflight never executes chown/chmod (diagnostics only)" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 0 700          # dir wrong owner
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 644  # file wrong mode
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 1
  assert_no_remediation
}

# --- No recursive chown/chmod (static source inspection) ---------------------

@test "preflight source contains no recursive chown -R / chmod -R" {
  assert_file_exists "$SCRIPT"
  if grep -Eq 'chown[[:space:]]+-R|chmod[[:space:]]+-R' "$SCRIPT"; then
    echo "preflight must not use recursive chown/chmod (-R)" >&2
    return 1
  fi
}

# --- SSH agent is orthogonal ------------------------------------------------

@test "preflight is orthogonal to SSH agent: SSH_AUTH_SOCK set does not change result" {
  : > "$FAKE_STAT_DB"
  seed_stat "$SECRETS_FIXTURE" 1000 700
  seed_stat "$SECRETS_FIXTURE/api.key" 1000 600
  seed_stat "$SECRETS_FIXTURE/db.token" 1000 600
  seed_stat "$SECRETS_FIXTURE/ssh.pem" 1000 600
  SSH_AUTH_SOCK="/tmp/ssh-agent.sock" run bash "$SCRIPT" "$SECRETS_FIXTURE"
  assert_status 0
  assert_output_not_contains "ssh-agent"
  assert_output_not_contains "SSH_AUTH_SOCK"
  assert_no_remediation
}

@test "preflight source does not reference ssh-agent / SSH_AUTH_SOCK" {
  assert_file_exists "$SCRIPT"
  if grep -Eq 'ssh-agent|SSH_AUTH_SOCK' "$SCRIPT"; then
    echo "secrets preflight must not be coupled to SSH agent forwarding" >&2
    return 1
  fi
}
