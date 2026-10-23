#!/usr/bin/env bash
# check-budget-gate.sh <msg-file> | --range <rev> -- F-budget gate (DIA-260903-o7n0;
# Budget-Exception flow removed 2026-10-23 DIA-261023-jdx3, never used by a real commit).
# Budgets come from budget-baselines.json in the EVALUATED tree (staged index in hook mode,
# per-commit tree in --range), never the worktree. Hook: Budget-Scope refactor/test-debloat
# needs an approved campaign ticket with status OPEN else A/C LOC ceilings block; B
# (duplication) is unconditional; staged manifest edits need a backed refactor-family trailer.
# --range always blocks, skipping with a warn any commit whose tree lacks the manifest.
# Env: BUDGET_MANIFEST, TICKETS_DIR, BUDGET_PLUGIN_ROOT (fixture seam; unresolvable => fail
# closed), BUDGET_GATE_MODE=report (hook only: report+warn, never blocks; --range ignores it).
# Exits: 0 pass/report-allow, 1 blocked, 2 usage (eval_commit also returns 2 internally for
# the range-only pre-gate-history skip). Every "| grep -q" suspends pipefail around its
# pipeline (grep -q SIGPIPEs the upstream; only grep may decide the match).
set -uo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; }
ok() { printf 'ok: %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
# canonicalize: B-detector canonicalizer -- strip all whitespace, fold quote bytes so
# re-indent/line-split/quote-flip cannot evade the fixed-string match. ponytail: literal
# match only; string-concat splitting and identifier renaming evade this. Upgrade path:
# AST call-shape match. Trigger: an observed real bypass, not a hypothetical one.
canonicalize() { tr -d '[:space:]' | tr '\047"\140' 'x'; }
# parse_trailer <file> <key>: last "Key: value" occurrence wins; empty when absent.
parse_trailer() {
  [ -f "${1:-}" ] || return 0
  grep -a "^${2}: " "$1" 2>/dev/null | tail -n1 |
    sed -e "s/^${2}: //" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
CWD_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  fail "budget gate: not inside a git repository"
  exit 1
}
# Gated-repo discovery: an explicit BUDGET_PLUGIN_ROOT relocates the gated repo to the
# tree that owns the scoped plugin paths (fixture seam); a set-but-unresolvable override
# keeps plugin_root_ok=0 so eval_commit fails closed rather than silently scoping nothing.
ROOT="$CWD_ROOT"
plugin_root_ok=0
if [ -n "${BUDGET_PLUGIN_ROOT:-}" ]; then
  case "$BUDGET_PLUGIN_ROOT" in /*) plugin_probe="$BUDGET_PLUGIN_ROOT" ;; *) plugin_probe="$CWD_ROOT/$BUDGET_PLUGIN_ROOT" ;; esac
  if probe_root="$(git -C "$plugin_probe" rev-parse --show-toplevel 2>/dev/null)"; then
    ROOT="$probe_root"
    plugin_root_ok=1
  fi
fi
MANIFEST="${BUDGET_MANIFEST:-$ROOT/scripts/budget-baselines.json}"
case "$MANIFEST" in /*) ;; *) MANIFEST="$ROOT/$MANIFEST" ;; esac
case "$MANIFEST" in "$ROOT"/*) manifest_rel="${MANIFEST#"$ROOT"/}" ;; *) manifest_rel="$MANIFEST" ;; esac # outside-repo override: no tree path, never "absent"
TICKETS_DIR="${TICKETS_DIR:-$ROOT/docs/dev-infra-audit/tickets}"
tickets_dir_abs="${TICKETS_DIR%/}"
case "$tickets_dir_abs" in /*) ;; *) tickets_dir_abs="$ROOT/$tickets_dir_abs" ;; esac
case "$tickets_dir_abs" in "$ROOT"/*) tickets_rel="${tickets_dir_abs#"$ROOT"/}" ;; *) tickets_rel="" ;; esac # empty => ledger outside repo => disk fallback
PLUGIN_ROOT="$ROOT/.opencode/plugins"
if [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && [ "$plugin_root_ok" -eq 1 ]; then
  PLUGIN_ROOT="$plugin_probe"
fi
case "$PLUGIN_ROOT" in */) PLUGIN_ROOT="${PLUGIN_ROOT%/}" ;; esac
plugin_rel="${PLUGIN_ROOT#"$ROOT"/}"
COMMANDS_DIR="${POETRY_COMMANDS_DIR:-$ROOT/.opencode/commands}"
source "$CWD_ROOT/scripts/guards/home-qualt.sh" 2>/dev/null || true # shared /home/qualt guard (DIA-179)
EVAL_MODE="hook"; EVAL_SHA=""; SKIP_WARN=""; MSGFILE=""; CHANGED=""; EVAL_FAILS=""; EVAL_OK=""
manifest_ok=0; manifest_err=""; PROD_CEIL=""; SHELL_CEIL=""; PATTERNS_TSV=""; CAMPAIGNS_TSV=""
# tree_show <repo-rel-path>: blob bytes of the EVALUATED tree (staged index in hook mode
# via "git show :path", commit tree in range mode via "git show $EVAL_SHA:path") -- never disk.
tree_show() {
  if [ "$EVAL_MODE" = "range" ]; then git -C "$ROOT" show "$EVAL_SHA:$1" 2>/dev/null
  else git -C "$ROOT" show ":$1" 2>/dev/null; fi
}
tree_ls() {
  if [ "$EVAL_MODE" = "range" ]; then git -C "$ROOT" ls-tree -r --name-only -z "$EVAL_SHA" -- "$plugin_rel" 2>/dev/null
  else git -C "$ROOT" ls-files -z -- "$plugin_rel" 2>/dev/null; fi
}
# manifest_absent: range-only pre-gate probe; an outside-repo manifest override is
# never "absent" (it fails closed instead).
manifest_absent() {
  case "$MANIFEST" in
    "$ROOT"/*) ! git -C "$ROOT" cat-file -e "$EVAL_SHA:$manifest_rel" 2>/dev/null ;;
    *) return 1 ;;
  esac
}
# ticket_text <ref>: approval-record bytes; tree-first in range mode with an in-repo ledger.
ticket_text() {
  if [ "$EVAL_MODE" = "range" ] && [ -n "$tickets_rel" ]; then tree_show "$1" 2>/dev/null
  else cat "$1" 2>/dev/null; fi
}
# find_ticket <id-prefix>: first sorted ticket path; tree-first in range mode with an in-repo ledger.
find_ticket() {
  if [ "$EVAL_MODE" = "range" ] && [ -n "$tickets_rel" ]; then
    git -C "$ROOT" ls-tree -r --name-only "$EVAL_SHA" -- "$tickets_rel" 2>/dev/null |
      while IFS= read -r file; do
        case "${file##*/}" in "$1"*.md) printf '%s\n' "$file" ;; esac
      done | sort | head -n1
  else
    ls -1 "$TICKETS_DIR/$1"*.md 2>/dev/null | sort | head -n1
  fi
  return 0
}
manifest_load() { # fail-closed on any defect; content always from the evaluated tree, never worktree disk
  manifest_ok=0
  local manifest_content
  manifest_content="$(tree_show "$manifest_rel")" || {
    manifest_err="budget manifest not found in evaluated tree: $MANIFEST"
    return 1
  }
  printf '%s' "$manifest_content" | jq -e '(.prod_ceiling|type=="number") and (.shell_ceiling|type=="number") and (.patterns|type=="array") and (.campaigns|type=="array") and ([.patterns[]|(.id|type=="string") and (.canonical|type=="string") and (.baseline_count|type=="number") and (.authorized_site|type=="string")]|all) and ([.campaigns[]|(.ticket|type=="string") and (.ticket|length>0) and (.scope|type=="string") and (.status|type=="string")]|all)' >/dev/null 2>&1 || {
    manifest_err="budget manifest invalid (not JSON or schema violation): $MANIFEST"
    return 1
  }
  PROD_CEIL="$(jq -r .prod_ceiling <<<"$manifest_content")"
  SHELL_CEIL="$(jq -r .shell_ceiling <<<"$manifest_content")"
  PATTERNS_TSV="$(jq -r '.patterns[]|[.id,.canonical,(.baseline_count|tostring),.authorized_site]|join("\t")' <<<"$manifest_content")"
  CAMPAIGNS_TSV="$(jq -r '.campaigns[]|[.scope,.status,.ticket]|join("\t")' <<<"$manifest_content")"
  manifest_ok=1
}
has_backing() { # <scope>: approved campaign entry whose named ticket shows status OPEN
  [ -n "${1:-}" ] || return 1
  local line campaign_scope campaign_status campaign_ticket ticket_path open_status
  while IFS= read -r line; do
    IFS=$'\t' read -r campaign_scope campaign_status campaign_ticket <<<"$line"
    [ "$campaign_scope" = "$1" ] && [ "$campaign_status" = "approved" ] || continue
    ticket_path="$(find_ticket "$campaign_ticket")"
    [ -n "$ticket_path" ] || continue
    # suspend pipefail: grep -q SIGPIPEs upstream git show/cat (M3)
    set +o pipefail
    ticket_text "$ticket_path" | grep -q '^status: *OPEN'
    open_status=$?
    set -o pipefail
    [ "$open_status" -eq 0 ] && return 0
  done <<< "$CAMPAIGNS_TSV"
  return 1
}
eval_commit() { # in: MSGFILE, CHANGED. out: EVAL_FAILS/EVAL_OK/SKIP_WARN. 0 pass, 1 block, 2 range skip
  EVAL_FAILS=""; EVAL_OK=""; SKIP_WARN=""
  local scoped=0 manifest_touched=0 path abs_path scope_raw scope backed=0
  local prod_lines=0 shell_lines=0 is_observer file rel_path line_count
  local line pattern_id pattern_canonical pattern_baseline pattern_authorized_site
  local normalized_canonical match_count match_status
  if [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && [ "$plugin_root_ok" -eq 0 ]; then # unresolvable override refuses to guess scope (regression-5b)
    EVAL_FAILS="BUDGET_PLUGIN_ROOT does not resolve to a git tree ($BUDGET_PLUGIN_ROOT); refusing to guess scope (unset it or point it at the plugin tree)"
    return 1
  fi
  while IFS= read -r path; do
    abs_path="$ROOT/$path"
    [ "$abs_path" = "$MANIFEST" ] && manifest_touched=1
    case "$abs_path" in "$PLUGIN_ROOT" | "$PLUGIN_ROOT"/*) scoped=1 ;; esac
  done <<< "$CHANGED"
  # Fast path: nothing scoped and no manifest edit -> pass WITHOUT reading the manifest
  # (design.md: untouched-path commits never depend on manifest state).
  if [ "$scoped" -eq 0 ] && [ "$manifest_touched" -eq 0 ]; then
    EVAL_OK="no scoped paths touched; budget gate skipped"
    return 0
  fi
  if ! manifest_load; then
    # Pre-gate-history exemption (range mode only): a commit whose tree predates the
    # manifest holds no baselines to evaluate against, so skip it WITH a mandatory warn
    # line (never silently). A tree that HAS the manifest keeps fail-closed behavior.
    if [ "$EVAL_MODE" = "range" ] && manifest_absent; then
      SKIP_WARN="budget gate: no manifest in commit ${EVAL_SHA:0:12} ($manifest_rel absent from tree); skipping pre-gate-history commit"
      EVAL_OK="$EVAL_SHA skipped (pre-gate-history: no manifest in tree)"
      return 2
    fi
    EVAL_FAILS="budget manifest failed to load ($manifest_err); failing closed"
    return 1
  fi
  scope_raw="$(parse_trailer "$MSGFILE" "Budget-Scope")"
  case "$scope_raw" in
    refactor | test-debloat | feature) scope="$scope_raw" ;;
    *) scope="" ;; # unknown scope = absent (feature)
  esac
  if [ "$scope" = "refactor" ] || [ "$scope" = "test-debloat" ]; then
    if has_backing "$scope"; then
      backed=1
    else
      EVAL_FAILS="Budget-Scope $scope has no approved backing campaign in manifest; failing closed (no backing)"
      return 1
    fi
  fi
  if [ "$manifest_touched" -eq 1 ] && [ "$backed" -ne 1 ]; then # manifest edit: only a backed refactor-family trailer authorizes
    EVAL_FAILS="manifest edit requires Budget-Scope refactor/test-debloat with approved backing (got '${scope_raw:-<none>}')"
    return 1
  fi
  # A/C from the evaluated tree: delegation-observer.ts = prod+shell, single-level lib/*.ts
  # = prod; block only for backed scopes.
  while IFS= read -r -d '' file; do
    rel_path="${file#"$plugin_rel"/}"
    case "$rel_path" in
      delegation-observer.ts) is_observer=1 ;;
      lib/*.ts) case "${rel_path#lib/}" in */*) continue ;; esac; is_observer=0 ;;
      *) continue ;;
    esac
    line_count="$(tree_show "$file" | wc -l)"
    line_count="${line_count// /}"
    case "$line_count" in '' | *[!0-9]*) line_count=0 ;; esac
    prod_lines=$((prod_lines + line_count))
    [ "$is_observer" -eq 1 ] && shell_lines=$line_count
  done < <(tree_ls)
  if [ "$backed" -eq 1 ]; then
    [ "$prod_lines" -gt "$PROD_CEIL" ] && EVAL_FAILS+=$'\n'"production LOC $prod_lines exceeds prod ceiling $PROD_CEIL (scope $scope)"
    [ "$shell_lines" -gt "$SHELL_CEIL" ] && EVAL_FAILS+=$'\n'"shell LOC $shell_lines exceeds shell ceiling $SHELL_CEIL (scope $scope)"
  fi
  # B detector: unconditional once evaluated; normalize + fixed string over scoped .mjs
  # test files, authorized basename never counts.
  while IFS= read -r line; do
    IFS=$'\t' read -r pattern_id pattern_canonical pattern_baseline pattern_authorized_site <<<"$line"
    normalized_canonical="$(canonicalize <<<"$pattern_canonical")"
    [ -n "$normalized_canonical" ] || continue # empty pattern set / empty canonical: nothing to match (P1)
    match_count=0
    while IFS= read -r -d '' file; do
      case "$file" in *__tests__/*.mjs) ;; *) continue ;; esac
      [ "${file##*/}" = "$pattern_authorized_site" ] && continue
      # suspend pipefail: grep -q SIGPIPEs the upstream canonicalizer (M3)
      set +o pipefail
      tree_show "$file" | canonicalize | grep -qF -- "$normalized_canonical"
      match_status=$?
      set -o pipefail
      [ "$match_status" -eq 0 ] && match_count=$((match_count + 1))
    done < <(tree_ls)
    case "$pattern_baseline" in '' | *[!0-9]*) pattern_baseline=0 ;; esac
    [ "$match_count" -gt "$pattern_baseline" ] && EVAL_FAILS+=$'\n'"duplication pattern $pattern_id matched $match_count files above baseline $pattern_baseline"
  done <<< "$PATTERNS_TSV"
  [ -z "$(tr -d '[:space:]' <<<"$EVAL_FAILS")" ] || return 1
  if [ "$backed" -eq 1 ]; then EVAL_OK="scope $scope backed; prod $prod_lines/$PROD_CEIL shell $shell_lines/$SHELL_CEIL"
  else EVAL_OK="feature scope (report-only); prod $prod_lines/$PROD_CEIL shell $shell_lines/$SHELL_CEIL"; fi
  return 0
}
print_fails() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$line"
  done <<< "$EVAL_FAILS"
}
report_warn() { warn "BUDGET_GATE_MODE=report active: budget violations are reported, not blocked (local kill-switch; pre-push --range mode stays blocking)"; }
hook_mode() { # check-budget-gate.sh <message-file> (commit-msg hook)
  MSGFILE="${1:-}"
  if [ -z "$MSGFILE" ]; then
    fail "budget gate usage: check-budget-gate.sh <message-file> | --range <rev>"
    exit 2
  fi
  command -v guard_no_home_qualt >/dev/null 2>&1 && guard_no_home_qualt
  [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && warn "BUDGET_PLUGIN_ROOT override active ($BUDGET_PLUGIN_ROOT): scoping to $PLUGIN_ROOT (fixture/test override; production runs leave it unset)"
  CHANGED="$(git -C "$ROOT" diff --cached --name-only -z 2>/dev/null | tr '\0' '\n')"
  # manifest_load runs inside eval_commit AFTER the fast path (design.md: the fast path
  # exits 0 without reading the manifest).
  if eval_commit; then
    ok "$EVAL_OK"
    [ "${BUDGET_GATE_MODE:-}" = "report" ] && report_warn
    exit 0
  fi
  print_fails
  [ "${BUDGET_GATE_MODE:-}" = "report" ] && { report_warn; exit 0; } # kill-switch: report, never block (hook only; --range ignores)
  exit 1
}
range_mode() { # check-budget-gate.sh --range <rev> (pre-push/CI; always blocking)
  local rev="${1:-}" rev_list any_failed=0 sha tmp_msg line rc
  if [ -z "$rev" ]; then
    fail "budget gate usage: check-budget-gate.sh --range <rev>"
    exit 2
  fi
  rev_list="$(git -C "$ROOT" rev-list "$rev" 2>/dev/null)" || {
    fail "budget gate: bad range spec: $rev"
    exit 1
  }
  EVAL_MODE="range"
  [ -n "$tickets_rel" ] || warn "budget gate: TICKETS_DIR outside gated repo ($TICKETS_DIR); range mode falling back to disk ledger (historical ticket status not per-commit; no warn per commit)"
  tmp_msg="$(mktemp)"
  for sha in $rev_list; do
    EVAL_SHA="$sha" # manifest_ok resets inside manifest_load; a prior commit's verdict cannot mask this one
    git -C "$ROOT" log -1 --format=%B "$sha" > "$tmp_msg" 2>/dev/null
    MSGFILE="$tmp_msg"
    CHANGED="$(git -C "$ROOT" diff-tree --no-commit-id --name-only -r --root "$sha" 2>/dev/null)"
    eval_commit
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "$sha $EVAL_OK"
    elif [ "$rc" -eq 2 ]; then # pre-gate-history skip signalled by eval_commit (warn is mandatory, never silent)
      warn "$SKIP_WARN"
      ok "$EVAL_OK"
    else
      any_failed=1
      fail "commit $sha blocked:"
      while IFS= read -r line; do
        [ -n "$line" ] && fail "[${sha:0:12}] $line"
      done <<< "$EVAL_FAILS"
    fi
  done
  rm -f "$tmp_msg"
  exit "$any_failed"
}
if [ "${1:-}" = "--range" ]; then
  range_mode "${2:-}"
else
  hook_mode "${1:-}"
fi
