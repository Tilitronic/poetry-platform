#!/usr/bin/env bats
# DIA-097 approved item 3: unit tests for
# scripts/check-orchestrator-prompt-drift.sh (2026-08-13, implementation lane;
# marker-set extension 2026-08-13 by the ai-auditor Minor fix lane - 5 -> 8
# markers, +3 tests below).
# The script greps the 3 preset orchestrator prompts (opencode-go / cebula /
# free) in oh-my-opencode-slim.jsonc for REQUIRED delegation-rule markers and
# fails the config gate when any marker is missing from any prompt.
#
# Isolation strategy (validate-decision-variants.bats / validate-agent-names
# .bats conventions): every test builds a throwaway fixture JSONC under
# $BATS_TEST_TMPDIR and runs the checker against it via the SLIM_JSONC env
# override. The REAL .opencode/oh-my-opencode-slim.jsonc is NEVER touched.
# Fixtures are fake prompts - with/without the required markers - proving the
# checker catches drift without depending on the live config.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CHECKER="$REPO_ROOT/scripts/check-orchestrator-prompt-drift.sh"

# A prompt carrying ALL required markers (what a non-drifted orchestrator
# prompt must contain). Written with the exact marker spellings the checker
# greps for (pure-dispatch appears uppercase as PURE-DISPATCH in the real
# prompts; the checker matches it case-insensitively). The last three clauses
# mirror the DIA-097-added content locked by the ai-auditor Minor fix: the
# DIA-126a READ-SCOPE note, the EBDV (DIA-115) clause, and the 30/50 threshold
# text (READ-SCOPE / EBDV / 30% (primary) are the three new needles).
FULL_PROMPT="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=30% (primary) / >=50% (safety-net)."

# A full-marker prompt minus ONE marker's clause (each drifty test below spells
# its variant out explicitly - the removed clause is exactly the needle the
# checker must miss, so gap-count assertions stay accurate). READ-SCOPE /
# EBDV / 30% (primary) are the three markers added by the ai-auditor Minor fix.
DRIFTY_NO_DIA133="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=30% (primary) / >=50% (safety-net)."
DRIFTY_NO_DELEGATION="Orchestrator Operating Rules: batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=30% (primary) / >=50% (safety-net)."
DRIFTY_NO_BASH="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=30% (primary) / >=50% (safety-net)."
DRIFTY_NO_READSCOPE="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. EBDV (DIA-115): evidence-backed decision variants. Self-rerun at >=30% (primary) / >=50% (safety-net)."
DRIFTY_NO_EBDV="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. Self-rerun at >=30% (primary) / >=50% (safety-net)."
DRIFTY_NO_THRESHOLD="Orchestrator Operating Rules: you are delegation-only and FORBIDDEN from reading repo files. batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE: every task() call is the sole tool call. The orchestrator has no bash tool by design. DIA-126a READ-SCOPE NOTE: read/glob allow-list expanded 2026-08-13. EBDV (DIA-115): evidence-backed decision variants."

# fixture_dir: echoes a fresh throwaway tree (created on demand).
fixture_dir() {
  local dir="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$dir"
  echo "$dir"
}

# write_config <file> <go_prompt> <cebula_prompt> <free_prompt>:
# writes a minimal JSONC config with the 3 audited presets, each carrying the
# given orchestrator prompt. Formatting deliberately mimics the real file
# (prompt is the LAST key in the orchestrator block, so no trailing comma).
write_config() {
  local file="$1" go="$2" ceb="$3" free="$4"
  cat > "$file" <<JSONC
{
  "presets": {
    "opencode-go": {
      "orchestrator": {
        "prompt": "$go"
      }
    },
    "cebula": {
      "orchestrator": {
        "prompt": "$ceb"
      }
    },
    "free": {
      "orchestrator": {
        "prompt": "$free"
      }
    }
  }
}
JSONC
}

@test "check-orchestrator-prompt-drift: all 3 prompts with all markers PASS" {
  dir="$(fixture_dir)"
  write_config "$dir/ok.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$FULL_PROMPT"

  SLIM_JSONC="$dir/ok.jsonc" run bash "$CHECKER"

  assert_status 0
  assert_output_contains "3 preset(s) checked, 8 markers each, 0 gaps"
  assert_output_not_contains "FAIL"
}

@test "check-orchestrator-prompt-drift: missing DIA-133 in ONE prompt FAILS and names the preset" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$DRIFTY_NO_DIA133"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: missing required marker 'DIA-133'"
  assert_output_contains "1 marker gap(s)"
  assert_output_not_contains "FAIL: opencode-go"
  assert_output_not_contains "FAIL: cebula"
}

@test "check-orchestrator-prompt-drift: missing delegation-only in all 3 prompts FAILS with 3 gaps" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$DRIFTY_NO_DELEGATION" "$DRIFTY_NO_DELEGATION" "$DRIFTY_NO_DELEGATION"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: opencode-go: missing required marker 'delegation-only'"
  assert_output_contains "FAIL: cebula: missing required marker 'delegation-only'"
  assert_output_contains "FAIL: free: missing required marker 'delegation-only'"
  assert_output_contains "3 marker gap(s)"
}

