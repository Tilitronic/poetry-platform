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

# M3 (DIA-260827-ft3z): the analyzer pair markdown is a REQUIRED surface of
# every --doc-drift run (a missing file is a failure, not a skip), so each
# fixture tree carries both documents or the positive-marker failure drowns the
# assertion under test. Tests that need a custom analyzer.md call this first
# and overwrite the file afterwards.
require_analyzer_docs() {
  local tree="$1"
  mkdir -p "$tree/.opencode/agents"
  printf '# analyzer\ndeny-first bash contract.\n' > "$tree/.opencode/agents/analyzer.md"
  printf '# analyzer-escalated\ndeny-first bash contract.\n' > "$tree/.opencode/agents/analyzer-escalated.md"
}

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
  require_analyzer_docs "$tree"
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
  require_analyzer_docs "$tree"
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
    "coder": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "coder-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } },
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } }
  }
}
JSONC
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/agents/analyzer-escalated.md" <<'MD'
# analyzer-escalated
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "analyzer": { "orchestratorPrompt": "analyzer\n- bash limited to jq, rg, wc; else deny" } } }
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: analyzer/analyzer-escalated permission lockstep"
  # depth-honest success line (G1): top-level keys AND leaf rules, plus the
  # agent names actually compared. Fixture permission = edit(2) + bash(2) + task(1).
  assert_output_contains "(3 keys, 5 rules: analyzer, analyzer-escalated)"
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
  # Its permission block deliberately declares NO edit key either: an
  # edit-deny-scoped agent with no bash map is the G2 invariant violation, and
  # that case has its own fixture below.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "bash": { "*": "deny", "jq *": "allow" } } },
    "prompt-only-agent": { "permission": { "task": "deny" } }
  }
}
JSONC
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/agents/analyzer-escalated.md" <<'MD'
# analyzer-escalated
bash: deny-first enum - jq, rg, wc; everything else denied.
MD
  cat > "$tree/.opencode/agents/prompt-only-agent.md" <<'MD'
# prompt-only-agent
This doc claims bash: allow but the agent has no bash map at all.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 0
  # only analyzer is bash-restricted here; prompt-only-agent has no bash key
  # and no global block in the fixture, so it stays out of scope.
  assert_output_contains "1 in-scope agents: analyzer"
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
  # G1 depth honesty on the REAL maps: analyzer permission is edit(2) +
  # bash(1) + task(1) = 4 leaf rules behind 3 top-level keys (bash is now the
  # flat string "deny", so it contributes one leaf rule, not a 23-rule object).
  assert_output_contains "(3 keys, 4 rules: analyzer, analyzer-escalated)"
  # G3 widened scope on the REAL tree: the eight flat-"deny" agents plus the
  # deny-first object maps. DIA-260827-ft3z design D1/D6 moved three more
  # lanes INTO scope: researcher and designer now carry flat "bash": "deny"
  # and memory-manager a deny-first map, so all three are checked for
  # flat-allow doc claims (15 total; before the migration it was 12, with
  # researcher OUT on purpose behind its curl/wget allow-list).
  assert_output_contains "15 in-scope agents"
  assert_output_contains "orchestrator, architector, analyzer, analyzer-escalated, reviewer, code-navigator"
}

