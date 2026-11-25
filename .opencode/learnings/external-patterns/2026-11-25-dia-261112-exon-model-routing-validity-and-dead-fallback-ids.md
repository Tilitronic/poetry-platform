# Agent model-routing validity gate and dead fallback IDs (2026-11-25)

Date: 2026-11-25
Ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'
Topic: agent model-routing validity gate and dead fallback IDs
Source: ai-specialist gate findings for the model-routing review, persisted by the orchestrator persistence lane

## What changed

Developer-authored routing in `.opencode/oh-my-opencode-slim.jsonc`, preset
`mimo-balanced`:

| Agent | Line | Primary | Fallback | Variant |
| --- | --- | --- | --- | --- |
| coder | L69 | opencode-go/deepseek-v4.1-flash | opencode-go/mimo-v2.6-flash | high |
| reviewer | L88 | opencode-go/kimi-k3.1-pro | opencode-go/qwen4-max | high |
| analyzer | L100 | opencode-go/deepseek-v4.1-flash | opencode-go/mimo-v2.6-flash | high |
| designer | L113 | opencode-go/deepseek-v4.1-flash | opencode-go/mimo-v2.6-flash | high |

Routing is developer-owned and must NOT be rebalanced by a later lane.

## Validity outcome

All four model IDs pass the live catalog (OpenCode CLI 1.18.32, catalog mtime
2026-11-25). `variant: "high"` is schema-legal: the field is a free string with
no enum, and `high` is a real rung on deepseek (low|high|max), kimi
(low|high|max) and qwen4 (low|high|xhigh); the mimo ladder is unasserted
in-repo. All 11 declared skill names resolve under `.opencode/skills/`.
`mcps: ["websearch"]` (analyzer) is OMO's built-in surface, not an MCP server
entry; the same file carries 5 prior precedents.

## Lesson - the validator needs a live catalog

`scripts/validate-model-ids.sh` is the hard authority. It SKIPs with exit 0
when the opencode CLI catalog is unavailable, so a SKIP is NOT a pass.
Read-only lanes cannot run it (no shell), so the gate must be run by a
shell-capable lane BEFORE committing config.

## Lesson - dead fallback IDs hide behind passing primaries

The same run found 5 pre-existing invalid IDs that the routing diff did not
introduce:

- `opencode-go/mimo-v2.5` at `jsonc:127` (conspecter)
- `opencode-go/mimo-v2.5` at `jsonc:166` (memory-manager)
- `opencode-go/mimo-v2.5` at `jsonc:178` (code-navigator)
- `opencode-go/mimo-v2.5` at `jsonc:187` (researcher)
- `opencode-go/longcat-2.0` at `jsonc:154` (ai-auditor)

The developer diff reduced failures 6 -> 5. Catalog near-matches:
`mimo-v2.6-flash`, `longcat-2.5`. Only the primary model in each block is
exercised in normal dispatch, so dead fallbacks rot silently until the
validator runs.

## Flag to watch - temperature-fixed providers

Reviewer declares `temperature: 0.1` while `kimi-k3.1-pro` declares temperature
fixed at 1.0 upstream (models.dev lists the Temperature capability as "No"). It
is UNVERIFIED whether the runtime strips the value or the provider returns 4xx.
Observe on the first reviewer dispatch and record the outcome.

## Documentation drift found

- `knowledge/model-registry.yaml` had no entries for `kimi-k3.1-pro` or
  `qwen4-max`, and its reviewer row still named `gpt-5.3-codex`.
- The preset block comment at `jsonc:14` still claimed reviewer unchanged on
  `deepseek-v4.1-flash` and designer on `qwen3.8-flash`.

Registry rows are WARN-only in the validator, but they are DIA-133
dispatch-routing and quota-guard inputs, so empty rows degrade quota lookups.

## Sources

- `scripts/validate-model-ids.sh` - severity L14-27, skip L53-57, fail loop
  L176-198, registry WARN L200-209.
- `knowledge/model-registry.yaml`.
- models.dev provider rows for `kimi-k3.1-pro` and `qwen4-max` (fetched
  2026-11-25).
- models.dev PR #13760 adding `qwen4-max` (merged 2026-11-16).

## Outcome (2026-11-25)

fc1a15f8 repaired the five dead fallback IDs and added the two registry rows;
1dc21859 collapsed the four duplicated fallback arrays, so the dead-ID and
missing-row defects above are RESOLVED in config.
OPEN: (1) reviewer temperature 0.1 against kimi-k3.1-pro fixed 1.0 upstream,
still unverified; (2) registry lane/routing_table reconciliation tracked in
DIA-261125-mu6w; (3) the volume lanes now have no secondary fallback model.
