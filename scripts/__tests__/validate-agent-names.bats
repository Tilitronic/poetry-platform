#!/usr/bin/env bats
# Meta-tests for scripts/validate-agent-names.sh (change
# dev-infra-config-validators, task T2). The script enforces the
# DECLARED-⊆-RESOLVED containment contract over the kebab-case internal
# agent-name sets in the 4 project-scoped sources (owner ruling row 420):
#   S1 AGENTS.md §9 "Agent Naming Convention" table (Internal name column)
#   S2 .opencode/opencode.jsonc `agent`/`agents` block keys
#   S3 .opencode/oh-my-opencode-slim.jsonc `agents` keys + preset routing
#      values + disabled_agents list (disabled agents STILL validated, Q2) +
#      the PRESENCE of the top-level `council` KEY itself (council KEY →
#      S3-valid; its block MEMBERS are model seats — deepseek,
#      gemini-3.1-pro, gpt-5.3-codex, claude-sonnet-4.5, qwen3.7-plus — NOT
#      agent names, so NOT extracted — row 420)
#   S4 .opencode/agents/*.md filename stems. EXCEPT the S4-exempt set (row
#      415, retained as a clause of row-420 invariant 1): explore, general,
#      oracle, fixer, explorer, librarian are exempt from the S4 file
#      requirement — OpenCode built-ins / OMO native aliases that legitimately
#      live in S1/S2/S3 only (creating an S4 file would register a real agent
#      at next OpenCode startup).
# Two containment invariants (design.md §1):
#   I1  every §9 (S1) name resolves in S2∪S3∪S4∪exempt
#   I2  every S2∪S3-declared name appears in §9 (S1)
# Containment, NOT set-equality: S1+S2 without S4 (config-defined agent with
# no definition file) is PASS, not drift.
#
# Exit-code contract under test (design.md §3):
#   0  no HARD failures (all §9 names resolve + all S2∪S3 names canonical);
#      OR empty agents dir -> 0/0/0 (Q5)
#   1  HARD: invariant-1 / invariant-2 containment violation; JSONC parse
#      error (Q2)
#   2  INFRA: missing source file (AGENTS.md / opencode.jsonc /
#      oh-my-opencode-slim.jsonc) or python3 unavailable
#
# Isolation: each test builds a hermetic fixture tree under
# $BATS_TEST_TMPDIR mirroring the repo layout and points the validator at it
# via the AGENTS_ROOT env override — the real project config is never touched.

load test-helper

AGENTS_SCRIPT="$REPO_ROOT/scripts/validate-agent-names.sh"

# setup_tree <name>: creates a hermetic fixture root for one test.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$tree/.opencode/agents"
  echo "$tree"
}

# write_agents_md <root> <agent...>: writes AGENTS.md with a §9 Agent Naming
# Convention table listing the given internal names.
write_agents_md() {
  local root="$1"
  shift
  {
    echo "# Fixture"
    echo ""
    echo "## Agent Naming Convention"
    echo ""
    echo "| Display name | Internal name | Lane |"
    echo "| --- | --- | --- |"
    for name in "$@"; do
      echo "| @$name | \`$name\` | fixture lane |"
    done
  } > "$root/AGENTS.md"
}

# write_opencode_jsonc <root> <agent...>: writes .opencode/opencode.jsonc with
# an `agent` block keyed by the given names (matches the real file's key name;
# the validator also accepts `agents` for the design's wording).
write_opencode_jsonc() {
  local root="$1"
  shift
  {
    echo "{"
    echo "  // fixture JSONC (comment allowed)"
    echo "  \"agent\": {"
    local first=1
    for name in "$@"; do
      if [ "$first" -eq 1 ]; then first=0; else echo ","; fi
      printf '    "%s": { "mode": "subagent", "color": "#000000" }' "$name"
    done
    echo ""
    echo "  }"
    echo "}"
  } > "$root/.opencode/opencode.jsonc"
}

# write_slim_jsonc <root> <agents...> <disabled...>: writes
# .opencode/oh-my-opencode-slim.jsonc with an `agents` block keyed by the given
# names, a routing preset referencing them, and a disabled_agents list.
# Usage: write_slim_jsonc <root> <agents...> -- <disabled...>
write_slim_jsonc() {
  local root="$1"
  shift
  local agents=()
  local disabled=()
  local mode="agents"
  for arg in "$@"; do
    if [ "$arg" = "--" ]; then
      mode="disabled"
      continue
    fi
    if [ "$mode" = "agents" ]; then
      agents+=("$arg")
    else
      disabled+=("$arg")
    fi
  done
  {
    echo "{"
    echo "  // fixture JSONC (comment allowed)"
    echo "  \"preset\": \"fixture\","
    printf '  "disabled_agents": ['
    local d
    for d in "${disabled[@]}"; do printf '"%s",' "$d"; done
    echo "],"
    echo "  \"presets\": {"
    echo "    \"fixture-preset\": {"
    local first=1
    for name in "${agents[@]}"; do
      if [ "$first" -eq 1 ]; then first=0; else echo ","; fi
      printf '      "%s": { "model": "fixture/model" }' "$name"
    done
    echo ""
    echo "    }"
    echo "  },"
    echo "  \"agents\": {"
    local first=1
    for name in "${agents[@]}"; do
      if [ "$first" -eq 1 ]; then first=0; else echo ","; fi
      printf '    "%s": {}' "$name"
    done
    echo ""
    echo "  }"
    echo "}"
  } > "$root/.opencode/oh-my-opencode-slim.jsonc"
}