@test "config: analyzer maps pin bash as the flat string deny with no allow rules and matching edit/task (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  # No-shell pin (DIA-260827-ft3z): both analyzer lanes dropped the deny-first
  # bash OBJECT for the flat string "deny" - they have no shell at all. Parses
  # the REAL .opencode/opencode.jsonc with the SAME JSONC parser the config
  # gate uses - jsonc-parse.js exports no module API, so its function
  # definitions (everything before the CLI argv dispatch) are evaluated here
  # instead of writing a second parser. What it pins:
  #   1. bash is EXACTLY the string "deny" in both maps - not an object, not
  #      a deny-first enum that merely looks closed;
  #   2. no bash allow rule survives of any kind: the jq/rg/wc enum entries,
  #      the data-reduce wrapper forms, the fixed-path query_rag.py form, the
  #      bare+starred openspec subcommands and the whole rg --pre deny block
  #      are ALL gone (the ordering constraint the previous case pinned - deny
  #      after allow - has no meaning without an allow to shadow);
  #   3. the edit map and the task value are present and identical between
  #      the two lanes, so lockstep equality is not vacuous on a shared hole.
  # Fails against the pre-996aa9aa config (23-rule bash object per lane) and
  # against any reintroduction of a single allow rule.
  run "$NODE_BIN" -e '
    const fs = require("fs");
    const lib = process.argv[1];
    const file = process.argv[2];
    const src = fs.readFileSync(lib, "utf8");
    const marker = "const args = process.argv.slice(2);";
    const cut = src.indexOf(marker);
    if (cut < 0) { console.error("jsonc-parse.js layout changed: marker not found: " + marker); process.exit(2); }
    const mod = { exports: {} };
    new Function("require", "module", "exports", src.slice(0, cut) + "\nmodule.exports = { parseJsonc };")(require, mod, mod.exports);
    const cfg = mod.exports.parseJsonc(file);
    // Every shape the abandoned object map used to carry: enum allows, the
    // data-reduce wrapper, the fixed-path query helper, the openspec
    // subcommands and the preprocessor deny block.
    const GONE = ["jq", "rg", "wc", "data-reduce", "query_rag.py", "openspec", "--pre"];
    const problems = [];
    for (const name of ["analyzer", "analyzer-escalated"]) {
      const perm = (cfg.agent[name] || {}).permission || {};
      const bash = perm.bash;
      if (bash !== "deny") problems.push(name + ": bash is " + JSON.stringify(bash) + ", expected the flat string \"deny\"");
      if (bash && typeof bash === "object") {
        for (const k of Object.keys(bash)) {
          if (bash[k] === "allow") problems.push(name + ": bash still carries an allow rule: " + k);
          for (const g of GONE) if (k.includes(g)) problems.push(name + ": bash still lists the abandoned " + g + " form: " + k);
        }
      }
    }
    const a = (cfg.agent["analyzer"] || {}).permission || {};
    const b = (cfg.agent["analyzer-escalated"] || {}).permission || {};
    if (!a.edit || !b.edit) problems.push("edit map missing on a lane: analyzer=" + JSON.stringify(a.edit) + " analyzer-escalated=" + JSON.stringify(b.edit));
    else if (JSON.stringify(a.edit) !== JSON.stringify(b.edit)) problems.push("edit maps differ between analyzer and analyzer-escalated: " + JSON.stringify(a.edit) + " vs " + JSON.stringify(b.edit));
    if (!("task" in a) || !("task" in b)) problems.push("task value missing on a lane: analyzer=" + JSON.stringify(a.task) + " analyzer-escalated=" + JSON.stringify(b.task));
    else if (a.task !== b.task) problems.push("task values differ between analyzer and analyzer-escalated: " + JSON.stringify(a.task) + " vs " + JSON.stringify(b.task));
    if (problems.length > 0) { console.error(problems.join("\n")); process.exit(1); }
    console.log("ok: analyzer maps pin bash as the flat string deny with no allow rules and matching edit/task");
  ' "$LIB" "$REPO_ROOT/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: analyzer maps pin bash as the flat string deny with no allow rules and matching edit/task"
}

# ---------------------------------------------------------------------------
# DIA-260827-ft3z G1/G2/G3 hardening: non-vacuous lockstep, semantic
# restriction + edit/bash invariant, widened check-B scope and matching.
# ---------------------------------------------------------------------------

@test "validator: missing analyzer pair members fail lockstep instead of a vacuous green (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/lockstep-missing"
  mkdir -p "$tree/.opencode"
  # Both analyzer entries removed. The old gate picked an empty object for both
  # sides, compared nothing and printed "0 keys compared" - green with zero
  # coverage. The coder pair in the same fixture is clean and must stay green.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "coder-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'pair analyzer/analyzer-escalated: missing member "analyzer"'
  assert_output_contains 'pair analyzer/analyzer-escalated: missing member "analyzer-escalated"'
  assert_output_not_contains "0 keys compared"
  assert_output_not_contains "ok: analyzer/analyzer-escalated"
  assert_output_not_contains "coder / coder-escalated permission lockstep broken"
}

@test "validator: both analyzer members flat bash allow fail the edit/bash invariant (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/flat-allow-pair"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # Coordinated regression of BOTH pair members to a flat "bash": "allow": the
  # lockstep equality check still passes (they are equal), the old key-position
  # predicate skipped them (not an object), and nothing failed. The G2 invariant
  # is what closes it.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": "allow", "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": "allow", "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-scoped edit with unrestricted bash"
  assert_output_contains "analyzer: edit is deny-scoped but bash is not"
  assert_output_contains "analyzer-escalated: edit is deny-scoped but bash is not"
  # flat allow is not deny-scoped, so these two are OUT of the doc-drift scope
  assert_output_not_contains "deny-first doc contract drift"
}

@test "validator: catch-all key order is read semantically, not by key position (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/key-order"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  # {"jq *":"allow","*":"allow"}: the catch-all is NOT first, so a key-position
  # predicate mis-reads it as deny-first and skips it. Under last-match-wins it
  # is flat-allow, so it must be treated as unrestricted: out of doc-drift scope
  # (the "bash: allow" doc claim below is NOT reported) and a violation of the
  # edit/bash invariant.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "order-agent": { "permission": { "edit": { "*": "deny" }, "bash": { "jq *": "allow", "*": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/order-agent.md" <<'MD'
# order-agent
This doc claims bash: allow, which check B must NOT report - the map is unrestricted, not deny-first.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "order-agent: edit is deny-scoped but bash is not"
  assert_output_not_contains "order-agent.md:"
  assert_output_not_contains "deny-first doc contract drift"
}

@test "validator: a legitimately restricted agent passes the edit/bash invariant (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/restricted-ok"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "good-agent": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "1 in-scope agents: good-agent"
  assert_output_not_contains "deny-scoped edit with unrestricted bash"
}

