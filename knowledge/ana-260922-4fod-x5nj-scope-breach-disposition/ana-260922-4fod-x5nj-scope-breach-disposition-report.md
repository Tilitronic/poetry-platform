# ana-260922-4fod: Disposition of DIA-260821-x5nj "unified Docker development runtime plan" (scope-breach criterion g)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: docs/dev-infra-audit/tickets/DIA-260821-x5nj-unified-docker-development-runtime-plan-for-fedora-linux-and-wsl-developers.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket: DIA-260821-x5nj. Analysis date: 2026-09-22.
Method applied: **OODA loop** (Observe the real files, Orient against the
ADR/ticket authority hierarchy, Decide among variants, Act = ledger proposal)
with a **MECE decomposition** of the compose-surface inventory. All facts
below were re-derived from the repository, not from prior reports.

---

## 1. OBSERVE - compose inventory and selection mechanism (crux of V1 vs V2)

Five compose files exist on disk today: one base + four overlays.

| File | Content (non-comment body) | Selected by | State |
| --- | --- | --- | --- |
| `docker-compose.yml` | base: dev + postgres, volumes/ports/env/secrets single source | always first in merge | live |
| `docker-compose.podman.yml` | `userns_mode: keep-id` + `security_opt: [label=disable]` | `scripts/compose-env.sh:71` when engine=podman | live, ADR-11 sanctioned |
| `docker-compose.rootless-docker.yml` | `user: "0:0"` | `scripts/compose-env.sh:72` when engine=docker | live, ADR-11 sanctioned |
| `docker-compose.wsl.yml` | `services.dev: {}` + commented-out memory cap (functional no-op) | `scripts/compose-env.sh:82-84` when OS=wsl | live, ADR-11 sanctioned |
| `docker-compose.fedora.yml` | body byte-identical to podman overlay (see 2.) | **nothing** | DEAD FILE |

Selection mechanism (single source of truth, no docker/podman invocation at
compute time):

```
scripts/opencode-dev:46  ->  scripts/compose-env.sh  ->  COMPOSE_FILE (Makefile + launcher)
                                |
        engine=podman  -> docker-compose.podman.yml
        engine=docker  -> docker-compose.rootless-docker.yml
        os=wsl (extra) -> docker-compose.wsl.yml
        (docker-compose.fedora.yml appears in NO branch)
```

Full-repo grep for `docker-compose.fedora`: zero references in
`scripts/compose-env.sh`, `scripts/opencode-dev`, `Makefile`, `dev-entrypoint.sh`,
or any executable. Its only non-doc reference is a comment in
`scripts/__tests__/compose-overrides.bats:19`, which itself labels it
"the OBSOLETE OS-only docker-compose.fedora.yml".