# write_agent_files <root> <agent...>: creates .opencode/agents/<name>.md files.
write_agent_files() {
  local root="$1"
  shift
  local name
  for name in "$@"; do
    printf '# %s agent definition\n' "$name" > "$root/.opencode/agents/$name.md"
  done
}

# valid_tree <name>: builds a fully coherent fixture tree under the
# declared-⊆-resolved contract. Every §9 name resolves (alpha/beta/gamma in
# S2/S3/S4) and every S2∪S3 name appears in §9. `gamma` is additionally listed
# in disabled_agents — being disabled never excuses a name from the contract
# (Q2: disabled agents STILL validated).
valid_tree() {
  local tree
  tree="$(setup_tree "$1")"
  write_agents_md "$tree" alpha beta gamma
  write_opencode_jsonc "$tree" alpha beta gamma
  write_slim_jsonc "$tree" alpha beta gamma -- gamma
  write_agent_files "$tree" alpha beta gamma
  echo "$tree"
}

@test "validate-agent-names: all §9 names resolve + all S2∪S3 names canonical exits 0" {
  local tree
  tree="$(valid_tree valid)"

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 0
  assert_output_contains "ok: alpha"
  assert_output_contains "ok: beta"
  assert_output_contains "ok: gamma"
  assert_output_contains "3 passed, 0 failed, 0 warnings"
  assert_output_not_contains "FAIL:"
}

@test "validate-agent-names: agents/ stem differs from opencode.jsonc key exits 1" {
  local tree
  tree="$(setup_tree mismatch)"
  # Containment re-target (row 420): §9 + agents/ agree on `zzz`; opencode.jsonc
  # + slim lag behind on `alpha`. The stem in agents/ (zzz) differs from the
  # opencode.jsonc key (alpha); alpha is declared in S2∪S3 but absent from §9 →
  # violates invariant 2 (declared-⊆-resolved).
  write_agents_md "$tree" zzz beta gamma
  write_opencode_jsonc "$tree" alpha beta gamma
  write_slim_jsonc "$tree" alpha beta gamma -- gamma
  # stem `zzz` in agents/ but the matching opencode.jsonc key is `alpha`
  write_agent_files "$tree" zzz beta gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: alpha"
  assert_output_contains "3 passed, 1 failed, 0 warnings"
}

@test "validate-agent-names: disabled-agent mismatch exits 1" {
  local tree
  tree="$(setup_tree disabled-mismatch)"
  write_agents_md "$tree" alpha beta gamma
  write_opencode_jsonc "$tree" alpha beta gamma
  # disabled list references `zeta` but the declared agents are alpha/beta/gamma
  # — zeta is declared in S3 (disabled_agents) yet absent from §9 (invariant 2)
  write_slim_jsonc "$tree" alpha beta gamma -- zeta
  write_agent_files "$tree" alpha beta gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: zeta"
  assert_output_contains "3 passed, 1 failed, 0 warnings"
}

@test "validate-agent-names: JSONC parse error in opencode.jsonc exits 1 (HARD, not 2)" {
  local tree
  tree="$(setup_tree jsonc-error)"
  write_agents_md "$tree" alpha beta gamma
  printf '{ "agent": { "alpha": } BROKEN\n' > "$tree/.opencode/opencode.jsonc"
  write_slim_jsonc "$tree" alpha beta gamma -- gamma
  write_agent_files "$tree" alpha beta gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "opencode.jsonc"
  assert_output_contains "0 passed, 1 failed, 0 warnings"
}

@test "validate-agent-names: empty agents/ directory exits 0 with 0/0/0 line" {
  local tree
  tree="$(setup_tree empty-agents)"
  write_agents_md "$tree" alpha beta
  write_opencode_jsonc "$tree" alpha beta
  write_slim_jsonc "$tree" alpha beta -- gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 0
  assert_output_contains "0 passed, 0 failed, 0 warnings"
}

@test "validate-agent-names: missing AGENTS.md exits 2 (INFRA)" {
  local tree
  tree="$(setup_tree missing-agents-md)"
  write_opencode_jsonc "$tree" alpha
  write_slim_jsonc "$tree" alpha -- beta
  write_agent_files "$tree" alpha

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 2
  assert_output_contains "FAIL:"
  assert_output_contains "AGENTS.md"
}