@test "validator: flat-deny agent doc claiming an allow is caught (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/flat-deny-doc"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  # A flat "bash": "deny" is MORE restrictive than a deny-first object, so its
  # docs must not claim an allow either. These eight agents were skipped by the
  # old object-only predicate.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "flat-deny-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  cat > "$tree/.opencode/agents/flat-deny-agent.md" <<'MD'
# flat-deny-agent
This prose claims bash: allow for the jq, rg, wc enum.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-first doc contract drift"
  assert_output_contains "flat-deny-agent.md:2"
  assert_output_contains "bash: allow"
}

@test "validator: a preset/agent .prompt field claiming an allow is caught (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/prompt-field"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "prompt-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  # `.prompt` is the second injected prompt field - only orchestratorPrompt was
  # scanned before.
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "prompt-agent": { "prompt": "prompt-agent\n- Permissions: bash: allow for the jq enum" } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-first doc contract drift"
  assert_output_contains "agents.prompt-agent.prompt"
  assert_output_contains "bash: allow"
}

@test "validator: a live prompt-override _append.md file claiming an allow is caught (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/prompt-override"
  mkdir -p "$tree/.opencode/agents" "$tree/.opencode/oh-my-opencode-slim"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "probe-lane": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  # Injected at runtime from this directory, and never scanned before.
  cat > "$tree/.opencode/oh-my-opencode-slim/probe-lane_append.md" <<'MD'
# probe-lane
Runtime prompt override that claims bash: allow.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-first doc contract drift"
  assert_output_contains "probe-lane_append.md:2"
  assert_output_contains "bash: allow"
}

@test "validator: every forbidden occurrence on one line is reported, not only the first (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/multi-hit"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "multi-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  cat > "$tree/.opencode/agents/multi-agent.md" <<'MD'
# multi-agent
Claims bash: allow on the first mention and bash: allow again on the same line.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 2 ]
}

@test "validator: analyzer pair documents must state the deny-first contract (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/positive-invariant"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" } } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" } } }
  }
}
JSONC
  # Document exists but never states the deny-first contract - the positive
  # invariant must fail it even though no forbidden phrase appears.
  cat > "$tree/.opencode/agents/analyzer.md" <<'MD'
# analyzer
bash limited to jq, rg and wc; everything else denied.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'missing required "deny-first" marker'
  assert_output_contains "analyzer.md"
}

# ---------------------------------------------------------------------------
# DIA-260827-ft3z review close-out: coverage holes in the gates above, plus the
# cycle-2 findings R1-R8. Discriminating vs regression guard (R6: the previous
# blanket claim "every case here is DISCRIMINATING" was overstated and is
# corrected here): a [D] case fails against the pre-fix predicate, the pre-fix
# matcher or the pre-fix phrase scanner - or, for the probe-A/probe-B fixture,
# against a probe-B-only predicate - and passes after the fix; a [G] case pins
# behaviour that was ALREADY correct when written and only guards against a
# regression. [G] in this section: "every remaining forbidden phrase fires at
# least once" and "the deny-first marker is scoped to the analyzer pair" were
# guards from the start, as are the R7 additions that pin untested acceptance
# details (success-line pluralization, the no-permission-object branch) rather
# than close a hole. The former "memory-manager exemption" R7 case is no
# longer a [G] guard: design D6 emptied EXEMPT_EDIT_BASH, so that case now
# pins the emptied set (the same fixture must FAIL loudly) - see the
# "emptied exemption set" case below.
# ---------------------------------------------------------------------------

@test "validator: deny-by-default maps allowing a dangerous execution shape fail the invariant (DIA-260827-ft3z C1)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/c1-dangerous-allow"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # Both maps resolve the two restriction probes to DENY (no probe starts with
  # python3 / bash -c), so the old "both probes deny" predicate called them
  # restricted and the invariant stayed silent - on a lane that can still run
  # arbitrary code. The dangerous-allow probe must disqualify them and name
  # WHICH shape was allowed.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "c1-python": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "python3 *": "allow" } } },
    "c1-bashc": { "permission": { "edit": { "*": "deny" }, "bash": { "*": "deny", "bash -c *": "allow" } } }
  }
}
JSONC
  # c1-python is UNRESTRICTED under the fixed predicate, so its doc claim must
  # NOT be scanned either - a second face of the same classification.
  cat > "$tree/.opencode/agents/c1-python.md" <<'MD'
# c1-python
This doc claims bash: allow and must stay unreported (map is unrestricted).
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'c1-python: edit is deny-scoped but bash is not (bash is deny-by-default but allows the dangerous execution shape "python3 -c '"'"'x'"'"'")'
  assert_output_contains 'c1-bashc: edit is deny-scoped but bash is not (bash is deny-by-default but allows the dangerous execution shape "bash -c '"'"'x'"'"'")'
  # unrestricted maps leave doc-drift scope: no phrase scan, no drift header
  assert_output_not_contains "deny-first doc contract drift"
  assert_output_not_contains "c1-python.md:"
}

