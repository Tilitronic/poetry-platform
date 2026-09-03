#!/usr/bin/env bats
# Unit tests for scripts/allocate-id (DIA-260819-8kwm).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  ALLOCATE="$REPO_ROOT/scripts/allocate-id"
}

# -- happy-path: valid types produce correct format --------------------------

@test "allocate-id: res type outputs res-YYMMDD-XXXX-slug" {
  run "$ALLOCATE" res test-slug
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^res-[0-9]{6}-[a-z0-9]{4}-test-slug$ ]]
}

@test "allocate-id: ana type outputs ana-YYMMDD-XXXX-slug" {
  run "$ALLOCATE" ana test-slug
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^ana-[0-9]{6}-[a-z0-9]{4}-test-slug$ ]]
}

@test "allocate-id: tch type outputs tch-YYMMDD-XXXX-slug" {
  run "$ALLOCATE" tch test-slug
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^tch-[0-9]{6}-[a-z0-9]{4}-test-slug$ ]]
}

@test "allocate-id: DIA type outputs DIA-YYMMDD-XXXX-slug" {
  run "$ALLOCATE" DIA test-slug
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^DIA-[0-9]{6}-[a-z0-9]{4}-test-slug$ ]]
}

# -- error cases ------------------------------------------------------------

@test "allocate-id: invalid type exits non-zero with usage message" {
  run "$ALLOCATE" foo test-slug
  [ "$status" -ne 0 ]
  [[ "$output" =~ "invalid type" ]]
}

@test "allocate-id: missing arguments exits non-zero" {
  run "$ALLOCATE"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "allocate-id: missing slug exits non-zero" {
  run "$ALLOCATE" res
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

# -- uniqueness -------------------------------------------------------------

@test "allocate-id: two consecutive calls produce different IDs" {
  local id1 id2
  id1="$("$ALLOCATE" res uniqueness-test)"
  id2="$("$ALLOCATE" res uniqueness-test)"
  [ "$id1" != "$id2" ]
}