Provenance: one x5nj-era commit `362a9eb` ("feat(DIA-260821-x5nj): unified
docker dev runtime overrides", +56 lines) created ALL FOUR overlays at once;
`3a8b68e` added `scripts/check-secrets-ownership.sh` + bats. The fedora
overlay was obsolete on arrival - the same commit introduced its replacement
(podman.yml) and no wiring ever selected it.

## 2. Redundancy analysis (are 4 overlays genuine necessity?)

- **fedora vs podman: strict functional duplicate.** With comment lines
  stripped, both bodies hash to md5 `8f4ee13eaa1b44b337e148ad5b00c9c7`; the
  raw files differ only in header comment text. Same keys (`userns_mode`,
  `security_opt`), same values. Not two engine cases - one case, two files.
- **podman vs rootless-docker: genuinely distinct.** Podman needs
  `userns_mode: keep-id` + SELinux `label=disable`; rootless Docker needs
  `user: "0:0"` (res040 sections 1/2/4, cited at tasks.md:150-164). These
  cannot be merged without breaking one engine.
- **wsl: sanctioned no-op placeholder.** ADR 11 explicitly contemplates "an
  optional WSL overlay" (`.sdd/dev-infra/architecture.md:98`); compose-env.sh
  appends it conditionally. Empty body costs ~0 maintenance; deleting it would
  require editing the selection script for no gain. In-design, not sprawl.

**Verdict:** the live surface is **3 overlays = exactly what ADR 11
prescribes** (one per engine + one optional OS). The 4th file is not a design
excess; it is a dead artifact of the same commit, already queued for deletion.

## 3. ORIENT - ADR 11 conformance and criterion (g)

ADR 11 (Accepted, committed, `.sdd/dev-infra/architecture.md:94-104`) states
engine differences "are expressed only as compose overlays selected by
scripts/compose-env.sh; OS differences as an optional WSL overlay"
(line 98). Line 96 records that ADR 11 "refines DIA-260821-x5nj" - the
accepted architecture authority formally adopted the overlay mechanism that
the x5nj-era commits shipped. The scope breach of criterion (g)
(ticket lines 88-89, "No Dockerfile, compose, or config file was modified by
this ticket (planning-only)") is therefore a **label-vs-delivery mismatch
whose deliverables were later ratified by a higher authority**, not design
drift. Every surviving overlay traces to the change's own tasks.md (see 4.).

## 4. tasks.md coverage (does V1/V2 duplicate planned work?)

`openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/tasks.md`:

| Question | Finding | Evidence |
| --- | --- | --- |
| Does tasks.md plan the overlay work? | YES, exactly 3 overlays: T2.1 podman (line 150), T2.2 rootless-docker (line 158), T2.3 wsl (line 166). It does NOT plan docker-compose.fedora.yml anywhere. | tasks.md:150-172 |
| Does tasks.md plan the retirement slices PHASE 3 executes? | YES for the legacy runtime: Slice 9 "Retirement Preparation" T8.6 "Retire tools/opencode-docker/ (DIA-260824-8k62)" (line 500), gated by T8.1-T8.5 acceptance/countdown/audits (lines 461-498). fedora.yml deletion is NOT in x5nj tasks.md - it is tracked in **DIA-260922-cp0m** "ACCEPTED FOLLOW-UPS" item 1 (line 106) and "REMAINING PHASES" item 2 (line 140): "Retire tools/opencode-docker + delete docker-compose.fedora.yml + drop test-opencode-docker from test-shell". | tasks.md:450-506; cp0m:106,140 |
| Checkbox state vs reality | **All 79 boxes are unchecked**, yet T1.1 (opencode-dev exists), T2.1-T2.3 (overlays exist, commit 362a9eb), T7.0a/T7.0c (check-secrets-ownership.sh + bats, commit 3a8b68e) are implemented, and PHASE 1 of the follow-on work is committed (07c0513, ADR-11 implementation status at architecture.md:102-104). The checkboxes are stale bookkeeping, not open work; treat as a known tracking-hygiene note, owned by whichever lane next touches the change dir. | tasks.md:11-506; architecture.md:102-104 |

Consequence: **V2 would open a ticket for work that is already ticketed**
(cp0m REMAINING PHASES 2), and **V3's "formally satisfy (g)" retro-documentation
would duplicate the ADR 11 record that already exists**. The retirement and
the dedupe both have a home; x5nj does not need a new one.

## 5. DECIDE - variant comparison

| Criterion | V1 Close, (g) superseded by ADR 11 | V2 Close + new sprawl ticket | V3 Keep open, satisfy/revert (g) | V1+ (V1 with explicit cp0m cross-ref) |
| --- | --- | --- | --- | --- |
| Evidence conformance | TRUE: live surface = 3 = ADR 11 design; dup already targeted for deletion (cp0m:140) | FALSE PREMISE: "4 overlays exceed design" - only 3 are live; 4th is dead and already ticketed | PARTIAL: honors gate wording but ignores that ADR 11 ratified the artifacts | TRUE, strictly stronger paper trail than V1 |
| Reliable+deterministic infra | Unblocks 8k62 -> retirement proceeds -> less drift | No effect on infra; ticket noise | Keeps infra WORSE: legacy runtime + dup overlay persist behind the block | Unblocks 8k62 |
| Low-maintenance | One less open ticket, zero new artifacts | Adds a ticket whose scope is a subset of cp0m (duplicate tracker = maintenance cost) | Open ticket + retro-doc ceremony or a revert diff | One less open ticket |
| Spec-first / ownership | Breach is recorded, not hidden; disposition lands in the Fix block, reviewable | Same close, plus ownership of sprawl lands on a NEW owner instead of cp0m's existing owner | Pretends planning-only gate still has teeth after the authority changed | Breach + supersession + deletion path all cross-linked |
| Effort | Ledger edit only (~5 min) | V1 + new ticket authoring (~20 min) | Retro-doc (~1 h) or revert of ADR-conformant infra (harmful) | V1 + 2 lines of cross-refs (~10 min) |
| Reversibility | High: closing a ticket is trivially reopened, and (g)'s supersession note keeps the audit trail | High | High (cost is the delay itself) | High |

## 6. RECOMMENDATION

**V1, executed with the V1+ cross-references.** No new ticket.

Because: the only factual basis distinguishing V2/V3 from V1 - that the repo
carries 4 ADR-exceeding overlays whose scope breach x5nj must still answer
for - is disproven by the files themselves: the live overlay set is exactly
the 3 ADR 11 prescribes (compose-env.sh:70-84 selects nothing else), the 4th
(docker-compose.fedora.yml) is a comment-only duplicate of the podman overlay
that no script, Makefile, or test selects, and its deletion is already an
accepted, phase-scoped deliverable of DIA-260922-cp0m (lines 106, 140). A
planning-only ticket whose chosen direction was subsequently ratified by an
Accepted ADR has no residual gate function left; keeping it open (V3) or
ticketing already-ticketed work (V2) converts a closed decision into open
bookkeeping - the opposite of the project's low-maintenance value.

## 7. Ledger actions implied (orchestrator executes ONLY after developer disposition - analyzer changed nothing)

1. **DIA-260821-x5nj**: status `OPEN` -> closed. In its Fix/Update block record:
   criterion (g) (ticket lines 88-89) SUPERSEDED by Accepted ADR 11
   (`.sdd/dev-infra/architecture.md:94-104`), which adopted the overlay
   mechanism; the x5nj-era commits 362a9eb/3a8b68e match this change's own
   tasks.md slices 2 and 7; the single surplus artifact
   (docker-compose.fedora.yml, unselected dup) is deleted under
   DIA-260922-cp0m REMAINING PHASES item 2 (cp0m line 140).
2. **DIA-260824-8k62**: frontmatter `blocked_by: [DIA-260821-x5nj]` (8k62:10)
   -> remove that edge; line 62 of 8k62 states the edge is "retained until
   that disposition lands" - this report is the disposition, so 8k62 becomes
   unblocked from x5nj (its other gates, e.g. the T8.1-T8.5 acceptance chain
   now owned by cp0m phases, still apply as that ticket's text directs).
   Then run `scripts/tickets rollup` to refresh the README index.
3. **DIA-260922-cp0m**: no status/edge change; optionally add a cross-ref line
   noting x5nj's closure routes criterion-(g) residue to its PHASES 2 item.
4. **No new ticket** (V2 rejected on evidence).

## 8. Caveats / not analyzed

- Per dispatch, criteria (a)-(f) satisfaction was taken as verified (lane
  cod-2); this report spot-checked (a),(c),(d),(e) pointers only where cited.
- WSL overlay being a no-op stub is flagged for awareness only; ADR 11 names
  it, so it is not sprawl. If a future phase wants to fold it, that is an
  ADR-level change, not a ticket-level cleanup.
- Stale tasks.md checkboxes (all unchecked despite shipped slices 1-2, 7a) are
  a tracking-hygiene debt of the change dir; suggest the lane executing cp0m
  PHASES 2 tick them as part of that diff.

## Appendix: evidence index

| Claim | Source |
| --- | --- |
| planning-only MUST NOT clause | ticket lines 71-73 |
| criterion (g) text | ticket lines 88-89 |
| ADR 11 overlay mandate | .sdd/dev-infra/architecture.md:98; status Accepted + x5nj refinement :94-96 |
| engine->file mapping | scripts/compose-env.sh:70-78; wsl append :81-84; delegation from opencode-dev :46 |
| fedora==podman body dup | `diff <(grep -v '^#' ...)` empty; md5 8f4ee13eaa1b44b337e148ad5b00c9c7 both |
| fedora.yml unselected + OBSOLETE label | grep (no script/Makefile hits); compose-overrides.bats:19 |
| 4 overlays created together | git show --stat 362a9eb |
| fedora.yml deletion already planned | cp0m lines 106, 140 |
| 8k62 edge held pending this report | 8k62 line 62 |
| retirement slices exist in tasks.md | tasks.md:450-506 (T8.1-T8.6) |
