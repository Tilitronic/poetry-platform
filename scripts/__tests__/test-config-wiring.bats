#!/usr/bin/env bats
# Wiring regression for the `make test-config` target (change
# dev-infra-config-validators, task T4). Structural checks over the root
# Makefile: static greps assert the test-config target body references both
# new validators (validate-agent-names.sh + validate-handoff.sh) alongside the
# pre-existing validate-opencode-config.sh, and a `make -n` dry-run asserts the
# host-scoped skip note and the test-typecheck prerequisite (DIA-260928-gpcc:
# the typecheck seam lives HERE now; scripts/__tests__/typecheck-target.bats
# was retired because its unanchored whole-file substring grep went false-green
# on a commented-out prerequisite and false-red on a harmless reorder).
#
# The other config validators are unit-tested hermetically in
# validate-agent-names.bats / validate-handoff.bats; this suite guards the
# Makefile wiring seam so a future edit cannot silently drop the validators
# (or the typecheck) from the config gate. DIA-260827-ft3z adds behavioral
# coverage for validate-opencode-config.sh itself - the --lockstep permission-
# clone gate (coder + analyzer base/escalated pairs) and the --doc-drift
# deny-first doc-contract gate - because no dedicated
# validate-opencode-config.bats exists; fixtures live under $BATS_TEST_TMPDIR
# and the real repo config is exercised by the passing-gate test.

load test-helper

# DIA-260827-ft3z: the behavioral tests below run the validator library with
# node. Resolve it up front and skip with a clear message when absent (same
# contract as overnight.bats).
NODE_BIN="$(command -v node || true)"
LIB="$REPO_ROOT/.opencode/scripts/lib/jsonc-parse.js"
VALIDATOR="$REPO_ROOT/.opencode/scripts/validate-opencode-config.sh"

@test "test-config wiring: Makefile references both new validators" {
  # Each new validator must appear in the test-config target body. The recipe
  # line form is `bash scripts/<name>.sh` (same shape as validate-opencode-config.sh).
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-agent-names.sh"
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-handoff.sh"
  # Pre-existing baseline preserved: validate-opencode-config.sh still wired.
  assert_file_contains "$REPO_ROOT/Makefile" "bash .opencode/scripts/validate-opencode-config.sh"
}

@test "test-config wiring: Makefile emits visible host-scoped skip note (P2, DIA-260922-cp0m)" {
  # P2: the test-config recipe must print a visible @echo noting that
  # compose-config validation is host-scoped and runs host-side. This prevents
  # silent coverage shrinkage (the PHASE 3 false-green lesson).
  #
  # Discriminating pin: `make -n` (dry-run) outputs recipe lines but NOT
  # comments. The old `# NOTE:` comment form produces ZERO matches in
  # `make -n` output; the `@echo` form produces exactly one. This assertion
  # would FAIL against the unfixed Makefile.
  local dry_run_output
  dry_run_output="$(make -C "$REPO_ROOT" -n test-config 2>/dev/null)"
  echo "$dry_run_output" | grep -q "compose config validation is host-scoped"
  # DIA-260928-gpcc: same dry-run must schedule the typecheck. Asserting on
  # make's dependency GRAPH (the expanded recipe), not on the Makefile text,
  # so a commented-out prerequisite reddens while a harmless reorder stays
  # green - the exact false-green/false-red pair the retired
  # typecheck-target.bats whole-file substring grep had.
  echo "$dry_run_output" | grep -q "==> typecheck .opencode/plugins"
  echo "$dry_run_output" | grep -q "npx --no-install tsc --noEmit -p .opencode/plugins/tsconfig.json"
}