@test "validator: edit deny-scoping resolves with path-shaped probes, catch-all key position irrelevant (DIA-260827-ft3z M1/C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/edit-path-probes"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # path-only: the old command-shaped probe (no slash) matched nothing, so the
  # invariant was skipped on a map that denies every path. order-last: the
  # deny catch-all sits LAST, so the result must come from resolution, not key
  # position. Both maps grant no arbitrary path -> deny-scoped -> with a flat
  # "allow" bash the invariant must fire for BOTH.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "path-only": { "permission": { "edit": { "**/*": "deny", "knowledge/**": "allow" }, "bash": "allow" } },
    "order-last": { "permission": { "edit": { "knowledge/*": "allow", "*": "deny" }, "bash": "allow" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "path-only: edit is deny-scoped but bash is not"
  assert_output_contains "order-last: edit is deny-scoped but bash is not"
  assert_output_not_contains "deny-first doc contract drift"
}

@test "validator: bash: allow matches allowed but not allow-list or allowlisted (DIA-260827-ft3z M2a/R3)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/allow-boundary"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "m2a": { "permission": { "edit": "deny", "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  # R3: the word after `allow` is examined, not just its first character. The
  # four allow-list spellings are skipped; `allowed` is a genuine flat-allow
  # claim and must fire (the old next-char rule swallowed it, so the hit count
  # below discriminates: 1 against the old rule, 2 against the fixed one).
  cat > "$tree/.opencode/agents/m2a.md" <<'MD'
# m2a
Claims bash: allow-list for the enum - must NOT be reported.
Claims bash: allowlisted for the enum - must NOT be reported.
Claims bash: allowed for the enum - must be reported.
Claims bash: allow for the enum - must be reported.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  # discriminating replacement for the old vacuous `assert_output_not_contains
  # "allow-list"` (the reported phrase is always "bash: allow", so that string
  # could never appear): the allow-list LINES must stay unreported.
  assert_output_not_contains "m2a.md:2"
  assert_output_not_contains "m2a.md:3"
  assert_output_contains 'm2a.md:4: forbidden phrase "bash: allow"'
  assert_output_contains 'm2a.md:5: forbidden phrase "bash: allow"'
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 2 ]
}

@test "validator: a same-line negation suppresses the phrase hit (DIA-260827-ft3z M2b)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/negation"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "m2b": { "permission": { "edit": "deny", "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/m2b.md" <<'MD'
# m2b
This lane does not run mmdc in any flow.
This lane renders with mmdc when asked.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'm2b.md:3: forbidden phrase "mmdc"'
  assert_output_not_contains "m2b.md:2"
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 1 ]
}

@test "validator: a prompt line naming another agent is not attributed to the subject (DIA-260827-ft3z M2c)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/attribution"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "coder": { "permission": { "bash": "allow" } }
  }
}
JSONC
  # Line 2 is an accurate description of CODER's grant in a routing table; it
  # must not be attributed to analyzer. Line 3 names the subject and fires.
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "analyzer": { "prompt": "analyzer routing table:\ncoder: bash: allow for its git enum\nanalyzer: bash: allow for its jq enum" } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "agents.analyzer.prompt:3: forbidden phrase \"bash: allow\""
  assert_output_not_contains "agents.analyzer.prompt:2"
}

@test "validator: matcher anchoring - a substring pattern does not match a longer probe (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/match-anchor"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # "probe_denied" is a SUBSTRING of the restriction probe
  # __dia_probe_denied__. Anchored whole-value matching leaves both probes on
  # the "*" deny -> restricted -> the doc claim is in scope and reported.
  # Unanchored matching would resolve the probe to allow, drop the agent out
  # of scope and green the gate.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "anchor-agent": { "permission": { "bash": { "*": "deny", "probe_denied": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/anchor-agent.md" <<'MD'
# anchor-agent
This doc claims bash: allow - reported only while matching stays anchored.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'anchor-agent.md:2: forbidden phrase "bash: allow"'
}

@test "validator: matcher escaping - a dot pattern does not match a bare word (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/match-escape"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # The edit probe is dia_edit_probe (no dot). If the "." in the key
  # dia_edit.probe were compiled as a regex any-char, the probe would resolve
  # to allow, isDenyScoped would bail out and the invariant would stay silent.
  # With escaping the key matches nothing, both probes hit "*", and the
  # invariant fires against the flat "allow" bash.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "escape-agent": { "permission": { "edit": { "*": "deny", "dia_edit.probe": "allow" }, "bash": "allow" } } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "escape-agent: edit is deny-scoped but bash is not"
}

@test "validator: matcher star crosses spaces and probe-B allow means not restricted (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/match-space"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # Probe B is "zzz_nonexistent_cmd --flag" - it only resolves to allow when
  # "*" crosses the space. So this map denies probe A, allows probe B and must
  # be classified NOT restricted: the invariant fires and the doc claim below
  # stays out of scope.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "space-agent": { "permission": { "edit": { "*": "deny" }, "bash": { "*": "deny", "zzz*": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/space-agent.md" <<'MD'
# space-agent
This doc claims bash: allow - unreported because the map is NOT restricted.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "space-agent: edit is deny-scoped but bash is not"
  assert_output_not_contains "space-agent.md:"
}