@test "check-orchestrator-prompt-drift: missing no-bash-tool marker FAILS (phrase with spaces)" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$DRIFTY_NO_BASH"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: missing required marker 'no bash tool'"
}

@test "check-orchestrator-prompt-drift: missing READ-SCOPE (DIA-126a note) in ONE prompt FAILS and names the preset" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$DRIFTY_NO_READSCOPE"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: missing required marker 'READ-SCOPE'"
  assert_output_contains "1 marker gap(s)"
  assert_output_not_contains "FAIL: opencode-go"
  assert_output_not_contains "FAIL: cebula"
}

@test "check-orchestrator-prompt-drift: missing EBDV (DIA-115 clause) in ONE prompt FAILS and names the preset" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$DRIFTY_NO_EBDV"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: missing required marker 'EBDV'"
  assert_output_contains "1 marker gap(s)"
  assert_output_not_contains "FAIL: opencode-go"
  assert_output_not_contains "FAIL: cebula"
}

@test "check-orchestrator-prompt-drift: missing threshold text (30% primary) in ONE prompt FAILS and names the preset" {
  dir="$(fixture_dir)"
  write_config "$dir/drift.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$DRIFTY_NO_THRESHOLD"

  SLIM_JSONC="$dir/drift.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: missing required marker '30% (primary)'"
  assert_output_contains "1 marker gap(s)"
  assert_output_not_contains "FAIL: opencode-go"
  assert_output_not_contains "FAIL: cebula"
}

@test "check-orchestrator-prompt-drift: pure-dispatch matched case-insensitively (PURE-DISPATCH in prompt PASSES)" {
  dir="$(fixture_dir)"
  write_config "$dir/ok.jsonc" "$FULL_PROMPT" "$FULL_PROMPT" "$FULL_PROMPT"

  SLIM_JSONC="$dir/ok.jsonc" run bash "$CHECKER"

  assert_status 0
  assert_output_not_contains "FAIL"
}

@test "check-orchestrator-prompt-drift: missing entire prompt for one preset FAILS" {
  dir="$(fixture_dir)"
  # free's orchestrator block exists but has no prompt key at all.
  cat > "$dir/missing.jsonc" <<JSONC
{
  "presets": {
    "opencode-go": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT"
      }
    },
    "cebula": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT"
      }
    },
    "free": {
      "orchestrator": {}
    }
  }
}
JSONC

  SLIM_JSONC="$dir/missing.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: orchestrator prompt missing entirely"
}

@test "check-orchestrator-prompt-drift: preset absent from config FAILS (empty prompt emitted)" {
  dir="$(fixture_dir)"
  cat > "$dir/nopreset.jsonc" <<JSONC
{
  "presets": {
    "opencode-go": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT"
      }
    },
    "cebula": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT"
      }
    }
  }
}
JSONC

  SLIM_JSONC="$dir/nopreset.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "FAIL: free: orchestrator prompt missing entirely"
}

@test "check-orchestrator-prompt-drift: JSONC comments and trailing commas are tolerated" {
  dir="$(fixture_dir)"
  # The real config is JSONC (comments + trailing commas inside blocks). The
  # checker must not choke on them - the char-level stripper removes both.
  cat > "$dir/commenty.jsonc" <<JSONC
{
  // a comment before presets
  "presets": {
    "opencode-go": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT",
      },
    },
    "cebula": {
      /* block comment */
      "orchestrator": {
        "prompt": "$FULL_PROMPT",
      },
    },
    "free": {
      "orchestrator": {
        "prompt": "$FULL_PROMPT",
      },
    },
  },
}
JSONC

  SLIM_JSONC="$dir/commenty.jsonc" run bash "$CHECKER"

  assert_status 0
  assert_output_contains "3 preset(s) checked, 8 markers each, 0 gaps"
}

@test "check-orchestrator-prompt-drift: invalid JSONC exits 1 (config defect, not INFRA)" {
  dir="$(fixture_dir)"
  echo '{ "presets": { broken' > "$dir/broken.jsonc"

  SLIM_JSONC="$dir/broken.jsonc" run bash "$CHECKER"

  assert_status 1
  assert_output_contains "JSONC parse failed"
}

@test "check-orchestrator-prompt-drift: missing config file exits 2 (INFRA)" {
  SLIM_JSONC="$BATS_TEST_TMPDIR/nonexistent.jsonc" run bash "$CHECKER"

  assert_status 2
  assert_output_contains "not found"
}

@test "check-orchestrator-prompt-drift: PRESETS override targets a single preset" {
  dir="$(fixture_dir)"
  local drifty="Orchestrator Operating Rules: batch-approval boot gate. DIA-133: consult the model registry. PURE-DISPATCH RULE. The orchestrator has no bash tool by design."
  write_config "$dir/ok.jsonc" "$FULL_PROMPT" "$drifty" "$FULL_PROMPT"

  # Only audit opencode-go: its prompt is complete, so the drift in cebula
  # must NOT be reported (PROVES the PRESETS override scopes the check).
  SLIM_JSONC="$dir/ok.jsonc" PRESETS="opencode-go" run bash "$CHECKER"

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
