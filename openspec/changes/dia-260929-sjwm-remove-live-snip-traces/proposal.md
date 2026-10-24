---
ownership:
  substance: developer
  structure: AI
  interview_depth: compressed
  interview_reason: 'DIA-104 cross-boundary/cross-cutting/hard-to-reverse triggers; developer pre-resolved scope decisions (history kept, dormant deny removal) as the authoritative compressed grill; the out-of-repo slice was later transferred to DIA-260827-txq2 (OQ1 resolved).'
campaign_ticket: DIA-260929-sjwm
---

## Why

SNIP has been fully abandoned, but live traces remain in the repository.
`Dockerfile.dev` still installs the `snip` binary and pins `SNIP_VERSION`;
`.opencode/opencode.jsonc` still carries a four-rule dormant `snip` / `snip *`
deny block plus a comment that says "do NOT remove these rules";
`.opencode/agents/coder-escalated.md` still documents that deny in its
permission ground-truth block; and `docs/dev-infra-audit/inventory.md` still
lists `snip 0.22.0` as a live image pin.

The startup warning `[snip] snip binary not found in PATH - plugin disabled`
does NOT originate in any repository file; it originates in the user-global
OpenCode config plugin declaration, recorded against DIA-260827-txq2 line 41 and
`knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit/ana-260831-6w4y-full-repository-four-lane-reaudit-report.md`
line 385.

**Slice 4 transfer record (this amendment):** the out-of-repo user-global
cleanup is REMOVED from this change and TRANSFERRED to DIA-260827-txq2
'inherited-obsolete-and-duplicate-plugins-from-base-omo-config', which already
owns that regression. DIA-260929-sjwm closes REPO-ONLY. Rationale: three
read-only probes falsified slice 4's premise - the `/workspace` bind source is a
single subdirectory
(`/dev/nvme0n1p6[/home/mimic/Documents/Coddding/poetry-platform]`), there is no
bind for `/home/dev/.config`, `/proc/self/mounts` shows no such bind, the
recorded host paths (`/home/mimic/...`, `/home/qualt/...`) do not exist
in-container, and `OPENCODE_CONFIG_DIR` resolves to the container overlay. No
lane reachable from the container can see or edit the host user-global config.
OQ1 is resolved; full detail in design.md "Slice 4 transfer record".

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
- **Out-of-repo user-global config (TRANSFERRED OUT):** slice 4 - removal of the
  user-global `opencode-snip@latest` plugin declaration and the orphaned host
  paths - is transferred to DIA-260827-txq2. This change does not edit any
  out-of-repo path; DIA-260929-sjwm closes repo-only.
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
the pinned `snip` install and the dormant deny rules. No host-side step is part
of this change (the out-of-repo slice is transferred to DIA-260827-txq2).

## Alternatives considered

- **Variant A - full live-surface removal (repo + out-of-repo global config in
  one change):** rejected/moved. Three read-only probes show no container lane
  can reach the host user-global config (design.md "Slice 4 transfer record"),
  and the startup warning is unconfirmed in poetry-dev. The out-of-repo surface
  is transferred to DIA-260827-txq2, which already owns that regression.
- **Variant B - repository traces only; transfer the global declaration to
  DIA-260827-txq2:** chosen. The repository cleanup is fully executable and
  verifiable in-container; the host edit is owned where it is reachable.
  Evidence: DIA-260827-txq2 line 41 and
  `knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit/ana-260831-6w4y-full-repository-four-lane-reaudit-report.md`
  line 385 record the global declaration as the source of the warning, and that
  regression is DIA-260827-txq2's.
- **Variant C - keep the four deny rules as a dormant guardrail (the DIA-092
  council 5/5 position):** rejected. The developer explicitly reversed that
  position in decision 3; once the binary is gone and the global declaration is
  transferred for removal the guard has no subject, and a rule that instructs
  "do NOT remove" against
  the developer's cleanup intent is itself a live trace. Evidence: Tier-1
  `docs/dev-infra-audit/tickets/DIA-092-snip-plugin-removal-s10.md` (council
  reversal, dormant-rule rationale); developer decision 3 (this dispatch).
- **Status-quo / do nothing:** rejected. It leaves a third-party binary in the
  image, a stale inventory claim, and a dormant deny guard with no subject.
  Evidence: Tier-1 live reads of `Dockerfile.dev:36`,
  `.opencode/opencode.jsonc:329-330`, `docs/dev-infra-audit/inventory.md:51`.

Chosen option: Variant B - because the repository traces are fully removable and
verifiable in-container, while the out-of-repo global declaration is unreachable
from this container and is already owned by DIA-260827-txq2.

## Ticket linkage

- **Governs:** DIA-260929-sjwm (this change).
- **Evidence refs:** DIA-260827-txq2 line 41;
  `knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit` line 385;
  `docs/dev-infra-audit/tickets/DIA-092-snip-plugin-removal-s10.md`.
- **Probe evidence (amendment):** design.md "Slice 4 transfer record"
  (read-only probes falsifying the delegated-lane mechanism).
- **Slice 4 transfer (amendment):** the out-of-repo global cleanup moves to
  DIA-260827-txq2
  'inherited-obsolete-and-duplicate-plugins-from-base-omo-config' (OQ1 resolved;
  DIA-260929-sjwm closes repo-only). Probe evidence: design.md "Slice 4 transfer
  record".
- **History preserved:** DIA-092, DIA-075, DIA-078, DIA-093 (CLOSED).
