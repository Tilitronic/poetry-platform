---
ownership:
  substance: developer
  structure: AI
  interview_depth: compressed
  interview_reason: 'DIA-104 cross-boundary/cross-cutting/hard-to-reverse triggers; developer pre-resolved scope decisions as the authoritative compressed grill; the out-of-repo slice was later transferred to DIA-260827-txq2 (OQ1 resolved).'
campaign_ticket: DIA-260929-sjwm
---

## Context

See [proposal.md](proposal.md) for motivation. The live SNIP surface was
re-verified by direct file reads (not trusted from the prior recon):

- `Dockerfile.dev`: comment line 5; `ARG SNIP_VERSION=0.22.0` line 36;
  "snip/uv" comments lines 44 and 92; install block lines 128-135; "snip/uv
  installs" comment line 141; `SNIP_VERSION` listed in the trafilatura comment
  line 170; "node/snip/uv/mise" comment line 290.
- `.opencode/opencode.jsonc`: comment block lines 317-322 (including the
  "DO NOT remove these rules" line 322); coder denies lines 329-330;
  coder-escalated denies lines 435-436. The project plugin array (lines
  749-760) contains only `oh-my-opencode-slim@2.2.19`,
  `@dietrichgebert/ponytail`, and `envsitter-guard@0.0.4` - no snip entry, so
  no project plugin edit is needed.
- `.opencode/agents/coder-escalated.md` line 34:
  `bash: snip / snip * (deny)` in the runtime-permissions block.
- `docs/dev-infra-audit/inventory.md` line 51: `snip 0.22.0` in the pinned
  Dockerfile ARG list.
- `docs/dev-infra-audit-plan.md` line 47: `opencode-snip` named in the
  historical C5 global-plugin audit checklist (all items already `[x]`).

Out-of-repo (not under version control): the user-global OpenCode config
plugin array entry `opencode-snip@latest` and the orphaned user-home
`~/.config/snip/config.toml` plus the `snip` binary on PATH. This surface is
NOT edited by this change - slice 4 is transferred to DIA-260827-txq2 (see
"Slice 4 transfer record" below). DIA-260929-sjwm is repo-only.

### Slice 4 transfer record (out-of-repo global config, now out of scope)

Slice 4 - removal of the user-global `opencode-snip@latest` plugin declaration
and the orphaned `~/.config/snip/` home config plus `snip` binary - is REMOVED
from DIA-260929-sjwm and TRANSFERRED to DIA-260827-txq2
'inherited-obsolete-and-duplicate-plugins-from-base-omo-config', which already
owns that regression. DIA-260929-sjwm closes REPO-ONLY: no lane and no manual
step edits any host path under this change. OQ1 is resolved by this transfer.

Probe rationale (read-only probes, recorded basis). The `/workspace` bind source
is a single subdirectory
(`/dev/nvme0n1p6[/home/mimic/Documents/Coddding/poetry-platform]`), there is no
bind for `/home/dev/.config`, `/proc/self/mounts` shows no such bind, the
recorded host paths (`/home/mimic/...`, `/home/qualt/...`) do not exist
in-container, and `OPENCODE_CONFIG_DIR` resolves to the container overlay with
no `opencode.json(c)`. No lane reachable from this container can see or edit the
host user-global config, so this change cannot own that edit.

The startup warning `[snip] snip binary not found in PATH - plugin disabled` has
never been observed in poetry-dev; the recorded host-config observation and the
unconfirmed-warning evidence move with slice 4 to DIA-260827-txq2.

This change spans two AGENTS.md change classes: Docker/infra (section 2.4) and
OpenCode config (section 2.5). Both classes route through `@openspec-plan`
(this artifact set), then `@coder`; the config class additionally requires the
section 2.5 ai-specialist gate before the coder config dispatch and the
ai-auditor independent review afterwards.

Governing `.sdd/` documents (referenced, not overridden):

- `.sdd/dev-infra/architecture.md` ADR 11 (one dev-toolchain container +
  postgres) and ADR 14 (execution-context contract) govern `Dockerfile.dev`
  changes; the `snip` install block is a dev-image toolchain layer, removed
  within that boundary. No ADR change is required - this is not a topology or
  boundary decision.