@test "typecheck wiring: scoped project pins isolatedModules and excludes .scratch (DIA-260928-gpcc)" {
  # The two established values of the plugin tsconfig, asserted by PARSING the
  # JSON rather than by text matching: the invariant is "the two syntax-model
  # flags (isolatedModules and erasableSyntaxOnly) are on" and "the scratch
  # tree is excluded", so a future `.scratch` ->
  # `**/.scratch` spelling change keeps the test green.
  cd "$REPO_ROOT" # the snippet below uses a relative path; pin the CWD
  run python3 -c "import json,sys; c=json.load(open('.opencode/plugins/tsconfig.json')); co=c['compilerOptions']; assert co['isolatedModules'] is True; assert co['erasableSyntaxOnly'] is True; ex=c['exclude']; assert any(e.endswith('.scratch') for e in ex)"
  [ "$status" -eq 0 ]
  # Real invariant kept from the retired suite: test-typecheck stays listed in
  # .PHONY (same idiom: pin the single .PHONY line, then fixed-string grep).
  local phony_line
  phony_line="$(grep -F '.PHONY:' "$REPO_ROOT/Makefile")"
  run grep -Fq 'test-typecheck' <<<"$phony_line"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# DIA-260827-ft3z: validator behavior - permission lockstep (check A) and
# deny-first doc contract (check B). Every failure case builds a MUTATED
# fixture under $BATS_TEST_TMPDIR and asserts the validator exits 1 with an
# actionable message; the clean-fixture and real-config tests assert exit 0.
# ---------------------------------------------------------------------------

@test "validator: analyzer vs analyzer-escalated permission divergence fails lockstep (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/lockstep-diverge"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "doom_loop": "deny", "task": "deny", "bash": { "*": "deny" } } },
    "coder-escalated": { "permission": { "doom_loop": "deny", "bash": { "*": "deny" }, "task": "deny" } },
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "rg *": "allow" }, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  # names both agents and the differing path inside the permission object
  assert_output_contains "analyzer / analyzer-escalated permission lockstep broken"
  assert_output_contains "value differs at bash"
  # the coder pair in the same fixture is clean - the failure stays isolated
  assert_output_not_contains "coder / coder-escalated permission lockstep broken"
}

@test "validator: deny-first agent md claiming bash: allow fails doc-drift (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/doc-md-forbidden"
  mkdir -p "$tree/.opencode/agents"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "analyzer": { "permission": { "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
This prose claims bash: allow for the jq, rg, wc enum.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-first doc contract drift"
  assert_output_contains "analyzer.md:2"
  assert_output_contains "bash: allow"
}

@test "validator: deny-first orchestratorPrompt claiming Mermaid CLI fails doc-drift (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/doc-prompt-forbidden"
  mkdir -p "$tree/.opencode/agents"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "analyzer": { "permission": { "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "analyzer": { "orchestratorPrompt": "analyzer\n- renders diagrams with Mermaid CLI" } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-first doc contract drift"
  assert_output_contains "agents.analyzer.orchestratorPrompt"
  assert_output_contains "Mermaid CLI"
}

@test "validator: clean fixture tree passes lockstep and doc-drift (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/clean-fixture"
  mkdir -p "$tree/.opencode/agents"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } }
  }
}
JSONC
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "analyzer": { "orchestratorPrompt": "analyzer\n- bash limited to jq, rg, wc; else deny" } } }
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: analyzer/analyzer-escalated permission lockstep"
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: deny-first doc contract"
}

@test "validator: agent without a bash map is out of scope for doc-drift (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/no-bash-map"
  mkdir -p "$tree/.opencode/agents"
  # analyzer is deny-first with clean docs (counted); prompt-only-agent has no
  # bash permission at all, so its forbidden md must be IGNORED by check B.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "bash": { "*": "deny", "jq *": "allow" } } },
    "prompt-only-agent": { "permission": { "edit": { "*": "deny" } } }
  }
}
JSONC
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/agents/prompt-only-agent.md" <<'MD'
# prompt-only-agent
This doc claims bash: allow but the agent has no bash map at all.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "1 deny-first agents"
}

@test "validator: real repo config passes the full gate (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run validate-opencode-config.sh"
  run bash "$VALIDATOR"
  assert_status 0
  # both new check modes are wired into the entry point (their ok lines only
  # print when the shell script invokes them)
  assert_output_contains "ok: analyzer/analyzer-escalated permission lockstep"
  assert_output_contains "ok: deny-first doc contract"
  assert_output_contains "ok: all OpenCode config files are valid JSONC"
}
