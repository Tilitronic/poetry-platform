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
# Exits: 0 pass/report-allow, 1 blocked, 2 usage. Every "| grep -q" suspends pipefail around
# its pipeline (grep -q SIGPIPEs the upstream; only grep may decide the match).
set -uo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; }
ok() { printf 'ok: %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
norm() { tr -d '[:space:]' | tr '\047"\140' 'x'; } # B canonicalizer: strip ws, fold quotes; ponytail: literal match only, AST call-shape on observed bypass
trailer() { [ -f "${1:-}" ] && grep -a "^${2}: " "$1" 2>/dev/null | tail -n1 | sed -e "s/^${2}: //" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; } # last "Key: value" wins
CWD_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { fail "budget gate: not inside a git repository"; exit 1; }
ROOT="$CWD_ROOT"; PR_OK=0 # PR_OK=0 with BUDGET_PLUGIN_ROOT set => eval_commit refuses to guess scope (regression-5b)
[ -z "${BUDGET_PLUGIN_ROOT:-}" ] || { case "$BUDGET_PLUGIN_ROOT" in /*) _PR="$BUDGET_PLUGIN_ROOT" ;; *) _PR="$CWD_ROOT/$BUDGET_PLUGIN_ROOT" ;; esac; _RR="$(git -C "$_PR" rev-parse --show-toplevel 2>/dev/null)" && { ROOT="$_RR"; PR_OK=1; }; }
MANIFEST="${BUDGET_MANIFEST:-$ROOT/scripts/budget-baselines.json}"; case "$MANIFEST" in /*) ;; *) MANIFEST="$ROOT/$MANIFEST" ;; esac
case "$MANIFEST" in "$ROOT"/*) MREL="${MANIFEST#"$ROOT"/}" ;; *) MREL="$MANIFEST" ;; esac # outside-repo override: no tree path, never "absent"
TICKETS_DIR="${TICKETS_DIR:-$ROOT/docs/dev-infra-audit/tickets}"; _T="${TICKETS_DIR%/}"; case "$_T" in /*) ;; *) _T="$ROOT/$_T" ;; esac
case "$_T" in "$ROOT"/*) TREL="${_T#"$ROOT"/}" ;; *) TREL="" ;; esac # empty => ledger outside repo => disk fallback
PLUGIN_ROOT="$ROOT/.opencode/plugins"; [ -z "${BUDGET_PLUGIN_ROOT:-}" ] || [ "$PR_OK" -eq 0 ] || PLUGIN_ROOT="$_PR"
case "$PLUGIN_ROOT" in */) PLUGIN_ROOT="${PLUGIN_ROOT%/}" ;; esac; PLUGREL="${PLUGIN_ROOT#"$ROOT"/}"
COMMANDS_DIR="${POETRY_COMMANDS_DIR:-$ROOT/.opencode/commands}"; source "$CWD_ROOT/scripts/guards/home-qualt.sh" 2>/dev/null || true # shared /home/qualt guard (DIA-179)
EVAL_MODE="hook"; EVAL_SHA=""; MSGFILE=""; CHANGED=""; EVAL_FAILS=""; EVAL_OK=""; MANIFEST_OK=0; MERR=""
PROD_CEIL=""; SHELL_CEIL=""; PATTERNS_TSV=""; CAMPAIGNS_TSV=""
tree_show() { if [ "$EVAL_MODE" = "range" ]; then git -C "$ROOT" show "$EVAL_SHA:$1" 2>/dev/null; else git -C "$ROOT" show ":$1" 2>/dev/null; fi; } # staged index / commit tree, never disk
tree_ls() { if [ "$EVAL_MODE" = "range" ]; then git -C "$ROOT" ls-tree -r --name-only -z "$EVAL_SHA" -- "$PLUGREL" 2>/dev/null; else git -C "$ROOT" ls-files -z -- "$PLUGREL" 2>/dev/null; fi; }
manifest_absent() { case "$MANIFEST" in "$ROOT"/*) ! git -C "$ROOT" cat-file -e "$EVAL_SHA:$MREL" 2>/dev/null ;; *) return 1 ;; esac; } # range-only pre-gate probe; outside-repo override is never "absent"
ticket_text() { if [ "$EVAL_MODE" = "range" ] && [ -n "$TREL" ]; then tree_show "$1" 2>/dev/null; else cat "$1" 2>/dev/null; fi; } # tree-first in range mode
find_ticket() { # <prefix>: first sorted ticket path; tree-first in range mode with an in-repo ledger
  if [ "$EVAL_MODE" = "range" ] && [ -n "$TREL" ]; then git -C "$ROOT" ls-tree -r --name-only "$EVAL_SHA" -- "$TREL" 2>/dev/null | while IFS= read -r f; do case "${f##*/}" in "$1"*.md) printf '%s\n' "$f" ;; esac; done | sort | head -n1
  else ls -1 "$TICKETS_DIR/$1"*.md 2>/dev/null | sort | head -n1; fi
  return 0
}
manifest_load() { # fail-closed on any defect; content always from the evaluated tree, never worktree disk
  MANIFEST_OK=0; local c
  c="$(tree_show "$MREL")" || { MERR="budget manifest not found in evaluated tree: $MANIFEST"; return 1; }
  printf '%s' "$c" | jq -e '(.prod_ceiling|type=="number") and (.shell_ceiling|type=="number") and (.patterns|type=="array") and (.campaigns|type=="array") and ([.patterns[]|(.id|type=="string") and (.canonical|type=="string") and (.baseline_count|type=="number") and (.authorized_site|type=="string")]|all) and ([.campaigns[]|(.ticket|type=="string") and (.ticket|length>0) and (.scope|type=="string") and (.status|type=="string")]|all)' >/dev/null 2>&1 || { MERR="budget manifest invalid (not JSON or schema violation): $MANIFEST"; return 1; }
  PROD_CEIL="$(jq -r .prod_ceiling <<<"$c")"; SHELL_CEIL="$(jq -r .shell_ceiling <<<"$c")"
  PATTERNS_TSV="$(jq -r '.patterns[]|[.id,.canonical,(.baseline_count|tostring),.authorized_site]|join("\t")' <<<"$c")"; CAMPAIGNS_TSV="$(jq -r '.campaigns[]|[.scope,.status,.ticket]|join("\t")' <<<"$c")"
  MANIFEST_OK=1
}
has_backing() { # <scope>: approved campaign entry whose named ticket shows status OPEN
  [ -n "${1:-}" ] || return 1
  local line sc st tk tp o
  while IFS= read -r line; do IFS=$'\t' read -r sc st tk <<<"$line"; [ "$sc" = "$1" ] && [ "$st" = "approved" ] || continue
    tp="$(find_ticket "$tk")"; [ -n "$tp" ] || continue
    set +o pipefail; ticket_text "$tp" | grep -q '^status: *OPEN'; o=$?; set -o pipefail # suspend pipefail: grep -q SIGPIPEs upstream (M3)
    [ "$o" -eq 0 ] && return 0
  done <<< "$CAMPAIGNS_TSV"
  return 1
}
eval_commit() { # in: MSGFILE, CHANGED. out: EVAL_FAILS/EVAL_OK. 0 pass, 1 block
  EVAL_FAILS=""; EVAL_OK=""
  local scoped=0 mtch=0 p abs sraw scope backed=0 prod=0 shc=0 both f rel lines line pid pcan pbase pauth nc cnt ms
  if [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && [ "$PR_OK" -eq 0 ]; then # unresolvable override refuses to guess scope (regression-5b)
    EVAL_FAILS="BUDGET_PLUGIN_ROOT does not resolve to a git tree ($BUDGET_PLUGIN_ROOT); refusing to guess scope (unset it or point it at the plugin tree)"; return 1
  fi
  while IFS= read -r p; do abs="$ROOT/$p"; [ "$abs" = "$MANIFEST" ] && mtch=1; case "$abs" in "$PLUGIN_ROOT" | "$PLUGIN_ROOT"/*) scoped=1 ;; esac; done <<< "$CHANGED"
  if [ "$scoped" -eq 0 ] && [ "$mtch" -eq 0 ]; then EVAL_OK="no scoped paths touched; budget gate skipped"; return 0; fi # fast path: no manifest read
  sraw="$(trailer "$MSGFILE" "Budget-Scope")"
  case "$sraw" in refactor | test-debloat | feature) scope="$sraw" ;; *) scope="" ;; esac # unknown scope = absent (feature)
  [ "$MANIFEST_OK" -eq 1 ] || { EVAL_FAILS="budget manifest failed to load ($MERR); failing closed"; return 1; }
  if [ "$scope" = "refactor" ] || [ "$scope" = "test-debloat" ]; then
    has_backing "$scope" && backed=1 || { EVAL_FAILS="Budget-Scope $scope has no approved backing campaign in manifest; failing closed (no backing)"; return 1; }
  fi
  if [ "$mtch" -eq 1 ] && [ "$backed" -ne 1 ]; then # manifest edit: only a backed refactor-family trailer authorizes, no bootstrap bypass
    EVAL_FAILS="manifest edit requires Budget-Scope refactor/test-debloat with approved backing (got '${sraw:-<none>}')"; return 1
  fi
  # A/C from the evaluated tree: delegation-observer.ts = prod+shell, single-level lib/*.ts = prod; block only for backed scopes
  while IFS= read -r -d '' f; do
    rel="${f#"$PLUGREL"/}"
    case "$rel" in delegation-observer.ts) both=1 ;; lib/*.ts) case "${rel#lib/}" in */*) continue ;; esac; both=0 ;; *) continue ;; esac
    lines="$(tree_show "$f" | wc -l)"; lines="${lines// /}"; case "$lines" in '' | *[!0-9]*) lines=0 ;; esac
    prod=$((prod + lines)); [ "$both" -eq 1 ] && shc=$lines
  done < <(tree_ls)
  if [ "$backed" -eq 1 ]; then
    [ "$prod" -gt "$PROD_CEIL" ] && EVAL_FAILS+=$'\n'"production LOC $prod exceeds prod ceiling $PROD_CEIL (scope $scope)"
    [ "$shc" -gt "$SHELL_CEIL" ] && EVAL_FAILS+=$'\n'"shell LOC $shc exceeds shell ceiling $SHELL_CEIL (scope $scope)"
  fi
  # B: unconditional once evaluated; normalize + fixed string over scoped .mjs tests, authorized basename never counts
  while IFS= read -r line; do IFS=$'\t' read -r pid pcan pbase pauth <<<"$line"; nc="$(norm <<<"$pcan")"; cnt=0
    while IFS= read -r -d '' f; do
      case "$f" in *__tests__/*.mjs) ;; *) continue ;; esac
      [ "${f##*/}" = "$pauth" ] && continue
      set +o pipefail; tree_show "$f" | norm | grep -qF -- "$nc"; ms=$?; set -o pipefail # suspend pipefail: grep -q SIGPIPEs the normalizer (M3)
      [ "$ms" -eq 0 ] && cnt=$((cnt + 1))
    done < <(tree_ls)
    case "$pbase" in '' | *[!0-9]*) pbase=0 ;; esac
    [ "$cnt" -gt "$pbase" ] && EVAL_FAILS+=$'\n'"duplication pattern $pid matched $cnt files above baseline $pbase"
  done <<< "$PATTERNS_TSV"
  [ -z "$(tr -d '[:space:]' <<<"$EVAL_FAILS")" ] || return 1
  if [ "$backed" -eq 1 ]; then EVAL_OK="scope $scope backed; prod $prod/$PROD_CEIL shell $shc/$SHELL_CEIL"; else EVAL_OK="feature scope (report-only); prod $prod/$PROD_CEIL shell $shc/$SHELL_CEIL"; fi
  return 0
}
print_fails() { local line; while IFS= read -r line; do [ -n "$line" ] && fail "$line"; done <<< "$EVAL_FAILS"; }
report_warn() { warn "BUDGET_GATE_MODE=report active: budget violations are reported, not blocked (local kill-switch; pre-push --range mode stays blocking)"; }
hook_mode() { # check-budget-gate.sh <message-file> (commit-msg hook)
  MSGFILE="${1:-}"
  [ -n "$MSGFILE" ] || { fail "budget gate usage: check-budget-gate.sh <message-file> | --range <rev>"; exit 2; }
  command -v guard_no_home_qualt >/dev/null 2>&1 && guard_no_home_qualt
  [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && warn "BUDGET_PLUGIN_ROOT override active ($BUDGET_PLUGIN_ROOT): scoping to $PLUGIN_ROOT (fixture/test override; production runs leave it unset)"
  CHANGED="$(git -C "$ROOT" diff --cached --name-only -z 2>/dev/null | tr '\0' '\n')"
  manifest_load || : # fail-closed decision lands in eval_commit; the fast path may not need the manifest
  if eval_commit; then ok "$EVAL_OK"; [ "${BUDGET_GATE_MODE:-}" = "report" ] && report_warn; exit 0; fi
  print_fails
  [ "${BUDGET_GATE_MODE:-}" = "report" ] && { report_warn; exit 0; } # kill-switch: report, never block (hook only; --range ignores)
  exit 1
}
range_mode() { # check-budget-gate.sh --range <rev> (pre-push/CI; always blocking)
  local rev="${1:-}" shas failed=0 sha tmp line
  [ -n "$rev" ] || { fail "budget gate usage: check-budget-gate.sh --range <rev>"; exit 2; }
  shas="$(git -C "$ROOT" rev-list "$rev" 2>/dev/null)" || { fail "budget gate: bad range spec: $rev"; exit 1; }
  EVAL_MODE="range"
  [ -n "$TREL" ] || warn "budget gate: TICKETS_DIR outside gated repo ($TICKETS_DIR); range mode falling back to disk ledger (historical ticket status not per-commit; no warn per commit)"
  tmp="$(mktemp)"
  for sha in $shas; do
    EVAL_SHA="$sha"; MANIFEST_OK=0 # reset: a prior commit's success must not mask this commit's load failure
    if ! manifest_load && manifest_absent; then # pre-gate-history exemption: no baselines in tree => skip WITH a mandatory warn (never silently)
      warn "budget gate: no manifest in commit ${sha:0:12} ($MREL absent from tree); skipping pre-gate-history commit"
      ok "$sha skipped (pre-gate-history: no manifest in tree)"
      continue
    fi
    git -C "$ROOT" log -1 --format=%B "$sha" > "$tmp" 2>/dev/null; MSGFILE="$tmp"
    CHANGED="$(git -C "$ROOT" diff-tree --no-commit-id --name-only -r --root "$sha" 2>/dev/null)"
    if eval_commit; then ok "$sha $EVAL_OK"
    else
      failed=1; fail "commit $sha blocked:"
      while IFS= read -r line; do [ -n "$line" ] && fail "[${sha:0:12}] $line"; done <<< "$EVAL_FAILS"
    fi
  done
  rm -f "$tmp"; exit "$failed"
}
if [ "${1:-}" = "--range" ]; then range_mode "${2:-}"; else hook_mode "${1:-}"; fi
