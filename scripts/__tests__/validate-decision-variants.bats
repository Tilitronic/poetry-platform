#!/usr/bin/env bats
# DIA-115 approved item 1: unit tests for
# scripts/validate-decision-variants.sh (2026-08-13, section-10 implementation
# lane). EBDV = evidence-backed decision variants; the script mechanically
# enforces the EBDV format on RECORDED decisions in DIA ticket files.
#
# Isolation strategy (validate-agent-names.bats / tickets.bats conventions):
# every test builds a throwaway fixture ledger under $BATS_TEST_TMPDIR and runs
# the validator against it via the TICKETS_DIR env override. The REAL ledger at
# docs/dev-infra-audit/tickets/ is NEVER touched. Only the ticket files under
# TICKETS_DIR are scanned - the validator resolves ROOT from BASH_SOURCE, so
# the fixture tree needs no scripts/ copy.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-decision-variants.sh"

# fixture_dir: echoes a fresh throwaway ledger dir (created on demand).
fixture_dir() {
  local dir="$BATS_TEST_TMPDIR/tickets"
  mkdir -p "$dir"
  echo "$dir"
}

@test "validate-decision-variants: valid 2-variant + chosen ticket PASSES" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-200-valid.md" <<'TICKET'
---
id: DIA-200
title: "valid eb dv ticket"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

### Variant A: Use the conspect-backed approach
knowledge/res022-evidence-backed-decision-variants/ documents this pattern.

### Variant B: Status-quo (keep current config)
.sdd/current/architecture.md confirms no change is needed.

### Chosen: Variant A - because knowledge/res022 is a Tier-1 committed pointer
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-decision-variants: 1 tickets checked, 1 passed, 0 failed"
}

@test "validate-decision-variants: single-variant-no-abort ticket FAILS rule b (and rule a)" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-201-single.md" <<'TICKET'
---
id: DIA-201
title: "single variant no abort"
area: opencode-config
severity: Low
status: OPEN
---

## Decision-variants

### Variant A: Just do the thing
knowledge/res022-evidence-backed-decision-variants/ backs this approach.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  # one variant, no fewer-than-2 marker -> rule a; no abort heading -> rule b
  assert_output_contains "rule a"
  assert_output_contains "rule b"
  assert_output_contains "DIA-201-single.md"
  assert_output_contains "1 tickets checked, 0 passed, 1 failed"
}

@test "validate-decision-variants: variant with no evidence marker FAILS rule e" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-202-bare.md" <<'TICKET'
---
id: DIA-202
title: "evidence-bare variant"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

### Variant A: Option one
Just vibes, no evidence anywhere in this block.

### Variant B: Option two (status-quo alternative)
This is the do-nothing path.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "rule e"
  assert_output_contains "DIA-202-bare.md"
}

@test "validate-decision-variants: [INFERENCE]-only single variant FAILS rule f" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-203-inference.md" <<'TICKET'
---
id: DIA-203
title: "single inference-only variant"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

fewer-than-2-alternatives

### Variant A: Status-quo (keep current, inferred)
[INFERENCE] derived from the res014 ladder structure.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  # rule a passes via the fewer-than-2 marker, rule b passes via the
  # Status-quo heading, rule c passes - only rule f fires
  assert_output_contains "rule f"
  assert_output_not_contains "rule a"
  assert_output_not_contains "rule b"
  assert_output_contains "DIA-203-inference.md"
}

@test "validate-decision-variants: 2 variants, one [INFERENCE] + one Tier-1 pointer PASSES" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-204-mixed.md" <<'TICKET'
---
id: DIA-204
title: "mixed evidence ticket"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

### Variant A: Use the conspect-backed approach
knowledge/res022-evidence-backed-decision-variants/ is the Tier-1 pointer here.

### Variant B: Alternative inferred path (status-quo)
[INFERENCE] derived from the res014 escalation ladder structure.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-decision-variants: 1 tickets checked, 1 passed, 0 failed"
}

@test "validate-decision-variants: ticket with no decision-variant section is skipped" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-205-plain.md" <<'TICKET'
---
id: DIA-205
title: "plain ticket"
area: docs
severity: Low
status: OPEN
---

## Description

A regular ticket with no decision-variant block and no Chosen record.

## Verification

- [ ] nothing to verify
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-decision-variants: 1 tickets checked, 1 passed, 0 failed"
  assert_output_not_contains "FAIL"
}

@test "validate-decision-variants: '## Alternatives considered' section is a valid opt-in (Tier-2 dated URL)" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-206-alt.md" <<'TICKET'
---
id: DIA-206
title: "alternatives-considered ticket"
area: opencode-config
severity: Medium
status: OPEN
---

