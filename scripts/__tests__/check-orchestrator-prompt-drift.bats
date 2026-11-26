#!/usr/bin/env bats
# DIA-097 approved item 3: unit tests for
# scripts/check-orchestrator-prompt-drift.sh (2026-08-13, implementation lane;
# marker-set extension 2026-08-13 by the ai-auditor Minor fix lane - 5 -> 8
# markers, +3 tests below; hoist to a single md source DIA-261126-q9r9 / ADR 16
# - the fixture writer now seeds orchestrator.md and the jsonc carries NO inline
# prompt, plus a new negative case for an inline prompt reappearing; the
# batch-approval marker was RETIRED with the boot gate, so the contract is now
# 8 markers).
# The script greps the hoisted orchestrator prompt
# (.opencode/oh-my-opencode-slim/orchestrator.md) for REQUIRED delegation-rule
# markers and fails the config gate when any marker is missing, when the prompt
# file is missing, or when an audited preset (mimo-balanced /
# openai-first-cost-balanced) carries an inline orchestrator.prompt - an inline
# copy silently overrides the md at runtime (OMO 3.0.7 precedence).
#
# Isolation strategy (validate-decision-variants.bats / validate-agent-names
# .bats conventions): every test builds a throwaway fixture tree under
# $BATS_TEST_TMPDIR and runs the checker against it via the SLIM_JSONC /
# ORCH_PROMPT_MD env overrides. The REAL config and prompt file are NEVER
# touched. Fixtures are fake prompts - with/without the required markers -
# proving the checker catches drift without depending on the live config.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CHECKER="$REPO_ROOT/scripts/check-orchestrator-prompt-drift.sh"

# A prompt carrying ALL required markers (what a non-drifted orchestrator
# prompt must contain). Written with the exact marker spellings the checker
# greps for (pure-dispatch appears uppercase as PURE-DISPATCH in the real
# prompts; the checker matches it case-insensitively). The last three clauses
# mirror the DIA-097-added content locked by the ai-auditor Minor fix: the
# DIA-126a READ-SCOPE note, the EBDV (DIA-115) clause, and the 15/25 threshold
# text (READ-SCOPE / EBDV / 15% (primary) are the three new needles).
FULL_PROMPT="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."

# A full-marker prompt minus ONE marker's clause (each drifty test below spells
# its variant out explicitly - the removed clause is exactly the needle the
# checker must miss, so gap-count assertions stay accurate). READ-SCOPE /
# EBDV / 15% (primary) are the three markers added by the ai-auditor Minor fix.
DRIFTY_NO_DIA133="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_DELEGATION="Orchestrator Operating Rules: DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_BASH="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_READSCOPE="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_EBDV="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. Self-rerun at >=15% (primary) / >=25% (safety-net). TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_THRESHOLD="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. TODOWRITE DIA-260819-880v: use todowrite for >=3-step work."
DRIFTY_NO_TODOWRITE="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=15% (primary) / >=25% (safety-net)."

# fixture_dir: echoes a fresh throwaway tree (created on demand).
fixture_dir() {
  local dir="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$dir"
  echo "$dir"
}

# write_prompt <dir> [prompt]: seeds the hoisted prompt file (the single source
# the checker audits). Defaults to FULL_PROMPT.
write_prompt() {
  local dir="$1" text="${2:-$FULL_PROMPT}"
  printf '%s\n' "$text" > "$dir/orchestrator.md"
}

# write_config <file> [inline_preset] [inline_prompt]:
# writes a minimal JSONC config with the 2 audited presets and NO inline
# orchestrator.prompt - the hoisted md is the single source post-ADR-16.
# Passing inline_preset re-adds an inline prompt to that one preset, which is
# exactly the silent-override hazard the checker must reject.
write_config() {
  local file="$1" inline_name="${2:-}" inline_prompt="${3:-}"
  local names=(mimo-balanced openai-first-cost-balanced)
  local name
  {
    printf '{\n  "presets": {\n'
    for name in "${names[@]}"; do
      printf '    "%s": {\n      "orchestrator": {\n        "model": "test/model",\n' "$name"
      if [ "$name" = "$inline_name" ]; then
        printf '        "prompt": "%s"\n' "$inline_prompt"
      else
        printf '        "variant": "high"\n'
      fi
      printf '      }\n    }'
      [ "$name" = "openai-first-cost-balanced" ] || printf ','
      printf '\n'
    done
    printf '  }\n}\n'
  } > "$file"
}

@test "check-orchestrator-prompt-drift: prompt with all markers and no inline preset prompt PASSES" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  write_config "$dir/ok.jsonc"

  SLIM_JSONC="$dir/ok.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 0
  assert_output_contains "2 preset(s) checked, 8 markers each, 0 gaps"
  assert_output_contains "no inline prompt"
  assert_output_not_contains "FAIL"
}

