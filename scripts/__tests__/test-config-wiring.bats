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
  # bash(23) + task(1) = 26 leaf rules behind 3 top-level keys.
  assert_output_contains "(3 keys, 26 rules: analyzer, analyzer-escalated)"
  # G3 widened scope on the REAL tree: the eight flat-"deny" agents plus the
  # five deny-first object maps = 13 in-scope agents, named in the ok line.
  assert_output_contains "13 in-scope agents"
  assert_output_contains "orchestrator, architector, analyzer, analyzer-escalated, reviewer, code-navigator"
}

@test "config: analyzer maps pin rg --pre denies AFTER the rg allow and carry bare openspec forms (DIA-260827-ft3z)" {
  [ -n "$NODE_BIN" ] || skip "node is required to run jsonc-parse.js"
  # Structural case (S1 + F7b): parses the REAL .opencode/opencode.jsonc with
  # the SAME JSONC parser the config gate uses - jsonc-parse.js exports no
  # module API, so its function definitions (everything before the CLI argv
  # dispatch) are evaluated here instead of writing a second parser. What it
  # pins is ORDERING, which is what last-match-wins needs: every rg --pre /
  # --pre-glob deny must sit at a key index AFTER the direct "rg *" allow in
  # BOTH analyzer maps (a deny before the allow is shadowed and worthless),
  # and the four bare openspec subcommands must exist beside their starred
  # twins (the star requires a trailing argument, so the bare form would
  # otherwise fall through to the catch-all deny). Fails on the pre-S1 config
  # (8 missing denies per map) and on any reordering that moves a deny above
  # the allow.
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
    const DENY = [
      "rg --pre *", "rg --pre=*", "rg * --pre *", "rg * --pre=*",
      "rg --pre-glob *", "rg --pre-glob=*", "rg * --pre-glob *", "rg * --pre-glob=*"
    ];
    const BARE = ["openspec list", "openspec status", "openspec show", "openspec context"];
    const problems = [];
    for (const name of ["analyzer", "analyzer-escalated"]) {
      const perm = (cfg.agent[name] || {}).permission || {};
      const bash = perm.bash;
      if (!bash) { problems.push(name + ": no bash permission map"); continue; }
      const keys = Object.keys(bash);
      const allowAt = keys.indexOf("rg *");
      if (allowAt < 0) problems.push(name + ": direct rg * allow missing");
      for (const p of DENY) {
        const at = keys.indexOf(p);
        if (at < 0) { problems.push(name + ": deny pattern missing: " + p); continue; }
        if (bash[p] !== "deny") problems.push(name + ": " + p + " is " + bash[p] + ", expected deny");
        if (allowAt >= 0 && at < allowAt) {
          problems.push(name + ": " + p + " at key index " + at + " is BEFORE the rg * allow at index " + allowAt + " (last-match-wins would shadow it)");
        }
      }
      for (const b of BARE) {
        const star = b + " *";
        if (!(b in bash)) problems.push(name + ": bare openspec form missing: " + b);
        else if (bash[b] !== "allow") problems.push(name + ": " + b + " is " + bash[b] + ", expected allow");
        if (!(star in bash)) problems.push(name + ": starred openspec form missing: " + star);
      }
    }
    if (problems.length > 0) { console.error(problems.join("\n")); process.exit(1); }
    // O5 (DIA-260827-ft3z re-review): the count is derived from DENY.length so
    // a future change to that array cannot leave the message claiming a stale
    // number (the bats assertion below still pins the current count of 8).
    console.log("ok: analyzer maps pin " + DENY.length + " rg --pre denies after the rg * allow and 4 bare openspec forms beside their starred twins");
  ' "$LIB" "$REPO_ROOT/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "ok: analyzer maps pin 8 rg --pre denies after the rg * allow"
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
