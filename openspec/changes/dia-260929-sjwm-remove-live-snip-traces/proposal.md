---
ownership:
  substance: developer
  structure: AI
  interview_depth: compressed
  interview_reason: 'DIA-104 cross-boundary/cross-cutting/hard-to-reverse triggers; developer pre-resolved scope decisions 1-3 (global cleanup, history kept, dormant deny removal) as the authoritative compressed grill.'
campaign_ticket: DIA-260929-sjwm
---

## Why

SNIP has been fully abandoned, but live traces remain in the repository and in
the user-global OpenCode config. `Dockerfile.dev` still installs the `snip`
binary and pins `SNIP_VERSION`; `.opencode/opencode.jsonc` still carries a
four-rule dormant `snip` / `snip *` deny block plus a comment that says
"do NOT remove these rules"; `.opencode/agents/coder-escalated.md` still
documents that deny in its permission ground-truth block; and
`docs/dev-infra-audit/inventory.md` still lists `snip 0.22.0` as a live image
pin.

The startup warning `[snip] snip binary not found in PATH - plugin disabled`
does NOT originate in any repository file. It originates in the user-global
OpenCode config plugin array (prior recorded path
`/home/mimic/.config/opencode/opencode.jsonc` line 4, entry
`opencode-snip@latest`), evidenced by DIA-260827-txq2 line 41 and
`knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit/ana-260831-6w4y-full-repository-four-lane-reaudit-report.md`
line 385. The repository cleanup alone therefore cannot silence the warning;
the out-of-repo global declaration must be removed too.

Governing ticket: DIA-260929-sjwm 'Remove all live SNIP traces' (OPEN, area
scripts, severity Medium).

## What Changes

- **Docker/infra:** remove the `snip` binary install block, the
  `ARG SNIP_VERSION=0.22.0` pin, and every live comment reference to snip from
  `Dockerfile.dev` (8 sites: lines 5, 36, 44, 92, 128-135, 141, 170, 290).
- **OpenCode project config:** remove the `snip` / `snip *` deny rules from the
  `coder` permission block (lines 329-330) and from the `coder-escalated`
  permission block (lines 435-436), plus the DORMANT comment block (lines
  317-322) that instructs "do NOT remove these rules".
- **Agent policy doc:** remove the `bash: snip / snip * (deny)` line from
  `.opencode/agents/coder-escalated.md` (line 34).
- **Out-of-repo user-global config (delegated lane):** remove the
  `opencode-snip@latest` entry from the user-global OpenCode plugin array, and
  inspect the orphaned user-home `~/.config/snip/` config plus the `snip`
  binary on PATH. The exact global config path MUST be RE-CONFIRMED before any
  edit; the prior path is a recorded observation, not an assumption.
- **Live documentation:** update `docs/dev-infra-audit/inventory.md` (line 51)
  so the Dockerfile ARG list no longer names `snip 0.22.0`; record the
  disposition of `docs/dev-infra-audit-plan.md` (line 47).
- **Preserved historical record (MUST NOT be deleted or rewritten):**
  `.opencode/CHANGELOG.yaml` (and the derived `.opencode/CHANGELOG.md`), the
  CLOSED ticket docs (`DIA-092-snip-plugin-removal-s10.md`, `DIA-075`,
  `DIA-078`, `DIA-093`), `knowledge/archive/res011-opencode-snip-mechanical-lock/`
  (plus the sibling archived conspects res009/res010), and the post-mortem
  entries in `.opencode/memory/lessons.md` / `.opencode/memory/failures.md`.
  The ticket README index, closed-ticket references, learnings files, and
  point-in-time analysis reports also remain untouched as historical record.

**BREAKING:** none for the application. Consumers that run `snip` by name
inside the container will lose the binary; no repository script, test, or
package manifest references it (verified).

## Capabilities

### New Capabilities

None. This is removal of dead tooling plus a documentation/inventory sync. No
new or changed product or system behavior requirement is introduced.

### Modified Capabilities

