# Three live pin divergences and a malformed OpenCode install block (2026-11-12)

Date: 2026-11-12
Source: migration analysis round for campaign ticket DIA-261112-exon, persisted by the orchestrator persistence lane
Ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'

## Finding A - three live pin divergences, present BEFORE any V2 work

The working tree carries three pin divergences that make the existing parity
gates fail today, before any V2 migration work starts: (1) host opencode
1.18.32 (`.mise.toml:12`) vs container `@opencode/cli` 2.2.6
(`Dockerfile.dev:30`), compared as ONE identity by
`scripts/check-pin-sync.sh:102` (`compare opencode "${MISE_OPENCODE}"
"${DOCKER_OPENCODE}"`), so the 1.x-vs-2.x major split is invisible to the
gate; (2) oh-my-opencode-slim 2.2.19 config (`.opencode/opencode.jsonc:817`)
and 2.2.19 tui (`.opencode/tui.json:2`) vs 3.0.7 image cache
(`Dockerfile.dev:33`), enforced equal by `scripts/check-omo-version-sync.sh:34`
(`config_pin != tui_pin || config_pin != image_pin` -> exit 1); (3)
`@dietrichgebert/ponytail` unpinned at `.opencode/opencode.jsonc:822`, so it
floats to latest. DIAGNOSIS (not measured behaviour): a container already on
2.2.6 cannot load the V1-line plugins in the tree at all - either the pin is
stale or the container is already broken, and that must be verified live
before migration planning.

## Finding B - malformed OpenCode install block (build blocker)

`Dockerfile.dev:280` begins with a literal plus character inside the
`RUN npm install ... && \` block (line 279 continues into
`+    opencode --version`), so the OpenCode install block is malformed as
written. DIAGNOSIS (not measured behaviour): the shell would treat `+` as a
command in the continuation, so the image build fails at this step - recorded
as a BUILD BLOCKER, not a style nit.

## References

- `.mise.toml:12`, `Dockerfile.dev:30`, `Dockerfile.dev:33`,
  `Dockerfile.dev:279-280`, `scripts/check-pin-sync.sh:102`,
  `.opencode/opencode.jsonc:817`, `.opencode/opencode.jsonc:822`,
  `.opencode/tui.json:2`, `scripts/check-omo-version-sync.sh:34`.
- Shelf: `knowledge/ana-261112-ibny-opencode-infra-keep-or-delete-matrix/`
  (keep-or-delete matrix, same campaign ticket).