- `.sdd/opencode-config/architecture.md` governs the OpenCode config surface
  (batch pattern, instance separation); the deny-rule removal is a permission
  value edit inside that boundary, not a new pattern. No `@architector`
  escalation is needed.
- Root `architecture.md` is not affected (no snip reference found).

## Goals / Non-Goals

**Goals:**

- Remove every live SNIP trace from the repository's live surface.
- Keep all historical SNIP records byte-identical.
- Prove absence with a repo token scan and prove integrity with
  `make test-config` and `make test-infra`.

**Non-Goals:**

- No change to `.opencode/CHANGELOG.yaml` / `.opencode/CHANGELOG.md`, CLOSED
  ticket docs, `knowledge/archive/**`, `.opencode/memory/lessons.md`,
  `.opencode/memory/failures.md`, the ticket README index, learnings files, or
  point-in-time analysis reports. These are historical record.
- No rewrite of `doom_loop: deny` or any other permission rule - only the
  snip-specific pair is removed.
- No new validator, no new test harness, no new `.sdd/` document.
- No application code, package manifest, lockfile, Makefile, or script change.
- No commit or push of any artifact as part of this spec-authoring task.

## Decisions

### D1: Delete snip lines; do not neutralize or comment them out

**Choice:** physically delete the Dockerfile install block, the `ARG
SNIP_VERSION` pin, the four deny rules, the DORMANT comment block, the
coder-escalated doc line, and the live comments at all eight Dockerfile sites.
Comments that merely cite snip as a comparison in unrelated installs (lines 44,
92, 141, 170, 290) are reworded to name only the surviving pattern (for example
"the pinned SHA256-verified binary-install pattern used by uv/tini") so no
"snip" token remains as a live reference.

**Rationale:** the developer directed "nothing must remain" and "nothing must
interfere or generate errors". A commented-out install or a renamed variable
would remain a trace; deletion is the only complete-cleanup form. Reworded
comments keep the surviving rationale (why uv/tini are SHA256-verified) without
naming a removed tool.

**Alternatives considered:** comment-out the lines (rejected: still a live
trace and can be re-enabled); rename `SNIP_VERSION`/`SNIP_ARCH` (rejected: the
install still exists).

### D2: Remove the dormant deny rules (reverses the DIA-092 council position)

**Choice:** delete the `snip` / `snip *` deny rules and their "do NOT remove
these rules" comment from both the `coder` and `coder-escalated` permission
blocks.

**Rationale:** per developer decision 3, the guard has no subject once the
binary is gone and the global declaration is transferred for removal to
DIA-260827-txq2. The DIA-092 council-5/5 dormancy rationale (zero-cost
hallucination guardrail) applied while snip could still be re-primed by a global
plugin; that priming source is owned by DIA-260827-txq2. The `doom_loop: deny`
rule is unrelated and stays.

**Alternatives considered:** keep the rules dormant (rejected: developer
decision 3; a comment that resists removal is itself a live trace and
contradicts the cleanup); keep the rules but drop only the comment (rejected:
half-measure leaves live deny tokens).

### D3: No delta spec (`skip_specs: true`)

**Choice:** mark the change `skip_specs: true`; produce proposal + design +
tasks only.

**Rationale:** there is no existing `openspec/specs/` capability for snip, and
removing dead tooling plus a dormant guard does not define or change an
observable behavior contract. The proposal is explicit that no capability is
added or modified. Matches the `dia-260827-docker-omo-pin-drift` precedent
(`skip_specs: true` for a config-value change).

### D4: Two-class routing - section 2.5 ai-specialist gate before the config coder dispatch, ai-auditor review after

**Choice:** the OpenCode config portion (opencode.jsonc + coder-escalated.md)
is routed through the AGENTS.md section 2.5 chain: (1) ai-specialist read-only
gate/dispatch BEFORE any `@coder` config dispatch, with findings registered in
`.opencode/learnings/external-patterns/`; (2) developer review of the gate
findings; (3) `@coder` applies the approved edit; (4) `make test-config` +
JSONC validity + restart smoke; (5) `@ai-auditor` independent review; (6) the
CHANGELOG entry is appended via `scripts/changelog-add`. The Docker/infra
portion follows section 2.4 (same spec, `@coder`, `make test-infra`,
`@reviewer`, memory-manager).

