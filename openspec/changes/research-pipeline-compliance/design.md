# Design: research-pipeline-compliance

> **Proposal:** `openspec/changes/research-pipeline-compliance/proposal.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-260820-dr0g.md` (researcher agent deviates from 3-tier fetch chain).
> **Scope:** implementation design only - no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; routing is AGENTS.md section 2.4 (dev-infra -> @reviewer).

## Context

See proposal.md - Why. The researcher agent deviates from the 3-tier fetch chain, creating non-persistent non-reproducible research. The research-pipeline skill already documents the 3-tier chain (lines 19-22 of SKILL.md), Phase 2 verification (lines 34-40), and Archive-Before-Claim policy (lines 85-90). The gap is enforcement: no validator checks that the researcher actually archived sources before returning findings.

**Current state:**

- research-pipeline skill documents 3-tier chain (registry JSON API -> trafilatura -> crawl4ai/crwl)
- Phase 2 verification checks `sources/.source-urls.txt` exists (lines 34-40)
- No validator checks manifest well-formedness or archival evidence
- Researcher can bypass chain without detection

**Constraints:**

- Must not over-constrain tool choice (res039 proved sandbox can deny curl/trafilatura)
- Must accept documented deviations (fallback/deviation recorded in manifest)
- Must reject missing archival evidence (hard gate at Phase 2)
- Must be invokable by orchestrator during live dispatch (not CI gate)

## Goals / Non-Goals

**Goals:**

- Validate sources/ directory exists and is non-empty
- Validate .source-urls.txt manifest exists and is well-formed
- Assert every claimed source URL has archival evidence (archived file OR NOT ARCHIVED marker with reason)
- Accept deviation records when fallback/deviation actually occurred
- Provide clear failure messages for re-dispatch

**Non-Goals:**

- Tool-provenance ban (no telemetry on which tool was used)
- Makefile target (validator is invoked by orchestrator, not CI)
- Conspecter enforcement (conspecter already has Archive-Before-Claim policy; this change reinforces it via skill prompt, not validator)
- Validating relevance/reliability ratings (subjective; out of scope)

## Decisions

### Decision 1: Validator scope

**Choice:** Structural invariants only (sources/ exists, manifest exists, manifest is well-formed, every URL has archival evidence or NOT ARCHIVED marker). No tool-provenance validation.

**Rationale:** res039 proved the sandbox can deny curl/trafilatura even where durable archives can be created through a documented fallback. Banning specific tools would over-constrain the researcher. What matters is that archives exist and deviations are recorded, not which tool was used.

**Alternatives considered:**

- Tool-provenance ban (Variant B) - rejected: over-constrains, res039 proved fallback is valid (Q7)
- Relevance/reliability validation - rejected: subjective, out of scope

### Decision 2: Exit code contract

**Choice:** Exit 0 = valid evidence; exit 1 = missing/malformed manifest or archive (including missing res directory); exit 2 = validator infrastructure failure (I/O/parser/dependency).

**Rationale:** Missing res directory is an evidence failure (the researcher did not create the expected artifacts), not an infrastructure failure. Exit 1 signals "researcher return is broken, re-dispatch". Exit 2 signals "validator environment is broken, halt/escalate".

**Correction from interview:** Developer clarified that missing res directory is exit 1 (evidence failure), not exit 2 (Q8 correction).

**Alternatives considered:**

- Missing res directory = exit 2 - rejected: conflates evidence failure with infra failure (developer correction, Q8)

### Decision 3: Manifest format

**Choice:** Pipe-delimited format: `URL | tool | archived-path-or-NOT-ARCHIVED | relevance/reliability`

**Rationale:** Simple, parseable with bash/awk/jq, human-readable. Matches the existing `.source-urls.txt` format used in research conspects (res008, res024).

**Examples:**

```
# Correct manifest entry (3-tier chain followed):
https://example.com | trafilatura | sources/example.md | High/High

# Correct manifest entry (deviation recorded):
https://example.com | webfetch (trafilatura denied by sandbox) | sources/example.md | High/High

# Correct manifest entry (source not archived):
https://example.com | trafilatura+curl+crwl all failed | [source not archived] | High/High

# INCORRECT (missing archival evidence):
https://example.com | trafilatura | High/High
```

**Alternatives considered:**

- JSON format - rejected: harder to read/write manually, overkill for simple manifest
- Free-form markdown - rejected: hard to parse, ambiguous

### Decision 4: Integration point

**Choice:** Orchestrator invokes validator during Phase 2 verification (skill lines 34-40). No Makefile target.

**Rationale:** Validator is invoked by orchestrator during live dispatch, not as CI gate. A Makefile target is unnecessary overhead. The standalone script is reusable: orchestrator can call it, developers can call it manually, and it can be wired into `make test-config` later if needed.

**Alternatives considered:**

- Makefile target - rejected: validator is invoked during live dispatch, not CI (Q10)
- Inline orchestrator logic - rejected: standalone script is reusable, follows existing validator pattern (Q10)

### Decision 5: Re-dispatch flow

**Choice:** If validator exits 1, orchestrator rejects researcher return and re-dispatches with explicit instructions:

- "Phase 2 compliance gate failed: [specific failure from validator output]"
- "You MUST complete Phase A source capture before returning findings"
- "Every source URL must have a corresponding archived file in sources/ OR be marked [source not archived] with a reason in .source-urls.txt"
- "If you cannot use the 3-tier chain (e.g., sandbox denies curl/trafilatura), record the deviation in .source-urls.txt"

If validator exits 2, orchestrator halts and escalates to developer (validator environment is broken).

**Rationale:** Clear failure messages enable targeted re-dispatch. Exit 2 escalation prevents infinite re-dispatch loops when the validator itself is broken.

**Alternatives considered:**

- Soft audit (warn but accept) - rejected: ticket states bypass creates non-persistent research; soft audit lets broken research proceed (Q7)
- Silent re-dispatch (no failure message) - rejected: researcher needs to know what went wrong

### Decision 6: Skill prompt strengthening

**Choice:** Update `.opencode/skills/research-pipeline/SKILL.md` to add:

1. "Deviation Recording" section with examples of correct vs incorrect manifest entries
2. Warning: "DO NOT use WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND you record the deviation in .source-urls.txt"
3. Update Phase 2 verification to reference the new validator script

**Rationale:** Addresses root cause hypothesis (a) "skill instructions not clear enough". Explicit examples reduce ambiguity. Warning against tool bypass closes root cause hypothesis (b) "agent tool preferences override skill".

**Alternatives considered:**

- No skill update (validator only) - rejected: does not address root cause (a); researcher may not know deviation recording is required

## Risks / Trade-offs

**Risk:** Manifest format is ambiguous (what counts as "well-formed"?).
**Mitigation:** Validator documents exact format (pipe-delimited with 4 fields). bats tests cover valid + invalid formats. Coder lane implements strict parsing (exactly 4 pipe-delimited fields per line).

**Risk:** Validator is too strict and rejects valid research.
**Mitigation:** Validator accepts NOT ARCHIVED markers with reasons. Does not validate tool provenance. Only checks structural invariants. bats tests include "valid with deviation" and "valid with NOT ARCHIVED" cases.

**Risk:** Researcher does not understand deviation recording requirements.
**Mitigation:** Skill prompt includes explicit examples. Re-dispatch flow includes concrete failure messages. Developer can review skill prompt during implementation.

**Risk:** Validator is not invoked consistently (orchestrator skips Phase 2 verification).
**Mitigation:** Skill documents Phase 2 verification as HARD GATE. Orchestrator is trained to invoke validator. Future: wire validator into `make test-config` for CI enforcement (out of scope for this change).

**Trade-off:** No tool-provenance validation means researcher can use any tool (WebFetch, context7, etc.) as long as archives exist.
**Acceptance:** res039 proved this is acceptable. What matters is archival evidence, not tool choice. Deviation recording provides audit trail.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                      | What it is                                                               | Test location                                                                                                   | Test type                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **S1 - `scripts/validate-research-pipeline.sh`**          | Research pipeline compliance validator (sources/ + manifest validation). | `scripts/__tests__/validate-research-pipeline.bats` (new suite, `RESEARCH_DIR` env override for fixture trees). | Behavioral: exit code + stderr/stdout content per 7-case fixture matrix.     |
| **S2 - `bash -n` syntax-check loop in `bats-wrapper.sh`** | New script passes `bash -n` syntax check on every `make test-shell` run. | `scripts/__tests__/bats-wrapper.sh` (modified - added entry).                                                   | Implicit: `bash -n` runs in `make test-shell`; syntax errors fail the build. |
| **S3 - `.opencode/skills/research-pipeline/SKILL.md`**    | Skill prompt update (deviation recording section + examples).            | Visual review (no automated test).                                                                              | n/a                                                                          |

### New seams vs. existing seams

- **S1 is a new top-level script but reuses the existing bats harness** (`bats-wrapper.sh`, `test-helper.bash`). No new harness infrastructure needed.
- **S2 extends the existing `bash -n` loop** (no new seam).
- **S3 is a skill prompt update** (no automated test; visual review during implementation).

### Testability env seams

- **`RESEARCH_DIR` env override** for `validate-research-pipeline.sh` - points the validator at a temp fixture tree for bats tests. Same shape as `AGENTS_ROOT` in `validate-agent-names.sh`.
- **First positional argument** for `validate-research-pipeline.sh` - the res directory path (e.g., `knowledge/res008-source-archival-fallbacks/`). bats tests pass temp-fixture paths via this argument.

## Implementation approach

### Script structure (`scripts/validate-research-pipeline.sh`)

1. **Input validation:**
   - Check first positional argument (res directory path) is provided
   - If not provided, exit 2 with "usage: validate-research-pipeline.sh <res-directory>"
   - Check res directory exists
   - If not found, exit 1 with "FAIL: res directory not found: <path>"
   - Check `command -v jq` (already validated by `check-host-jq.sh`)
   - If not found, exit 2 with "unsupported: jq not found"

