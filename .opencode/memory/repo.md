Repository facts (irrecoverable pointers)

- Dev orchestration helpers live under scripts/ and are the canonical place for host-level orchestration wrappers (scripts/dev-stack.sh, scripts/test-docker-smoke.sh).
- Dev-infra tests are in scripts/__tests__/ and vendorised bats-core is pinned into scripts/__tests__/vendor/.
- Python API tests are under apps/api-server/tests/ with pytest configuration in pyproject.toml.
- Makefile targets: test-shell, test-python, test-infra, test-config are the developer entrypoints for dev-infra verification.
- Opencode config validators live in .opencode/scripts/validate-opencode-config.sh

Note: These are navigational facts to help future humans find the infra/test artifacts quickly; they do not duplicate commit history or diffs.

- Context7 API host facts (2026-08-02): api.context7.com is dead (NXDOMAIN). The live REST base used by the implemented pipeline is https://context7.com/api (v2 endpoints such as /api/v2/libs/search and /api/v2/context). Do NOT reintroduce api.context7.com; prefer the canonical base and verify via DNS before use. This is an operational repo fact recorded because DNS/host state is not recoverable from the repository commits.

- Ledger status convention (campaign-specific, 2026-08-03): during the dev-infra audit the owner chose a campaign-level ledger convention that is NOT fully recoverable from git because session logs are gitignored. The rule applied in this run: DEFERRED tickets remain listed with status OPEN in the canonical tickets index (docs/dev-infra-audit/tickets/README.md) with disposition explained in the ticket body/overview; IMPLEMENTED tickets are synced into the ledger index (OPEN -> IMPLEMENTED + rollup recount) only after the owner-authorized registration step. This convention and the owner-driven atomic-commit-after-restart pattern are session-scoped operational facts and should be consulted when reconciling the tickets ledger vs session messages.

- Model context-window authoritative source (2026-08-03): do NOT rely on NEXT-RUN.md's static table as a primary source for model context windows. During the "dia-redispatch-cycle" campaign we discovered that the NEXT-RUN.md lookup listed `deepseek-v4-flash` as 64,000 tokens (this was the V3 value). The correct, upstream context window for deepseek-v4-flash is 1,000,000 tokens (verified via models.dev, DeepSeek official docs, HF model card, and arXiv:2606.19348). Models.dev should be consulted as the authoritative catalog for model context limits when making operational handoff/threshold decisions. Record: the repository's docs table is a convenience copy and can silently drift from live model metadata.