@test "validator: a missing analyzer agent markdown fails the positive marker (DIA-260827-ft3z M3)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/missing-analyzer-md"
  mkdir -p "$tree/.opencode/agents"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "m3-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  # No agents/analyzer.md at all: deleting the document must not delete the
  # requirement - absence is a failure naming the missing file.
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "analyzer: required agent document missing:"
  assert_output_contains "agents/analyzer.md"
  assert_output_contains "analyzer-escalated: required agent document missing:"
  assert_output_contains "agents/analyzer-escalated.md"
}

@test "validator: lockstep rejects an empty permission object (DIA-260827-ft3z G1)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/empty-permission"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": {} },
    "analyzer-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'pair analyzer/analyzer-escalated: member "analyzer" has an empty permission object'
  assert_output_not_contains "ok: analyzer/analyzer-escalated"
}

@test "validator: lockstep rejects a map that is all task-related exemptions (DIA-260827-ft3z G1)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/all-exempt"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "task": "deny" } },
    "coder-escalated": { "permission": { "task": "deny" } },
    "analyzer": { "permission": { "bash": { "*": "deny" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'pair coder/coder-escalated: member "coder" has no comparable permission keys left after exemptions'
  assert_output_contains 'pair coder/coder-escalated: member "coder-escalated" has no comparable permission keys left after exemptions'
  assert_output_not_contains "ok: coder/coder-escalated"
}

@test "validator: lockstep rejects permission keys carrying zero leaf rules (DIA-260827-ft3z M4)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/zero-rules"
  mkdir -p "$tree/.opencode"
  # {"bash":{}} has a key but no rule: the old gate printed "1 keys, 0 rules"
  # and went green on zero rule coverage.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "bash": {} } },
    "analyzer-escalated": { "permission": { "bash": {} } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'member "analyzer" has 0 leaf rules'
  assert_output_contains 'member "analyzer-escalated" has 0 leaf rules'
  assert_output_not_contains "ok: analyzer/analyzer-escalated"
}

@test "validator: an undeclared agent resolves edit and bash through the global block (DIA-260827-ft3z G2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/global-fallback"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # global-agent declares NO permission keys: edit and bash both come from the
  # top-level permission block, so the invariant must see a deny-scoped edit
  # on an unrestricted bash through the fallback.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "permission": { "edit": { "*": "deny" }, "bash": "allow" },
  "agent": { "global-agent": {} }
}
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "global-agent: edit is deny-scoped but bash is not"
}

@test "validator: preset prompt field and live override name.md claims are caught (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/prompt-surfaces"
  mkdir -p "$tree/.opencode/agents" "$tree/.opencode/oh-my-opencode-slim"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "surf-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "presets": { "p1": { "surf-agent": { "prompt": "surf-agent\n- claims bash: allow in a preset" } } } }
JSONC
  # <name>.md as distinct from <name>_append.md (the append form has its own
  # test above).
  cat > "$tree/.opencode/oh-my-opencode-slim/surf-agent.md" <<'MD'
# surf-agent
Runtime override claims bash: allow.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "presets.p1.surf-agent.prompt:2: forbidden phrase \"bash: allow\""
  assert_output_contains "surf-agent.md:2: forbidden phrase \"bash: allow\""
}

@test "validator: every remaining forbidden phrase fires at least once (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/phrase-list"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "phrase-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  cat > "$tree/.opencode/agents/phrase-agent.md" <<'MD'
# phrase-agent
line1: bash: fully allowed here
line2: bash (allow) per docs
line3: bash is allowed for jq
line4: rendered via Mermaid CLI
line5: invoked through mmdc
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'phrase-agent.md:2: forbidden phrase "bash: fully allowed"'
  assert_output_contains 'phrase-agent.md:3: forbidden phrase "bash (allow)"'
  assert_output_contains 'phrase-agent.md:4: forbidden phrase "bash is allowed"'
  assert_output_contains 'phrase-agent.md:5: forbidden phrase "Mermaid CLI"'
  assert_output_contains 'phrase-agent.md:6: forbidden phrase "mmdc"'
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 5 ]
}

@test "validator: the deny-first marker is scoped to the analyzer pair (DIA-260827-ft3z C2)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/marker-confine"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # other-lane is in scope (deny-first bash map) but is NOT part of the
  # analyzer pair, so its document may omit the deny-first marker.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "other-lane": { "permission": { "edit": "deny", "bash": { "*": "deny", "jq *": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/other-lane.md" <<'MD'
# other-lane
No deny-first marker here, and that must be fine for a non-analyzer lane.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "1 in-scope agents: other-lane"
  assert_output_not_contains 'missing required "deny-first" marker'
}

# ---------------------------------------------------------------------------
# DIA-260827-ft3z cycle-2 findings R1-R8 (re-review of the gate above). Every
# case is tagged [D] discriminating or [G] regression guard in its comment;
# see the section header for what those tags mean.
# ---------------------------------------------------------------------------