2. **Sources directory validation:**
   - Check `sources/` subdirectory exists
   - If not found, exit 1 with "FAIL: missing sources/ directory"
   - Check `sources/` is non-empty (at least one file)
   - If empty, exit 1 with "FAIL: sources/ directory is empty"

3. **Manifest validation:**
   - Check `.source-urls.txt` manifest exists in res directory
   - If not found, exit 1 with "FAIL: missing .source-urls.txt manifest"
   - Parse manifest with jq/awk (pipe-delimited format)
   - For each line:
     - Extract URL, tool, archived-path-or-NOT-ARCHIVED, relevance/reliability
     - If archived-path-or-NOT-ARCHIVED is `[source not archived]`, check reason is provided (4th field non-empty)
     - Otherwise, check archived file exists in `sources/` directory
     - If file does not exist and not marked NOT ARCHIVED, exit 1 with "FAIL: URL <url> has no corresponding archive"
   - If all lines pass, continue

4. **Summary:**
   - Count total URLs, archived URLs, NOT ARCHIVED URLs, deviations
   - Exit 0 with "ok: N URLs validated (M archived, K not archived, J deviations recorded)"

### Exit code contract

| Exit code | Trigger                                                                                                                                                                                    | Category                                      |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------- |
| 0         | Valid evidence (sources/ + manifest present, well-formed, all claimed sources have archival evidence or are marked NOT ARCHIVED with reason)                                               | OK                                            |
| 1         | Missing/malformed manifest or archive (including missing res directory, missing sources/, missing manifest, manifest lists URLs with no corresponding archives and no NOT ARCHIVED marker) | HARD fail (researcher return is broken)       |
| 2         | Validator infrastructure failure (I/O/parser/dependency - manifest not readable, jq not available, etc.)                                                                                   | INFRA error (validator environment is broken) |

### Stream contract

- **stderr:** `FAIL: <message>` lines for HARD failures (exit 1) or INFRA errors (exit 2)
- **stdout:** `ok: <message>` lines for passes; final summary line on exit 0
- **Fail-fast:** YES (unlike other validators that collect-all). Rationale: manifest parsing is sequential; early failures make later steps meaningless.
- **Shell defaults:** `set -euo pipefail`

### Skill prompt update (`.opencode/skills/research-pipeline/SKILL.md`)

Add new section after "Phase 2 verification (HARD GATE)":

```markdown
### Deviation Recording

If you cannot use the 3-tier chain (e.g., sandbox denies curl/trafilatura), you MUST record the deviation in `.source-urls.txt` with the reason and the alternative tool used.

**Manifest format (pipe-delimited):**
```

URL | tool | archived-path-or-NOT-ARCHIVED | relevance/reliability

```

**Examples:**

```

# Correct manifest entry (3-tier chain followed):

https://example.com | trafilatura | sources/example.md | High/High

# Correct manifest entry (deviation recorded):

https://example.com | webfetch (trafilatura denied by sandbox) | sources/example.md | High/High

# Correct manifest entry (source not archived):

https://example.com | trafilatura+curl+crwl all failed | [source not archived] | High/High

# INCORRECT (missing archival evidence):

https://example.com | trafilatura | High/High

```

**WARNING:** DO NOT use WebFetch/context7/gh_grep for source archival unless the 3-tier chain is unavailable AND you record the deviation in `.source-urls.txt`. The orchestrator will reject your return if archival evidence is missing.

**Phase 2 compliance validator:** The orchestrator runs `scripts/validate-research-pipeline.sh knowledge/res<id>-<topic>/` after you return. If the validator exits 1, your return is rejected and you are re-dispatched with explicit instructions. If the validator exits 2, the orchestrator halts and escalates to the developer.
```

## Verification gate summary

| Gate                                                                                 | When        | Required                                                                               |
| ------------------------------------------------------------------------------------ | ----------- | -------------------------------------------------------------------------------------- |
| `make test-shell`                                                                    | After T1/T2 | Pre-existing bats baseline + new `validate-research-pipeline.bats` pass                |
| `bash scripts/validate-research-pipeline.sh knowledge/res<id>-<topic>/` (standalone) | After T1    | Exit 0 on real research conspect (e.g., `knowledge/res008-source-archival-fallbacks/`) |
| Manual: skill prompt update                                                          | After T3    | Visual review: deviation recording section present, examples correct                   |

## Traceability to confirmed rulings

Every design decision above is locked to a confirmed interview ruling. The mapping:

| Decision                                                    | Ruling source            |
| ----------------------------------------------------------- | ------------------------ |
| Structural invariants only (no tool-provenance ban)         | Q7                       |
| Exit 0/1/2 contract (missing res dir is exit 1)             | Q8, developer correction |
| Pipe-delimited manifest format                              | Q8                       |
| Orchestrator invokes validator (no Makefile target)         | Q10                      |
| Re-dispatch flow (exit 1 -> reject + re-dispatch)           | Q10                      |
| Skill prompt strengthening (deviation recording + examples) | Q10                      |
| Hard gate (not soft audit)                                  | Q7                       |

No decision in this design.md is invented beyond the confirmed rulings. If a gap emerges during implementation, the coder lane flags it to the orchestrator rather than deciding silently.
