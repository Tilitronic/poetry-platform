# Dual pin model resolved with an inert Dockerfile ARG, and a red test-config baseline (2026-11-13)

Date: 2026-11-13
Source: migration measurement round for campaign ticket DIA-261112-exon, persisted by the orchestrator persistence lane
Ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'

## Fact C - dual pin model resolved, the image ARG is inert

The container really runs OpenCode 1.18.32 resolved through the mise shim at
`/usr/local/bin/opencode` (`mise ls` lists opencode 1.18.32 from `.mise.toml:12`),
and `@opencode/cli` is NOT installed globally (`npm ls -g --depth=0` has no such
package). Therefore `Dockerfile.dev:30 ARG OPENCODE_VERSION=2.2.6` never takes
effect at runtime: the image-level install is either absent or shadowed by the
mise shim, and `scripts/check-pin-sync.sh:102` compares two pins of which only one
is live. DIAGNOSIS (consequence, not measured behaviour): the project has TWO
competing pin models for the same binary and must pick one - drop the mise
opencode entry and rely on the image install, keep mise and delete the image
install plus its ARG, or keep both and make the gate compare the live pin only.
Also recorded: blocker B7 from the migration brief (`docs/opencode-v2-migration-brief.md:56`)
is RESOLVED and was NOT the feared failure - the running V1 plugin set is healthy
(registry.jsonl written ~1.8 min before measurement, ticker.json ~26 s, OMO log
"health check passed {agents:23,tools:9,mcps:2}", zero plugin-load errors).

## Fact D - red baseline is not "all green except one"

`make test-config` currently exits 2 at the OMO version-sync step (`Makefile:260`)
and, because the recipe is sequential, the 13 steps AFTER it never execute - they
are UNVERIFIED, not passing. Independent measurements: `scripts/check-pin-sync.sh`
EXIT=1 (opencode 1.18.32 vs Dockerfile 2.2.6), `scripts/check-omo-version-sync.sh`
EXIT=1 (2.2.19/2.2.19/3.0.7), `scripts/validate-plugin-structure.sh` EXIT=0.
DIAGNOSIS (consequence, not a measured behaviour): any claim that a later change
"keeps the gates green" is unfalsifiable until the first two are repaired and the
full recipe is re-run end to end.

## References

- `.mise.toml:12`, `Dockerfile.dev:30`, `scripts/check-pin-sync.sh:102`,
  `Makefile:257-300` (sequential test-config recipe; OMO step at `Makefile:260`),
  `scripts/check-omo-version-sync.sh`, `scripts/validate-plugin-structure.sh`,
  `docs/opencode-v2-migration-brief.md:56` (blocker B7).
- Shelf: `knowledge/res-261112-1ima-opencode-version-migration/` (V1 -> V2
  migration conspect, same campaign ticket).
