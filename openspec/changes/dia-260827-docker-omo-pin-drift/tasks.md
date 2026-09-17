## 1. Pin bump (single token)

- [ ] 1.1 Change `oh-my-opencode-slim@2.2.14` to `oh-my-opencode-slim@2.2.19`
      in the `plugin` array of `tools/opencode-docker/config/opencode.json`
      (line 25). Touch nothing else: no MCP edits, no preset block, no key
      reorder, no formatting churn. **Acceptance:** `git diff --stat` shows one
      implementation file, one line (ticket-ledger bookkeeping excluded); `jq -re '.plugin[] | select(test("^oh-my-opencode-slim@"))'
tools/opencode-docker/config/opencode.json` outputs exactly
      `oh-my-opencode-slim@2.2.19`. Scope guard: diff introducing any other
      hunk fails review. **Blocks:** 2.1.

## 2. Validation gates (existing seams)

- [ ] 2.1 Run `make test-config`; assert exit 0. Covers
      `scripts/validate-observer-dedupe.sh` (legacy file input) and
      `scripts/audit-agent-tool-coverage.sh` (via Makefile:236) against the
      bumped file. **Acceptance:** exit 0 with both validators reporting the
      legacy file clean. **Blocks:** 2.2, 3.1.
- [ ] 2.2 Plugin load check for the standalone config: prove the bumped pin
      resolves (cheapest available at build time - bun/npm dry-run install or
      standalone startup log showing 2.2.19 loaded, no resolve error).
      **Acceptance:** evidence line (version string 2.2.19 from the resolver or
      startup log). **Blocks:** 3.1.

## 3. Spec hygiene + review

- [ ] 3.1 Run `openspec validate dia-260827-docker-omo-pin-drift`; assert
      validation passes. **Acceptance:** validator exit 0. **Blocks:** 3.2.
- [ ] 3.2 Dispatch `@reviewer` two-axis review (Standards + Spec fidelity) on
      the one-token diff. **Acceptance:** no Critical findings; diff confirmed
      one token; scope guards (no MCP/preset/retire creep) confirmed.
