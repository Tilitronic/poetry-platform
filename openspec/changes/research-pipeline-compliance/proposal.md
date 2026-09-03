# Proposal: research-pipeline-compliance

> **Status:** proposed
> **Scope:** dev-infra (scripts/, bats test scaffolding) + skill prompt (.opencode/skills/research-pipeline/SKILL.md). No application code touched.
> **Escalation:** none - change stays within existing module boundaries. Per AGENTS.md section 2.4 (dev-infra within existing boundaries -> @reviewer), no @architector dispatch is required.
> **Source tickets:** docs/dev-infra-audit/tickets/DIA-260820-dr0g.md (researcher agent deviates from 3-tier fetch chain, uses WebFetch/context7 instead of trafilatura/crawl4ai, creating non-persistent non-reproducible research without Tier-1 cache).
> **Research basis:** knowledge/res008-source-archival-fallbacks/ (validated 3-tier archival fallback chain); knowledge/res024-model-variant-fetch-tools/ (fetch-tool comparison, recommended 3-tier chain by URL class).

## Why

The researcher agent deviates from the research-pipeline skill's 3-tier fetch chain (Tier 1 npm registry JSON API -> Tier 2 trafilatura -> Tier 3 crawl4ai/crwl LAST-RESORT), instead using WebFetch/context7/gh_grep for source capture. This creates non-persistent, non-reproducible research without Tier-1 cache. DIA-260820-dr0g observed the researcher using WebFetch 5+ times, context7_resolve-library-id, and gh_grep_searchGitHub 7+ times, only switching to curl+trafilatura at the end. Root cause hypotheses: (a) skill instructions not clear enough, (b) agent tool preferences override skill, (c) no enforcement mechanism for 3-tier chain compliance. This change adds a hard artifact/manifest gate at Phase 2 verification plus explicit skill examples/deviation recording to close the enforcement gap.

## What Changes

- Add `scripts/validate-research-pipeline.sh` - standalone bash script that validates the researcher's Phase A source capture artifacts: checks `knowledge/res<id>-<topic>/sources/` directory exists and is non-empty, checks `.source-urls.txt` manifest exists and is well-formed, asserts every claimed source URL has a corresponding archived file in `sources/` OR is marked `[source not archived]` with a reason, accepts deviation records when fallback/deviation actually occurred.
- Exit code contract: exit 0 = valid evidence (sources/ + manifest present, well-formed, all claimed sources have archival evidence or are marked NOT ARCHIVED with reason); exit 1 = missing/malformed manifest or archive (including missing res directory, missing sources/, missing manifest, manifest lists URLs with no corresponding archives and no NOT ARCHIVED marker); exit 2 = validator infrastructure failure (I/O/parser/dependency - manifest not readable, jq not available, etc.).
- Integrate hard gate at Phase 2 verification: orchestrator runs validator after researcher returns; if exit 1, rejects return and re-dispatches with explicit instructions ("Phase 2 compliance gate failed: [specific failure]. You MUST complete Phase A source capture before returning findings. Every source URL must have a corresponding archived file in sources/ OR be marked [source not archived] with a reason in .source-urls.txt. If you cannot use the 3-tier chain, record the deviation in .source-urls.txt").
- Update `.opencode/skills/research-pipeline/SKILL.md` to add a "Deviation Recording" section with examples of correct vs incorrect manifest entries, warning against using WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND the deviation is recorded, and updating Phase 2 verification to reference the new validator script.
- Add `scripts/__tests__/validate-research-pipeline.bats` - bats unit tests with 7-case fixture matrix covering all exit codes (0=valid evidence, 1=missing/malformed, 2=infra failure).
- No tool-provenance ban/telemetry: res039 proved the sandbox can deny curl/trafilatura even where durable archives can be created through a documented fallback. The validator checks structural invariants (archives exist, deviations recorded), not which specific tool was used.
- Conspecter must not cite NOT ARCHIVED sources: enforced by conspecter skill instructions (not by this validator).

## Capabilities

### New Capabilities

None. This is dev-infra tooling (bash script + bats tests) + skill prompt update. No spec-level behavior changes.

### Modified Capabilities

None. No existing capabilities are modified.

**skip_specs: true** - this change is pure dev-infra tooling + skill prompt with no spec-level behavior changes.

## Impact

**Affected code:**

- `scripts/validate-research-pipeline.sh` (new) - research pipeline compliance validator
- `scripts/__tests__/validate-research-pipeline.bats` (new) - bats unit tests
- `.opencode/skills/research-pipeline/SKILL.md` (modified) - add deviation recording section + examples

**Dependencies:**

- Requires `jq` for manifest parsing (already validated by `check-host-jq.sh`)
- No new runtime dependencies

**Systems:**

- Orchestrator invokes validator during Phase 2 verification (live dispatch, not CI gate)
- Does NOT affect application code, APIs, or user-facing behavior
- Does NOT affect conspecter lane (conspecter already has Archive-Before-Claim policy; this change reinforces it)

## Design authority (.sdd/) reference

**Relevant .sdd/ documents:**

- `.sdd/dev-infra/architecture.md` - governs dev-infra scripts, bats test scaffolding