## Description

## Alternatives considered

### Variant A: Vendor managed service
https://docs.example.com/pricing/2026-08-01 shows the cost model.

### Variant B: Abort - keep self-hosted
openspec/changes/dev-infra-stack-hardening/ defines the current setup.

### Chosen: Variant B
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-decision-variants: 1 tickets checked, 1 passed, 0 failed"
}

@test "validate-decision-variants: _TEMPLATE.md is never validated" {
  dir="$(fixture_dir)"
  cat > "$dir/_TEMPLATE.md" <<'TICKET'
---
id: DIA-TPL
title: "template"
area: docs
severity: Info
status: OPEN
---

## Decision-variants

### Variant A: something
no evidence at all - deliberately broken template

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "0 tickets checked, 0 passed, 0 failed"
}

@test "validate-decision-variants: missing TICKETS_DIR exits 2 (INFRA)" {
  TICKETS_DIR="$BATS_TEST_TMPDIR/nonexistent" run bash "$VALIDATOR"

  assert_status 2
  assert_output_contains "tickets dir not found"
}

@test "validate-decision-variants: >=2 variants ALL [INFERENCE]-only FAILS rule g (whole-decision needs Tier-1/Tier-2)" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-207-all-inf.md" <<'TICKET'
---
id: DIA-207
title: "all inference variants"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

### Variant A: Inferred config path forward
[INFERENCE] derived from the res014 escalation ladder structure.

### Variant B: Status-quo (keep current config)
[INFERENCE] derived from the res022 tier definitions.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  # rules a/b/c all pass (2 variants, Status-quo heading, Chosen line);
  # d/e pass ([INFERENCE] is a valid per-variant marker); f does not fire
  # (count 2 != 1) - ONLY rule g fires: no Tier-1/Tier-2 anywhere in the
  # section, so the whole decision is T3-alone and is rejected.
  assert_output_contains "rule g"
  assert_output_not_contains "rule a"
  assert_output_not_contains "rule b"
  assert_output_not_contains "rule c"
  assert_output_not_contains "rule f"
  assert_output_contains "DIA-207-all-inf.md"
}

@test "validate-decision-variants: 2 variants with >=1 knowledge/ Tier-1 pointer PASSES rule g (regression guard)" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-208-tier1.md" <<'TICKET'
---
id: DIA-208
title: "tier-1 backed decision"
area: opencode-config
severity: Medium
status: OPEN
---

## Decision-variants

### Variant A: Conspect-backed approach
knowledge/res022-evidence-backed-decision-variants/ defines the tier contract.

### Variant B: Status-quo inferred alternative
[INFERENCE] derived from the res014 escalation ladder structure.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  # rule g must NOT fire: Variant A carries a knowledge/ Tier-1 pointer, so
  # the whole decision has real evidence despite Variant B being
  # [INFERENCE]-only (regression guard against over-eager whole-decision
  # rejection).
  assert_output_contains "ok: validate-decision-variants: 1 tickets checked, 1 passed, 0 failed"
  assert_output_not_contains "rule g"
}

@test "validate-decision-variants: fewer-than-2 marker OUTSIDE the decision section does NOT satisfy rule a" {
  dir="$(fixture_dir)"
  cat > "$dir/DIA-209-outside.md" <<'TICKET'
---
id: DIA-209
title: "marker outside decision section"
area: opencode-config
severity: Medium
status: OPEN
---

## Description

fewer-than-2-alternatives

A single-alternative decision with the marker text in the Description area
instead of inside the decision-variants section.

## Decision-variants

### Variant A: Status-quo (keep current config)
knowledge/res022-evidence-backed-decision-variants/ backs this approach.

### Chosen: Variant A
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  # the marker lives OUTSIDE the extracted decision section, so rule a must
  # fire; rule b passes (Status-quo heading), rule c passes, rule e passes
  # (Tier-1 evidence), rule f passes (Tier-1 present), rule g does not apply
  # (count 1 < 2)
  assert_output_contains "rule a"
  assert_output_not_contains "rule b"
  assert_output_not_contains "rule c"
  assert_output_not_contains "rule f"
  assert_output_not_contains "rule g"
  assert_output_contains "DIA-209-outside.md"
}

@test "validate-decision-variants: Makefile wiring - test-config references the validator" {
  # Same seam-guard shape as test-config-wiring.bats: a future edit cannot
  # silently drop the validator from the config gate. Recipe line form is
  # `bash scripts/validate-decision-variants.sh` (same shape as the other
  # validate-*.sh calls).
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-decision-variants.sh"
}