@test "validator: write and shell-out shapes disqualify a deny-by-default map (DIA-260827-ft3z R1) [D]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r1-write-shapes"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # The researcher map this ticket was opened for: both restriction probes
  # resolve to deny, yet `curl -o /workspace/anything URL` writes anywhere
  # behind the `curl *` allow. Under the interpreter-only shape list this
  # classified as restricted and the invariant stayed silent on the real hole.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "r1-curl": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "curl *": "allow" } } } } }
JSONC
  # Once the write shapes are in, the map is UNRESTRICTED, so its own doc
  # claim leaves doc-drift scope too - the other face of the reclassification.
  cat > "$tree/.opencode/agents/r1-curl.md" <<'MD'
# r1-curl
This doc claims bash: allow and stays unreported (map is unrestricted).
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'r1-curl: edit is deny-scoped but bash is not (bash is deny-by-default but allows the dangerous execution shape "curl -o x http://x")'
  assert_output_not_contains "r1-curl.md:"
  assert_output_not_contains "deny-first doc contract drift"
}

@test "validator: an empty key inside a populated permission map fails lockstep (DIA-260827-ft3z R2) [D]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r2-empty-key"
  mkdir -p "$tree/.opencode"
  # {"bash": {}, "task": "deny"}: the AGGREGATE leaf count is 1 (from task),
  # so the old check went green while bash carried zero rules. The check is per
  # key now and names every empty one.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "coder-escalated": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "analyzer": { "permission": { "bash": {}, "task": "deny" } },
    "analyzer-escalated": { "permission": { "bash": {}, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'pair analyzer/analyzer-escalated: member "analyzer" has 0 leaf rules in key(s): bash'
  assert_output_contains 'pair analyzer/analyzer-escalated: member "analyzer-escalated" has 0 leaf rules in key(s): bash'
  # the clean coder pair in the same fixture stays green
  assert_output_not_contains "coder / coder-escalated permission lockstep broken"
  assert_output_not_contains "ok: analyzer/analyzer-escalated"
}

@test "validator: negation markers are word-bounded and clause-scoped (DIA-260827-ft3z R4) [D]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r4-negation-bounds"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "r4": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  # Line 2 must STILL be suppressed (the bounded marker still works). Lines
  # 3-5 must fire: `never` no longer matches inside "nevertheless", `not` no
  # longer matches inside "cannot", and a marker in an EARLIER clause can no
  # longer retract a later claim. Against the unbounded marker all four lines
  # were suppressed and the gate exited 0.
  cat > "$tree/.opencode/agents/r4.md" <<'MD'
# r4
This lane does not run mmdc in any flow.
We nevertheless render mmdc when asked.
This lane cannot be stopped from running mmdc here.
Never mind. This lane runs mmdc when asked.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'r4.md:3: forbidden phrase "mmdc"'
  assert_output_contains 'r4.md:4: forbidden phrase "mmdc"'
  assert_output_contains 'r4.md:5: forbidden phrase "mmdc"'
  assert_output_not_contains "r4.md:2"
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 3 ]
}

@test "validator: attribution suppresses only the labelled hit, never the line (DIA-260827-ft3z R5) [D]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r5-per-hit"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "coder": { "permission": { "bash": "allow" } }
  }
}
JSONC
  # Line 2 is coder's grant behind its own label - suppressed. Line 3 names
  # coder but makes ITS OWN claim ("Unlike coder, this lane grants ...") and
  # was dropped wholesale by the old whole-line rule. Line 4 labels the
  # subject itself and always fires.
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "agents": { "analyzer": { "prompt": "analyzer routing table:\ncoder: bash: allow for its git enum\nUnlike coder, this lane grants bash: allow for its jq enum\nanalyzer: grants bash: allow for its jq enum" } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'agents.analyzer.prompt:3: forbidden phrase "bash: allow"'
  assert_output_contains 'agents.analyzer.prompt:4: forbidden phrase "bash: allow"'
  assert_output_not_contains "agents.analyzer.prompt:2"
  local hit_lines
  hit_lines="$(printf '%s\n' "$output" | grep -c 'forbidden phrase' || true)"
  [ "$hit_lines" -eq 2 ]
}

@test "validator: probe A allow with probe B deny is not restricted (DIA-260827-ft3z R6) [D]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r6-probe-a"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # Mirror of the probe-B fixture above: probe A (__dia_probe_denied__) resolves
  # ALLOW, probe B (zzz_nonexistent_cmd --flag) resolves DENY. A predicate that
  # only inspected probe B would call this map restricted, drop it out of the
  # invariant and report the doc claim below; the correct predicate needs BOTH
  # probes to deny, so this map is unrestricted: invariant fires, doc out of
  # scope.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "r6-agent": { "permission": { "edit": { "*": "deny" }, "bash": { "*": "deny", "__dia_probe*": "allow" } } } } }
JSONC
  cat > "$tree/.opencode/agents/r6-agent.md" <<'MD'
# r6-agent
This doc claims bash: allow - unreported because probe A resolves allow.
MD
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "r6-agent: edit is deny-scoped but bash is not"
  assert_output_not_contains "r6-agent.md:"
  assert_output_not_contains "deny-first doc contract drift"
}