**No new architectural decisions required.** This change stays within existing module boundaries (dev-infra scripts + skill prompt). Per AGENTS.md section 3, the absence of a governing .sdd/ for `scripts/validate-research-pipeline.sh` is a documentation gap, but one this change does not fill (precedent: `openspec/changes/dev-infra-config-validators/proposal.md` section Design authority).

## Testing Decisions

**What makes a good test here:**
The artifact under test is a bash script that validates directory structure and manifest format. The prior art is `validate-agent-names.sh` and `validate-handoff.sh` (3-tier exit codes, stderr/stdout stream contract, collect-all discipline). Tests assert observable behavior (exit code, output content), not implementation details.

**Modules under test:**

| Module                                                    | Test type  | Gate              |
| --------------------------------------------------------- | ---------- | ----------------- |
| `scripts/validate-research-pipeline.sh` (new)             | bats unit  | `make test-shell` |
| `scripts/__tests__/validate-research-pipeline.bats` (new) | bats suite | `make test-shell` |

**Fixture matrix (7 cases):**

| #   | Case                                                                                          | Expected exit | Expected output                                         |
| --- | --------------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------- |
| 1   | Valid: sources/ + manifest present, all URLs archived                                         | 0             | stdout `ok:` lines, final summary                       |
| 2   | Valid with deviation: manifest records fallback (e.g., "webfetch because trafilatura denied") | 0             | stdout `ok:` lines including deviation                  |
| 3   | Valid with NOT ARCHIVED: manifest marks URL as `[source not archived]` with reason            | 0             | stdout `ok:` lines including NOT ARCHIVED marker        |
| 4   | Missing sources/ directory                                                                    | 1             | stderr `FAIL:` line "missing sources/ directory"        |
| 5   | Missing manifest (.source-urls.txt)                                                           | 1             | stderr `FAIL:` line "missing .source-urls.txt manifest" |
| 6   | Manifest lists URL with no corresponding archive and no NOT ARCHIVED marker                   | 1             | stderr `FAIL:` line naming the URL                      |
| 7   | res directory not found (evidence failure, not infra)                                         | 1             | stderr `FAIL:` line "res directory not found"           |

**Test risk and mitigation:**

- **Risk**: manifest format is ambiguous (what counts as "well-formed"?). **Mitigation**: validator documents exact manifest format (pipe-delimited: `URL | tool | archived-path-or-NOT-ARCHIVED | relevance/reliability`); bats tests cover valid + invalid formats.
- **Risk**: validator is too strict and rejects valid research. **Mitigation**: validator accepts NOT ARCHIVED markers with reasons; does not validate tool provenance; only checks structural invariants.

**Prior art in the codebase:**

- `scripts/validate-agent-names.sh` - 3-tier exit codes, stderr/stdout stream contract, collect-all discipline
- `scripts/validate-handoff.sh` - same pattern, env override for fixture trees
- `scripts/__tests__/validate-agent-names.bats` - env override pattern for fixture trees
- `.opencode/skills/research-pipeline/SKILL.md` - existing Phase 2 verification (lines 34-40), Archive-Before-Claim policy (lines 85-90)

## Rollback plan

**Rollback is trivial** because this change has no persistent-state impact:

1. `git revert <merge-commit>` - reverts all file changes
2. `make test-shell` - bats re-runs at pre-existing baseline
3. Skill changes are additive (new section + examples), so rollback removes the additions

No data migration is needed. The orchestrator's Phase 2 verification reverts to the pre-change behavior (check sources/.source-urls.txt exists, but no manifest well-formedness validation).

**Rollback risk:** very low. The change is a bounded dev-infra addition (one new script, one new bats suite, one skill prompt update) with no application-code impact and no persistent-state impact.

## Alternatives considered

- **Tool-provenance ban (Variant B)**: ban WebFetch/context7/gh_grep for source archival; require trafilatura/curl/crwl only - rejected because res039 proved sandbox can deny curl/trafilatura; durable archives can be created through documented fallback; ban would over-constrain (developer rejected, Q7)
- **Soft audit (Variant C)**: warn on chain violation but accept research - rejected because ticket states bypass creates "non-persistent, non-reproducible research"; soft audit lets broken research proceed to conspecter (developer rejected, Q7)
- **Makefile target**: wire validator into `make test-config` or standalone target - rejected because validator is invoked by orchestrator during live dispatch, not as CI gate; Makefile target is unnecessary overhead (developer rejected, Q10)
- **Inline orchestrator logic (no script)**: orchestrator directly checks sources/ + manifest - rejected because standalone script is reusable (orchestrator, developers, future CI wiring); follows existing validator pattern (developer rejected, Q10)
- **Status-quo / do nothing**: accept that researcher can bypass 3-tier chain without enforcement - rejected because P1 ticket explicitly requires enforcement (DIA-260820-dr0g)

**Chosen option:** Variant A (hard artifact/manifest gate) with standalone script - because it enforces archival evidence without over-constraining tool choice, is reusable across orchestrator/developer/CI contexts, and follows existing validator patterns (evidence: res008 validates 3-tier chain; res024 confirms trafilatura/crawl4ai trade-offs; developer rulings Q7-Q10).