@test "validate-agent-names: missing required routing reference exits 1" {
  local tree
  tree="$(setup_tree missing-routing)"
  write_agents_md "$tree" alpha beta gamma
  write_opencode_jsonc "$tree" alpha beta gamma
  # preset routes an agent (`zeta`) that is NOT declared in the agents block —
  # hand-write the slim JSONC so the routing reference and agents keys differ;
  # zeta is declared in S3 (preset value) yet absent from §9 (invariant 2)
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{
  "preset": "fixture",
  "disabled_agents": ["gamma"],
  "presets": {
    "fixture-preset": {
      "alpha": { "model": "fixture/model" },
      "beta": { "model": "fixture/model" },
      "gamma": { "model": "fixture/model" },
      "zeta": { "model": "fixture/model" }
    }
  },
  "agents": {
    "alpha": {},
    "beta": {},
    "gamma": {}
  }
}
JSONC
  write_agent_files "$tree" alpha beta gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: zeta"
  assert_output_contains "3 passed, 1 failed, 0 warnings"
}

@test "validate-agent-names: council-KEY-only + exempt-name-without-S4-file exits 0" {
  local tree
  tree="$(setup_tree council-exempt)"
  # §9 declares alpha/beta/gamma/council/explore/librarian. `council` resolves
  # via the S3 council-KEY read ONLY (deliberately absent from S2 and S4).
  # `librarian` is an exempt OMO alias that appears in NO source but §9 — it
  # resolves via the exempt branch of invariant 1. `explore` is in S2/S3 but
  # has no S4 file — S4 absence is correct for the exempt set.
  write_agents_md "$tree" alpha beta gamma council explore librarian
  write_opencode_jsonc "$tree" alpha beta gamma explore
  # slim.jsonc: agents alpha/beta/gamma, disabled list has `explore`, and a
  # top-level council block whose MEMBERS are model seats (deepseek,
  # gemini-3.1-pro, gpt-5.3-codex, claude-sonnet-4.5, qwen3.7-plus) — only the
  # council KEY itself joins S3; the members are NOT extracted as agent names
  # (owner ruling row 420).
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<'JSONC'
{
  "preset": "fixture",
  "disabled_agents": ["explore"],
  "presets": {
    "fixture-preset": {
      "alpha": { "model": "fixture/model" },
      "beta": { "model": "fixture/model" },
      "gamma": { "model": "fixture/model" }
    }
  },
  "agents": {
    "alpha": {},
    "beta": {},
    "gamma": {}
  },
  "council": {
    "presets": {
      "default": {
        "deepseek": { "model": "opencode-go/deepseek-v4-flash" },
        "gemini-3.1-pro": { "model": "github-copilot/gemini-3.1-pro-preview" },
        "gpt-5.3-codex": { "model": "github-copilot/gpt-5.3-codex" },
        "claude-sonnet-4.5": { "model": "github-copilot/claude-sonnet-4.5" },
        "qwen3.7-plus": { "model": "opencode-go/qwen3.7-plus" }
      }
    },
    "default_preset": "default"
  }
}
JSONC
  # S4 files: alpha beta gamma — deliberately NO council.md / explore.md /
  # librarian.md (council resolves via S3 KEY presence; exempt names need no S4)
  write_agent_files "$tree" alpha beta gamma

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 0
  assert_output_contains "ok: alpha"
  assert_output_contains "ok: beta"
  assert_output_contains "ok: gamma"
  # `council` passes ONLY because the council-KEY presence makes it S3-valid
  assert_output_contains "ok: council"
  # `explore` passes via S2/S3 + S4-exemption; `librarian` via exempt branch
  assert_output_contains "ok: explore"
  assert_output_contains "ok: librarian"
  assert_output_contains "6 passed, 0 failed, 0 warnings"
  assert_output_not_contains "FAIL:"
  # Negative sub-assertions: council model-seat members are NOT extracted
  # as agent names and never appear in the validator's output or counts
  assert_output_not_contains "deepseek"
  assert_output_not_contains "gemini-3.1-pro"
  assert_output_not_contains "gpt-5.3-codex"
  assert_output_not_contains "claude-sonnet-4.5"
  assert_output_not_contains "qwen3.7-plus"
}

@test "validate-agent-names: declared name absent from §9 exits 1 (invariant 2)" {
  local tree
  tree="$(setup_tree declared-not-in-s1)"
  write_agents_md "$tree" alpha beta
  # opencode.jsonc declares `zeta` — absent from the §9 table. Invariant 2:
  # every S2∪S3-declared name must appear in §9; zeta violates it.
  write_opencode_jsonc "$tree" alpha beta zeta
  write_slim_jsonc "$tree" alpha beta
  write_agent_files "$tree" alpha beta

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: zeta"
  assert_output_contains "2 passed, 1 failed, 0 warnings"
}

@test "validate-agent-names: §9 name unresolved in all sources exits 1 (invariant 1)" {
  local tree
  tree="$(setup_tree s1-unresolved)"
  # §9 declares `omega` but no source resolves it and it is not exempt.
  # Invariant 1: every §9 name must resolve in S2∪S3∪S4∪exempt; omega
  # violates it.
  write_agents_md "$tree" alpha beta omega
  write_opencode_jsonc "$tree" alpha beta
  write_slim_jsonc "$tree" alpha beta
  write_agent_files "$tree" alpha beta

  AGENTS_ROOT="$tree" run bash "$AGENTS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: omega"
  assert_output_contains "2 passed, 1 failed, 0 warnings"
}