@test "validator: the lockstep success line pluralizes a single key and rule (DIA-260827-ft3z R7) [G]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r7-singular"
  mkdir -p "$tree/.opencode"
  # One top-level key carrying exactly one leaf rule: the acceptance detail is
  # "1 key, 1 rule" (never "1 keys, 1 rules").
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "bash": { "*": "deny" }, "task": "deny" } },
    "coder-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } },
    "analyzer": { "permission": { "bash": { "*": "deny" } } },
    "analyzer-escalated": { "permission": { "bash": { "*": "deny" } } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "(1 key, 1 rule: analyzer, analyzer-escalated)"
  assert_output_not_contains "1 keys"
  assert_output_not_contains "2 rules"
}

@test "validator: the emptied exemption set makes memory-manager fail loudly (DIA-260827-ft3z D6)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r7-exempt"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # DIA-260827-ft3z design D6 emptied EXEMPT_EDIT_BASH: memory-manager's bash
  # map is now closed (deny-first, read-only git + the shelf validator), so the
  # tracked-debt exemption is gone. The fixture that USED to be exempt -
  # deny-scoped edit on an unrestricted bash - must now FAIL loudly; that is
  # the intended behaviour of an empty set (a new agent in this state fails
  # instead of sliding through). The former expectation (exit 0, no report)
  # reddened the moment task 3.1 removed the member.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "memory-manager": { "permission": { "edit": { "*": "deny", ".opencode/memory/*": "allow" }, "bash": "allow" } } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-scoped edit with unrestricted bash"
  assert_output_contains "memory-manager: edit is deny-scoped"
}

@test "validator: lockstep rejects a pair member with no permission object at all (DIA-260827-ft3z R7) [G]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r7-no-permission"
  mkdir -p "$tree/.opencode"
  # The agent is configured but declares NO permission key (distinct from the
  # `permission: {}` empty-object case covered above).
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "coder": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "coder-escalated": { "permission": { "task": "deny", "bash": { "*": "deny" } } },
    "analyzer": {},
    "analyzer-escalated": { "permission": { "bash": { "*": "deny" }, "task": "deny" } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --lockstep "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'pair analyzer/analyzer-escalated: member "analyzer" has no permission object'
  assert_output_not_contains "ok: analyzer/analyzer-escalated"
}

@test "validator: a preset orchestratorPrompt claiming an allow is caught (DIA-260827-ft3z R7) [G]" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/r7-preset-orch"
  mkdir -p "$tree/.opencode/agents"
  require_analyzer_docs "$tree"
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{ "agent": { "preset-orch-agent": { "permission": { "edit": "deny", "bash": "deny" } } } }
JSONC
  # presets.<p>.<name>.orchestratorPrompt is the surface DISTINCT from
  # presets.<p>.<name>.prompt (covered by the preset/.prompt case above) and
  # from agents.<name>.orchestratorPrompt (covered at the top of this suite).
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{ "presets": { "p1": { "preset-orch-agent": { "orchestratorPrompt": "preset-orch-agent\n- claims bash: allow in a preset orchestratorPrompt" } } } }
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains 'presets.p1.preset-orch-agent.orchestratorPrompt:2: forbidden phrase "bash: allow"'
}

# ---------------------------------------------------------------------------
# DIA-260827-ft3z task 1.3: the former fetch-write hole as a config-gate
# negative test. Case 1 resolves the four LITERAL former commands through the
# same resolver the gate uses, against the REAL config, and asserts deny - RED
# while researcher still carries the curl/wget/trafilatura/crwl allows, green
# once task 3.1 flattens its bash to deny. Case 2 re-opens the hole in a
# fixture (deny-scoped edit + `curl *` re-added) and asserts the gate FAILS on
# it - RED while researcher still sits in EXEMPT_EDIT_BASH, green once the
# exemption closes. Together they pin both halves: the real config denies the
# shapes, and a restored grant is caught instead of exempted.
# ---------------------------------------------------------------------------

@test "config: the four former fetch write shapes resolve to deny for researcher (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  run "$NODE_BIN" -e '
    const fs = require("fs");
    const lib = process.argv[1];
    const file = process.argv[2];
    const src = fs.readFileSync(lib, "utf8");
    // jsonc-parse.js exports no module API: evaluate everything up to its
    // FIRST CLI dispatch branch and export the resolver helpers the config
    // gate itself uses - one resolver, not a second implementation. The
    // marker is the leading text of that branch, so every helper defined
    // below the argv slice stays inside the evaluated source.
    const marker = "if (args[0] === ";
    const cut = src.indexOf(marker);
    if (cut < 0) { console.error("jsonc-parse.js layout changed: marker not found"); process.exit(2); }
    const mod = { exports: {} };
    new Function("require", "module", "exports", src.slice(0, cut) + "\nmodule.exports = { parseJsonc, resolveRule, effectivePermission };")(require, mod, mod.exports);
    const cfg = mod.exports.parseJsonc(file);
    const researcherPerm = ((cfg.agent || {}).researcher || {}).permission || {};
    const bash = mod.exports.effectivePermission(researcherPerm, cfg.permission, "bash");
    // The four literal commands the researcher allow-list used to grant,
    // exactly as filed in tasks.md 1.3.
    const FORMER = [
      "curl -o /workspace/anything http://x",
      "wget -O /workspace/anything http://x",
      "trafilatura -o /workspace/anything http://x",
      "crwl -o /workspace/anything http://x",
    ];
    const problems = [];
    for (const cmd of FORMER) {
      // A flat string permission is the verdict for every command; an object
      // map resolves by findLast over its rules, same as the gate does.
      const verdict = typeof bash === "string" ? bash : mod.exports.resolveRule(bash, cmd);
      if (verdict !== "deny") problems.push(cmd + " resolves to " + JSON.stringify(verdict) + "; expected deny");
    }
    if (problems.length > 0) { console.error(problems.join("\n")); process.exit(1); }
    console.log("ok: researcher denies all four former fetch write shapes");
  ' "$LIB" "$REPO_ROOT/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: researcher denies all four former fetch write shapes"
}