None. There is no existing OpenSpec capability spec for snip, and removing a
dormant permission guard whose subject no longer exists does not change a
behavior contract. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- **Changed files:** `Dockerfile.dev`; `.opencode/opencode.jsonc`;
  `.opencode/agents/coder-escalated.md`; `docs/dev-infra-audit/inventory.md`;
  `docs/dev-infra-audit-plan.md` (disposition only); three OpenSpec artifacts.
- **Out-of-repo change:** the user-global OpenCode config plugin array
  (path re-confirmed at execution time) and, if present, the orphaned
  `~/.config/snip/` user-home config and the `snip` binary on PATH.
- **Dependencies:** removes a third-party binary dependency (`snip`,
  github.com/edouard-claude/snip). No dependency is added. No package manifest
  (`package.json`, `bun.lock`, `pnpm-lock.yaml`, `.mise.toml`) references snip.
- **Systems:** dev-container image build (`Dockerfile.dev`) and the OpenCode
  permission/config surface only. `make test-infra` re-validates the image.
- **Confirmed clean already:** `.opencode/opencode.jsonc` project plugin array
  (lines 749-760) contains no snip entry; no `.opencode/package.json` exists;
  no `scripts/*.sh` (including `scripts/overnight.sh`) references snip; no
  `tools/`, `docker-compose*.yml`, `dev-entrypoint.sh`, `.devcontainer/`, or
  CI config references snip.

## Testing Decisions

Full strategy lives in `design.md` (Test strategy). In brief: the test seams
are the existing gates - `make test-config` (config parse, agent-name lockstep,
JSONC validity, observer-dedupe) and `make test-infra` (image build + smoke).
A repo-wide token scan for the live snip surface proves absence. No new test
harness is introduced for a removal change; the Dockerfile install block and
the deny rules are deleted, not replaced.

## Rollback Plan

Full plan lives in `design.md` (Rollback plan). In brief: the in-repo edits are
Git-tracked and revert with one `git revert` of the change commit, restoring
the pinned `snip` install and the dormant deny rules. The out-of-repo global
config edit is NOT under version control and MUST have its pre-edit content
captured (backup or exact diff) before editing so the developer can restore it
by hand.

## Alternatives considered

- **Variant A - full live-surface removal (repo + out-of-repo global config):**
  chosen. Evidence: developer instruction "remove everything connected with it
  ... complete cleanup"; DIA-260827-txq2 line 41 and
  `knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit/ana-260831-6w4y-full-repository-four-lane-reaudit-report.md`
  line 385 record the global declaration as the source of the live warning.
- **Variant B - remove repository traces only, leave the global declaration:**
  rejected. The startup warning and the plugin load originate out-of-repo, so
  this variant leaves the reported symptom live. Evidence: Tier-1 DIA-260827-txq2
  line 41; ana-260831-6w4y line 385.
- **Variant C - keep the four deny rules as a dormant guardrail (the DIA-092
  council 5/5 position):** rejected. The developer explicitly reversed that
  position in decision 3; once the global declaration and the binary are gone
  the guard has no subject, and a rule that instructs "do NOT remove" against
  the developer's cleanup intent is itself a live trace. Evidence: Tier-1
  `docs/dev-infra-audit/tickets/DIA-092-snip-plugin-removal-s10.md` (council
  reversal, dormant-rule rationale); developer decision 3 (this dispatch).
- **Status-quo / do nothing:** rejected. It leaves a third-party binary and
  orphan config in the image, a stale inventory claim, and a live startup
  warning. Evidence: Tier-1 live reads of `Dockerfile.dev:36`,
  `.opencode/opencode.jsonc:329-330`, `docs/dev-infra-audit/inventory.md:51`.

Chosen option: Variant A - because the developer directed a complete cleanup
and the only evidence-backed way to silence the live SNIP warning is to remove
both the repository traces and the user-global plugin declaration.

## Ticket linkage

- **Governs:** DIA-260929-sjwm (this change).
- **Evidence refs:** DIA-260827-txq2 line 41;
  `knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit` line 385;
  `docs/dev-infra-audit/tickets/DIA-092-snip-plugin-removal-s10.md`.
- **History preserved:** DIA-092, DIA-075, DIA-078, DIA-093 (CLOSED).
