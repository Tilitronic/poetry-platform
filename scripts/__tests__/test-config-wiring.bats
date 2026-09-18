#!/usr/bin/env bats
# Wiring regression for the `make test-config` target (change
# dev-infra-config-validators, task T4). Purely structural — a static grep over
# the root Makefile asserting that the test-config target body references both
# new validators (validate-agent-names.sh + validate-handoff.sh) alongside the
# pre-existing validate-opencode-config.sh. No execution, no fixtures —
# same shape as the arch-failfast wiring test in opencode-docker.bats.
#
# The validators themselves are unit-tested hermetically in
# validate-agent-names.bats / validate-handoff.bats; this test only guards the
# Makefile wiring seam so a future edit cannot silently drop the validators
# from the config gate.

load test-helper

@test "test-config wiring: Makefile references both new validators" {
  # Each new validator must appear in the test-config target body. The recipe
  # line form is `bash scripts/<name>.sh` (same shape as validate-opencode-config.sh).
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-agent-names.sh"
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-handoff.sh"
  # Pre-existing baseline preserved: validate-opencode-config.sh still wired.
  assert_file_contains "$REPO_ROOT/Makefile" "bash .opencode/scripts/validate-opencode-config.sh"
}