**Rationale:** AGENTS.md section 2.5 requires the ai-specialist gate for
`.opencode/*` config changes, and ai-auditor is the independent reviewer for
config changes (dev-infra uses `@reviewer`). Routing both classes under one
change does not merge their review matrices.

**Alternatives considered:** treat the deny-rule deletion as dev-infra only
(rejected: `.opencode/opencode.jsonc` and agent docs are the opencode-config
class); skip the ai-specialist gate because the edit is a deletion (rejected:
section 2.5 has no deletion exemption).

### D5: Out-of-repo global cleanup is transferred to DIA-260827-txq2; this change is repo-only

**Choice:** slice 4 - the out-of-repo user-global OpenCode config cleanup - is
REMOVED from DIA-260929-sjwm and transferred to DIA-260827-txq2
'inherited-obsolete-and-duplicate-plugins-from-base-omo-config', which already
owns the inherited/duplicate global-plugin regression. DIA-260929-sjwm closes
REPO-ONLY: no lane and no manual step edits any host path under this change.

**Rationale:** three read-only probes falsified slice 4's premise. The
`/workspace` bind source is a single subdirectory
(`/dev/nvme0n1p6[/home/mimic/Documents/Coddding/poetry-platform]`), there is no
bind for `/home/dev/.config`, `/proc/self/mounts` shows no such bind, the
recorded host paths (`/home/mimic/...`, `/home/qualt/...`) do not exist
in-container, and `OPENCODE_CONFIG_DIR` resolves to the container overlay. No
lane reachable from the container can see or edit the host user-global config,
so a repo-scoped change cannot own or verify that edit.

**Alternatives considered:** keep slice 4 as a manual developer host action in
this change (rejected: OQ1 resolved against it - the change cannot verify a host
edit and the warning is unconfirmed in poetry-dev); delegate a lane holding
`external_directory` permission (rejected: FALSIFIED by the probe results - it
would edit a wrong overlay path or find nothing).

## Seams

**Test/verification seams (all pre-existing or trivial):**

- **`make test-config`** - config parse + JSONC validity + agent-name lockstep +
  observer-dedupe + EBDV/grilling validators. Proves `.opencode/opencode.jsonc`
  and `.opencode/agents/coder-escalated.md` remain valid after the deny/doc
  removal.
- **`make test-infra`** - builds the dev image and runs the docker smoke; proves
  `Dockerfile.dev` still builds without the snip layer and the container still
  boots.
- **Repo live-token scan** - a grep for the live surface (excluding the
  preserved historical paths) returns zero live hits. The scan is evidence, not
  a new committed validator.

**Public boundaries:**

- `Dockerfile.dev` image build contract (dev toolchain layer).
- `.opencode/opencode.jsonc` permission object + project plugin array (config
  surface).

**No new production module boundaries.** No `.sdd/` architecture document needs
updating.

## Test strategy

This is a removal change; the correct verification is absence plus regression of
the existing gates, not new tests.

1. **Absence (repo live surface):** after the edits, a scoped scan for `snip`
   over the live files (`Dockerfile.dev`, `.opencode/opencode.jsonc`,
   `.opencode/agents/coder-escalated.md`, `docs/dev-infra-audit/inventory.md`,
   `docs/dev-infra-audit-plan.md`) returns zero live-tooling hits. False
   positives (`snippet`, `totalSnippets`, docs scrape "snippet" prose) are
   documented and excluded by path, so the scan is not confused with them.
2. **Config validity:** `make test-config` exits 0 (JSONC parse, agent-name
   lockstep, observer-dedupe, validators).
3. **Image regression:** `make test-infra` exits 0 (image builds, smoke passes,
   `snip` is absent from the image: `command -v snip` fails inside the
   container).
4. **Dockerfile hygiene:** `docker compose config --quiet` still succeeds, and
   the Dockerfile contains no `SNIP_VERSION`, no `SNIP_ARCH`, and no
   `edouard-claude/snip` URL.
5. **Historical preservation:** `git status` / `git diff` shows the preserved
   paths (CHANGELOG, CLOSED tickets, `knowledge/archive/**`, memory files) are
   unmodified.
