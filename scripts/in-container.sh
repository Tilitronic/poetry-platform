#!/usr/bin/env bash
# in-container.sh — shared in-container detection (S6, DIA-260922-cp0m).
#
# WHY: hostname "poetry-dev" was repeated as a raw primitive in three scripts
# (check-compose-config.sh, verify-pre-push.sh, verify-pre-commit.sh). This
# helper provides one canonical definition. Sourced, not executed.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/in-container.sh"

is_in_dev_container() {
  [ "$(hostname 2>/dev/null)" = "poetry-dev" ]
}