@test "check-orchestrator-prompt-drift: missing DIA-133 marker FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_DIA133"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'DIA-133'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing delegation-only marker FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_DELEGATION"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'delegation-only'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing no-bash-tool marker FAILS (phrase with spaces)" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_BASH"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'no bash tool'"
}

@test "check-orchestrator-prompt-drift: missing READ-SCOPE (DIA-126a note) FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_READSCOPE"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'READ-SCOPE'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing EBDV (DIA-115 clause) FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_EBDV"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'EBDV'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing threshold text (15% primary) FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_THRESHOLD"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker '15% (primary)'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing TODOWRITE (DIA-260819-880v) FAILS with 1 gap" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "$DRIFTY_NO_TODOWRITE"
  write_config "$dir/drift.jsonc"

  SLIM_JSONC="$dir/drift.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt: missing required marker 'TODOWRITE DIA-260819-880v'"
  assert_output_contains "1 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: pure-dispatch matched case-insensitively (lowercase in prompt PASSES)" {
  dir="$(fixture_dir)"
  write_prompt "$dir" "${FULL_PROMPT/PURE-DISPATCH/pure-dispatch}"
  write_config "$dir/ok.jsonc"

  SLIM_JSONC="$dir/ok.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 0
  assert_output_not_contains "FAIL"
}

@test "check-orchestrator-prompt-drift: inline orchestrator.prompt reappearing in a preset FAILS (silent override)" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  write_config "$dir/inline.jsonc" openai-first-cost-balanced "$FULL_PROMPT"

  SLIM_JSONC="$dir/inline.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: openai-first-cost-balanced: inline orchestrator.prompt present"
  assert_output_contains "silently overrides"
  assert_output_not_contains "FAIL: mimo-balanced"
}

@test "check-orchestrator-prompt-drift: missing prompt file FAILS (prompt gone entirely)" {
  dir="$(fixture_dir)"
  write_config "$dir/ok.jsonc"

  SLIM_JSONC="$dir/ok.jsonc" ORCH_PROMPT_MD="$dir/nope.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: orchestrator prompt missing entirely"
}

@test "check-orchestrator-prompt-drift: preset absent from config FAILS" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  cat > "$dir/nopreset.jsonc" <<JSONC
{
  "presets": {
    "mimo-balanced": {
      "orchestrator": {}
    }
  }
}
JSONC

  SLIM_JSONC="$dir/nopreset.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: openai-first-cost-balanced: preset missing from config"
}

@test "check-orchestrator-prompt-drift: JSONC comments and trailing commas are tolerated" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  # The real config is JSONC (comments + trailing commas inside blocks). The
  # checker must not choke on them - the char-level stripper removes both.
  cat > "$dir/commenty.jsonc" <<JSONC
{
  // a comment before presets
  "presets": {
    "mimo-balanced": {
      "orchestrator": {
        "model": "test/model",
      },
    },
    "openai-first-cost-balanced": {
      /* block comment */
      "orchestrator": {
        "model": "test/model",
      },
    },
  },
}
JSONC

  SLIM_JSONC="$dir/commenty.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 0
  assert_output_contains "2 preset(s) checked, 8 markers each, 0 gaps"
}

@test "check-orchestrator-prompt-drift: invalid JSONC exits 1 (config defect, not INFRA)" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  echo '{ "presets": { broken' > "$dir/broken.jsonc"

  SLIM_JSONC="$dir/broken.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "JSONC parse failed"
}

@test "check-orchestrator-prompt-drift: missing config file exits 2 (INFRA)" {
  dir="$(fixture_dir)"
  write_prompt "$dir"

  SLIM_JSONC="$BATS_TEST_TMPDIR/nonexistent.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" run bash "$CHECKER"

  assert_status 2
  assert_output_contains "not found"
}

@test "check-orchestrator-prompt-drift: PRESETS override scopes the preset check" {
  dir="$(fixture_dir)"
  write_prompt "$dir"
  # Only mimo-balanced present in the fixture config: scoping the audit to it
  # must not report the absent openai-first-cost-balanced preset.
  cat > "$dir/one.jsonc" <<JSONC
{
  "presets": {
    "mimo-balanced": {
      "orchestrator": {
        "model": "test/model"
      }
    }
  }
}
JSONC

  SLIM_JSONC="$dir/one.jsonc" ORCH_PROMPT_MD="$dir/orchestrator.md" PRESETS="mimo-balanced" run bash "$CHECKER"

  assert_status 0
  assert_output_contains "1 preset(s) checked"
  assert_output_not_contains "FAIL"
}

@test "check-orchestrator-prompt-drift: Makefile wiring - test-config references the checker" {
  # Same seam-guard shape as validate-decision-variants.bats: a future edit
  # cannot silently drop the checker from the config gate. Recipe line form is
  # `bash scripts/check-orchestrator-prompt-drift.sh`.
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/check-orchestrator-prompt-drift.sh"
}
