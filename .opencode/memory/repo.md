Repository facts (irrecoverable pointers)

- Dev orchestration helpers live under scripts/ and are the canonical place for host-level orchestration wrappers (scripts/dev-stack.sh, scripts/test-docker-smoke.sh).
- Dev-infra tests are in scripts/__tests__/ and vendorised bats-core is pinned into scripts/__tests__/vendor/.
- Python API tests are under apps/api-server/tests/ with pytest configuration in pyproject.toml.
- Makefile targets: test-shell, test-python, test-infra, test-config are the developer entrypoints for dev-infra verification.
- Opencode config validators live in .opencode/scripts/validate-opencode-config.sh

Note: These are navigational facts to help future humans find the infra/test artifacts quickly; they do not duplicate commit history or diffs.

- Context7 API host facts (2026-08-02): api.context7.com is dead (NXDOMAIN). The live REST base used by the implemented pipeline is https://context7.com/api (v2 endpoints such as /api/v2/libs/search and /api/v2/context). Do NOT reintroduce api.context7.com; prefer the canonical base and verify via DNS before use. This is an operational repo fact recorded because DNS/host state is not recoverable from the repository commits.
