# DCP Stale-Reference Removal Inventory (DIA-260821-8kpc)

- Source: ai-specialist inventory (DIA-260819-9oxi follow-up)
- Date: 2026-08-21
- Ticket: DIA-260821-8kpc
- Scope: config-work implementation (AGENTS.md section 2.5)

## What was removed
The DCP plugin was already removed from the live config (commit 69dcdaf,
DIA-260819-9oxi). This change removes only the remaining STALE references to
DCP across docs, tests, and config-detection logic. No live plugin/config
behavior changed.

## Files touched
1. AGENTS.md - dropped `dcp.jsonc` from the section 2.5 scope list.
2. scripts/__tests__/routing-order-gate.test.mjs - removed `dcp\.jsonc` from
   the config-work regex, removed the `detects dcp.jsonc (F3)` test case,
   removed the `Change dcp.jsonc permissions` test-data entry, updated the two
   F3 comments that named dcp.jsonc.
3. .opencode/plugins/delegation-observer.ts - removed `dcp\.jsonc|` from the
   CONFIG_WORK_PATTERN alternation (line ~2834).
4. .opencode/oh-my-opencode-slim.jsonc - removed the `(DCP-independent)`
   qualifier from orchestrator prompt rule 4 in all 4 presets
   (opencode-go, cebula, cebula-openai-hy3, free). Rule text now reads
   "explicitly surface lane errors in session summaries."
5. docs/dev-infra-audit/inventory.md - removed DCP mentions: Dockerfile.dev
   pinned ARG `dcp 3.1.14`, tools/opencode-docker config `dcp`,
   `@tarquinen/opencode-dcp@3.1.14` plugin, the `.opencode/dcp.jsonc` bullet
   (line 62), and `m4 (global DCP sparse)` in the OPEN list.
6. .opencode/memory-shelf.yaml - added short "(since removed)" annotations to
   two historical conspect descriptions (lines 665, 771). Bodies unchanged.

## Why
Stale references mislead future config audits and keep DCP in the
config-work detection surface after the plugin is gone. Removing them keeps
the inventory, tests, and detection regex consistent with the live config.

## Verification
- routing-order-gate.test.mjs: 36/36 pass (node, standalone).
- make test-config (run manually; make absent on host): all 18 steps exit 0
  (test-interview, test-skills, docker compose config, validate-opencode-config,
  validate-agent-names, validate-output-contracts, validate-reviewer-sections,
  validate-decision-variants, validate-grilling-gate,
  check-orchestrator-prompt-drift, validate-handoff, test-ticket-gate,
  validate-memory-shelf, validate-changelog, validate-dia-mentions,
  audit-agent-tool-coverage x2, batch-d-infra).
- git status: only the 6 files above changed; no ticket files touched.