6. **Spec gate:** `openspec validate dia-260929-sjwm-remove-live-snip-traces`
   exits 0.
7. **Independent review:** `@ai-auditor` (config portion) and `@reviewer`
   (dev-infra portion) two-axis review; no Critical findings; diff scope
   matches this design.

## Rollback plan

- **In-repo edits:** one Git-tracked commit; `git revert` of that commit
  restores the `snip` install block, the `ARG SNIP_VERSION` pin, the four deny
  rules, the DORMANT comment, the coder-escalated doc line, the reworded
  comments, and `docs/dev-infra-audit/inventory.md`. No data migration, no
  side effects.
- **Image rollback:** rebuilding the image from the reverted Dockerfile
  restores `snip` in the container. No image-layer migration is involved.

## Risks / Trade-offs

- **Risk:** a model re-invents the `snip` prefix after the deny rules are gone.
  -> **Mitigation:** developer decision 3 accepts this; the priming source (the
  user-global plugin declaration) is owned by DIA-260827-txq2, and
  `doom_loop: deny` still halts the identical-command loop class. Accepted
  residual risk.
- **Risk:** the repo scan misses a live reference hidden in an unexpected file
  or trips on "snippet" false positives.
  -> **Mitigation:** scan the whole repo, then classify each hit as live /
  historical / false-positive by path; the design records the known false
  positives.
- **Trade-off:** removing the dormant guardrail lowers defense-in-depth for a
  hypothetical future `snip` hallucination. Acceptable per developer decision 3.

## Migration Plan

1. **In-repo:** apply the Dockerfile edits (slice 1) and, after the section 2.5
   ai-specialist gate, the config/agent-doc edits (slice 2).
2. **Docs:** update `docs/dev-infra-audit/inventory.md`; record the
   `docs/dev-infra-audit-plan.md` disposition (slice 3).
3. **Validate + review + register:** `make test-config`, `make test-infra`,
   `openspec validate`, ai-auditor + reviewer, then `scripts/changelog-add`
   (slice 5).
4. **Rollback:** `git revert` the repo commit and rebuild the dev image as
   needed. No host-side step is part of this change.

## Open Questions

None. OQ1 is RESOLVED (developer-decided).

### OQ1 (RESOLVED): Does slice 4 (out-of-repo global cleanup) belong in this change?

**Status:** RESOLVED - slice 4 is REMOVED from this change and transferred to
DIA-260827-txq2 'inherited-obsolete-and-duplicate-plugins-from-base-omo-config',
which already owns the inherited/duplicate global-plugin regression.
DIA-260929-sjwm closes repo-only. Rationale: no lane reachable from the container
can see or edit the host user-global config (probe evidence in Context), and the
startup warning has never been observed in poetry-dev.

The scope-boundary treatment of point-in-time `knowledge/ana*` / `res*` reports
and of `docs/dev-infra-audit-plan.md` (historical vs live) remains resolved in
favor of preservation: only `docs/dev-infra-audit/inventory.md` is a live-state
document and is updated; every dated analysis/research/planning record is kept
byte-identical.

## DIA-104 gate check (recorded)

- **gate_state:** grilled
- **gate_triggers:** cross-boundary, cross-cutting, hard-to-reverse
  - cross-boundary: spans the dev-infra class (Dockerfile) and the
    opencode-config class (opencode.jsonc + agent doc).
  - cross-cutting: the removal crosses the image build, the permission config,
    agent policy docs, and live documentation/inventory.
  - hard-to-reverse: the change reverses the DIA-092 council dormancy decision
    and removes an image-layer install; a partial revert would leave the deny
    guard and the removed binary inconsistent.
- **gate_waivers:** none apply (not a hotfix; not a pure no-behavior-change
  refactor; not a disposable spike; not a clean increment to a module whose
  grill already covers these new trade-offs, because this change reverses the
  DIA-092 council dormancy decision).
- **gate_override:** "" (none)
- **Grill basis:** the developer pre-resolved scope decisions (historical-record
  preservation, dormant deny removal) plus the later OQ1 decision (slice 4
  transferred to DIA-260827-txq2) constitute the compressed grill transcript for
  this change; the spec is synthesized from that transcript only.