@test "config: fixture researcher with curl * re-added fails the gate (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  local tree="$BATS_TEST_TMPDIR/readd-curl-star"
  mkdir -p "$tree/.opencode"
  require_analyzer_docs "$tree"
  # The POST-closure researcher shape (deny-scoped edit, deny-first bash) with
  # the former hole re-added: a single "curl *" grant behind the catch-all
  # deny. While researcher still sits in EXEMPT_EDIT_BASH the invariant skips
  # it and the gate stays green - this case is RED until task 3.1 removes the
  # exemption, then it pins that a restored curl * fails the gate.
  cat > "$tree/.opencode/opencode.jsonc" <<'JSONC'
{
  "agent": {
    "analyzer": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "analyzer-escalated": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "jq *": "allow" }, "task": "deny" } },
    "researcher": { "permission": { "edit": { "*": "deny", "knowledge/*": "allow" }, "bash": { "*": "deny", "curl *": "allow" } } }
  }
}
JSONC
  run "$NODE_BIN" "$LIB" --doc-drift "$tree/.opencode/opencode.jsonc"
  assert_status 1
  assert_output_contains "deny-scoped edit with unrestricted bash"
  assert_output_contains "researcher: edit is deny-scoped but bash is not"
  assert_output_contains "curl"
}

# ---------------------------------------------------------------------------
# tasks.md 1.6 / AUD-N2 (S1.1, campaign DIA-261119-vioa): no phantom gate.
# The slice's acceptance text must name only real gates: every `make <target>`
# referenced by tasks 1.1-1.8 resolves to a Makefile target, no test or script
# invokes the phantom check-omo-version-sync make target (Makefile:260 is only
# a recipe step inside test-config; the real entry point is the script), and
# the non-make gate scripts the slice names actually exist.
# The comment above deliberately never spells the phantom as `make <name>` --
# the guard below greps scripts/ for exactly that shape and would self-match.
# ---------------------------------------------------------------------------
@test "gate wiring: tasks.md group-1 make targets all exist and no script invokes the phantom check-omo-version-sync target (tasks.md 1.6)" {
  # Guards first (pass today): the slice's non-make gate entry points exist.
  assert_file_exists "$REPO_ROOT/scripts/check-pin-sync.sh"
  assert_file_exists "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  # No test or script may reference the non-existent make target.
  local phantom=""
  phantom="$(grep -rn --exclude-dir=vendor --include='*.sh' --include='*.bats' \
      -E 'make[[:space:]]+check-omo-version-sync' "$REPO_ROOT/scripts" 2>/dev/null || true)"
  phantom="${phantom}$(grep -hE 'make[[:space:]]+check-omo-version-sync' "$REPO_ROOT"/*.sh 2>/dev/null || true)"
  if [ -n "$phantom" ]; then
    echo "scripts/tests reference the non-existent make target check-omo-version-sync:" >&2
    echo "$phantom" >&2
    return 1
  fi
  # RED today: the group-1 task text itself still names `make
  # check-omo-version-sync` (tasks.md 1.6) while the Makefile declares no such
  # target -- so at least one backticked make command in tasks 1.1-1.8 does
  # not resolve. GREEN per task 1.6: declare the target OR reword the mention;
  # either way every named make gate must exist.
  local group1 targets t missing=""
  group1="$(awk '/^## 1\./{f=1} /^## 2\./{f=0} f' \
    "$REPO_ROOT/openspec/changes/opencode-v2-migration/tasks.md")"
  targets="$(grep -oE '`make [a-z0-9-]+`' <<<"$group1" | tr -d '\`' | sed 's/^make //' | sort -u)"
  [ -n "$targets" ] || {
    echo "extraction found no make targets in tasks.md group 1 (tasks.md layout changed?)" >&2
    return 1
  }
  for t in $targets; do
    grep -qE "^${t}:" "$REPO_ROOT/Makefile" || missing="$missing $t"
  done
  [ -z "$missing" ] || {
    echo "tasks.md group 1 names make target(s) the Makefile does not declare:$missing" >&2
    return 1
  }
}
