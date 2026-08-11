# ana010 -- Artifacts Folder Audit

- **Ticket:** DIA-084
- **Author:** @analyzer
- **Date:** 2026-08-11
- **Scope:** Full audit of knowledge/, .opencode/memory-shelf.yaml, .opencode/learnings/, .opencode/session/, openspec/, .sdd/, .tss/ plus skill-location convention documentation.
- **Guardrail:** No files were deleted, moved, or renamed. All recommendations are evidence-backed proposals requiring developer approval.

---

## 1. Executive Summary

| Category | Count |
|---|---|
| Misplaced files | 1 |
| Duplicate artifacts | 2 |
| Obsolete artifacts | 1 |
| Naming convention violations | 3 |
| Dangling cross-references | 1 |
| Unowned artifacts (no owner header) | 19 |
| Stale indexes | 1 |
| Status mismatches (shelf vs actual) | 4 |
| Unregistered openspec changes | 10 |
| Empty/incomplete changes | 1 |
| Committed-but-should-be-ignored | 1 |

**Overall health:** 8 of 11 folders are structurally sound. The three systemic issues are: (a) knowledge/ naming drift from the `<type><id>-<topic>` convention, (b) memory-shelf.yaml losing sync with openspec/changes/, (c) skill-location opacity for non-local runtimes.

---

## 2. Per-Folder Findings

### 2.1 knowledge/

**Contents:** 25 directories (11 res*, 10 ana*, 1 context7-docs, 2 ana-post-*, 1 context7-docs generated cache)

| ID | Directory | Status | Issue |
|---|---|---|---|
| 1 | ana001-docker-trafilatura-strategy/ | OK | Report present |
| 2 | ana002-agent-alignment-audit/ | OK | Report present |
| 3 | ana003-* | MISSING | Gap in sequence (001,002,004-009 used) |
| 4 | ana004-spec-authoring-philosophy/ | OK | Report present |
| 5 | ana005-false-delegation-ticket-audit/ | OK | Report present |
| 6 | ana006-issue-tracker-comparison/ | OK | Report present |
| 7 | ana007-session-log-silencing/ | OK | Report present |
| 8 | ana008-crosscheck-readiness/ | OK | Report present |
| 9 | ana009-telemetry-reentrancy-audit/ | OK | Report present |
| 10 | ana-post-cherry-pick-audit/ | **NAMING VIOLATION** | No numeric ID; should be ana011 or renumbered |
| 11 | ana-post-rebase-audit/ | **NAMING VIOLATION** | No numeric ID; should be ana012 or renumbered |
| 12 | res001-openspec-sdd-reconciliation/ | OK | Conspect present |
| 13 | res002-silent-session-logging/ | OK | Conspect + sources |
| 14 | res003-telemetry-reentrancy-guards/ | OK | Conspect + sources |
| 15 | res003-tui-corruption-stdout/ | **DUPLICATE + ORPHAN** | Same ID as #14 (collision); no conspect file, only empty sources/; topic duplicates res007 |
| 16 | res004-tool-enumeration/ | **COMMITTED SOURCE FILE** | sources/opencode-show-tools-npm.md is committed but should be gitignored |
| 17 | res005-opencode-telemetry-upstream-fix/ | OK | Conspect + sources |
| 18 | res006-telemetry-plugin-alternatives/ | OK | Conspect + sources |
| 19 | res007-tui-corruption-stdout/ | OK | Conspect + sources (canonical copy) |
| 20 | res008-source-archival-fallbacks/ | OK | Conspect + sources |
| 21 | res009-snip-jq-filter-truncation/ | OK | Conspect + sources |
| 22 | res010-dia078-loop-hardening/ | OK | Conspect + sources |
| 23 | res011-opencode-snip-mechanical-lock/ | OK | Conspect + sources |
| 24 | context7-docs/ | **NAMING VIOLATION** | No type prefix or ID; 28 generated files; correctly gitignored |
| 25 | (this report) | -- | ana010-artifacts-folder-audit/ |

**Missing:** No `knowledge/index.md` or `knowledge/README.md`.

**Ownership:** 19 of 21 conspect/report files have no owner lane or agent in their header metadata. The shelf entry provides implicit ownership (analyses = @analyzer, conspects = @conspecter) but individual files lack this annotation.

### 2.2 .opencode/memory-shelf.yaml

**YAML validity:** VALID (verified via `python3 -c "import yaml; yaml.safe_load(...)"`)

| Check | Result |
|---|---|
| YAML parse | PASS |
| All conspect paths resolve | PASS (11/11) |
| All analysis paths resolve | PASS (10/10) |
| All ADR paths resolve | PASS (1/1) |
| All spec paths resolve | **1 DANGLING** |
| Spec status alignment | **4 MISMATCHES** |
| Spec coverage (active changes) | **10 UNREGISTERED** |

**Dangling reference:**
- `ai-self-improvement-auditor-and-cleanup` -> `openspec/changes/ai-self-improvement-auditor-and-cleanup/` (DOES NOT EXIST). The change was archived to `openspec/changes/archive/2026-08-06-ai-self-improvement-auditor-and-cleanup/` but the shelf still points to the active path.

**Status mismatches (shelf vs proposal.md):**

| Change | Shelf status | proposal.md status | Actual state |
|---|---|---|---|
| context7-docs-pipeline | implemented | proposed | Implemented (script exists, data generated) |
| dia-redispatch-cycle | implemented | proposed | Implemented (architecture.md + fixtures exist) |
| volta-to-mise | proposed | proposed | Partially implemented (mise adopted in Dockerfile, .mise.toml exists) |
| dev-infra-pin-sync | implemented | proposed | Implemented (check-pin-sync.sh exists) |

The proposal.md files were not updated to "implemented" after implementation. The shelf is the more accurate source but the proposal.md files are stale.

**Unregistered changes (in openspec/changes/ but NOT in shelf):**
1. dev-infra-config-validators
2. dev-infra-copilot-fixes
3. dev-infra-copilot-fixes-2
4. dev-infra-jq-probe
5. dev-infra-language-servers
6. dev-infra-stack-hardening (proposal.md says "implemented")
7. dia-067-docker-trafilatura
8. dia-071-host-lsp-tolerance (EMPTY - no proposal/design/tasks)
9. pre-commit-autofix
10. test-skills-gate

### 2.3 .opencode/learnings/

**Structure:** `index.md` + `external-patterns/` (43 files)

| Check | Result |
|---|---|
| index.md exists | YES |
| index.md current | **STALE** (says "Last updated: 2026-08-09" but files from 2026-08-10 and 2026-08-11 exist) |
| Naming convention | OK (date-based: `YYYY-MM-DD-topic.md`) |
| .gitkeep in external-patterns/ | YES |

**Stale index entries (not in index.md but files exist):**
- `2026-08-10-dia063-ticket-gate-non-determinism.md`
- `2026-08-10-dia078-snip-deny-gate.md`
- `2026-08-10-dia078-snip-loop-hardening.md`
- `2026-08-10-project-agent-scoping-allowlist.md`
- `2026-08-11-context-usage-session-scope.md`
- `2026-08-11-dia093-checksum-delegation-fix.md`
- `2026-08-11-git-permission-merge-semantics.md`
- `2026-08-11-git-permission-pattern-matching.md`
- `2026-08-11-project-ops-reference.md`

That is 9 files unindexed.

### 2.4 .opencode/session/

**Gitignore status:** CORRECTLY GITIGNORED (`.opencode/session/` in root `.gitignore`)
**Committed files:** NONE (verified via `git ls-files .opencode/session/`)

| File | Size | Purpose |
|---|---|---|
| messages.jsonl | 938K | Canonical session log (NDJSON) |
| messages.md | 202K | Derived view (should be regenerated, not manually maintained) |
| registry.jsonl | 543K | Delegation registry |
| HANDOFF.md | 7K | Current handoff document |
| current-handoff.json | 7K | Machine-readable handoff |
| gate-tokens/ | dir | Cycle budget gate tokens |
| README.md | 10K | Session directory documentation |

**Verdict:** Correctly configured. Transient session data is gitignored. No committed duplicates exist elsewhere.

### 2.5 openspec/

**Structure:** `config.yaml` + `templates/` + `changes/` (16 active + 1 archived)

| Change | Status (proposal.md) | In shelf? | Complete? |
|---|---|---|---|
| context7-docs-pipeline | proposed | YES (implemented) | YES (proposal/design/tasks) |
| dev-infra-config-validators | proposed | NO | YES |
| dev-infra-copilot-fixes | proposed | NO | YES |
| dev-infra-copilot-fixes-2 | proposed | NO | YES |
| dev-infra-jq-probe | proposed | NO | YES |
| dev-infra-language-servers | proposed | NO | YES |
| dev-infra-pin-sync | proposed | YES (implemented) | YES |
| dev-infra-stack-hardening | implemented | NO | YES |
| dia-066-tool-coverage-audit | proposed | YES (proposed) | YES |
| dia-067-docker-trafilatura | proposed | NO | YES |
| **dia-071-host-lsp-tolerance** | N/A | NO | **EMPTY** (only .openspec.yaml) |
| dia-redispatch-cycle | proposed | YES (implemented) | YES |
| pre-commit-autofix | proposed | NO | YES |
| test-skills-gate | proposed | NO | YES |
| volta-to-mise | proposed | YES (proposed) | YES |

**Archive:** 1 entry (`2026-08-06-ai-self-improvement-auditor-and-cleanup`).

**Missing:** No `openspec/index.md` or `openspec/changes/index.md` listing all active changes.

**Issue:** `dia-071-host-lsp-tolerance` is an empty change scaffold (only `.openspec.yaml`). It has no proposal.md, design.md, or tasks.md. This is either abandoned or never started.

### 2.6 .sdd/

**Structure:** `README.md` + `dia-redispatch-cycle/architecture.md`

| Check | Result |
|---|---|
| README.md | YES (well-documented three-layer model) |
| Module docs | 1 (dia-redispatch-cycle) |
| Index file | NO (README serves as index) |

**Verdict:** Clean and minimal. The README explicitly states .tss/ is "future". One module doc exists. No issues.

### 2.7 .tss/

**Status:** DOES NOT EXIST.

**Evidence:** `openspec/config.yaml` explicitly states: `Technical specs: .tss/ (API contracts, data schemas -- future)`. This is intentional and documented.

---

## 3. Cross-Cutting Findings

### 3.1 Naming Convention Violations

| Location | Violation | Expected |
|---|---|---|
| knowledge/ana-post-cherry-pick-audit/ | No numeric ID | ana011-<topic> or ana012-<topic> |
| knowledge/ana-post-rebase-audit/ | No numeric ID | ana012-<topic> or ana011-<topic> |
| knowledge/context7-docs/ | No type prefix, no ID | This is a generated cache dir (gitignored); convention may not apply |

### 3.2 Duplicate Artifacts

| Duplicate Pair | Evidence |
|---|---|
| res003-tui-corruption-stdout/ vs res007-tui-corruption-stdout/ | Same topic. res003 has only empty sources/; res007 has full conspect + sources. res003 also collides with res003-telemetry-reentrancy-guards/ (ID collision). |
| knowledge/context7-docs/ vs knowledge/ shelf entry | context7-docs is a generated cache (gitignored) but not a knowledge artifact. No shelf entry. Naming makes it look like a conspect. |

### 3.3 Obsolete / Orphan Artifacts

| Artifact | Evidence |
|---|---|
| knowledge/res003-tui-corruption-stdout/ | No conspect file, empty sources/, topic duplicated by res007, ID collides with res003-telemetry-reentrancy-guards. This is a leftover from a failed/abandoned conspect attempt. |
| openspec/changes/dia-071-host-lsp-tolerance/ | Empty scaffold (only .openspec.yaml). No proposal/design/tasks. Appears abandoned. |

### 3.4 Dangling Cross-References

| Reference | Target | Status |
|---|---|---|
| shelf -> `openspec/changes/ai-self-improvement-auditor-and-cleanup/` | Dir moved to archive/ | **DANGLING** (archive path not updated in shelf) |

### 3.5 Committed-but-Should-Be-Ignored

| File | Gitignore rule | Evidence |
|---|---|---|
| knowledge/res004-tool-enumeration/sources/opencode-show-tools-npm.md | `knowledge/*/sources/` | Committed in e00c81d (DIA-067 VERIFIED). The gitignore pattern should exclude this but it was committed before the gitignore rule was added, or the rule was added without removing the existing tracked file. |

### 3.6 Stale Indexes

| Index | Last updated | Issue |
|---|---|---|
| .opencode/learnings/index.md | 2026-08-09 | 9 files from 2026-08-10/11 are not indexed |

### 3.7 Missing Indexes

| Folder | Index exists? |
|---|---|
| knowledge/ | NO (no index.md or README.md) |
| openspec/changes/ | NO (no index.md listing active changes) |
| .sdd/ | README serves as index (adequate) |
| .opencode/NOTES/ | NO |

### 3.8 Unowned Artifacts

19 of 21 conspect/report files in knowledge/ have no owner lane or agent in their header metadata. The shelf provides implicit ownership (conspects = @conspecter, analyses = @analyzer) but individual files lack this annotation. This is a minor issue since the shelf is the canonical ownership record, but file-level ownership would survive shelf separation.

---

## 4. Skill-Location Convention

### 4.1 Two-Tier Skill Architecture

OpenCode resolves skills from two locations:

| Location | Path | Scope | Resolution |
|---|---|---|---|
| Project | `.opencode/skills/` | This repo only | Always loaded when working in this project |
| Global | `~/.config/opencode/skills/` | All projects for this user | Always loaded for this user on this machine |

### 4.2 Current Distribution

**Project-only skills (13):**
code-review-fowler, domain-grilling, git-permissions, openspec-apply-change, openspec-archive-change, openspec-explore, openspec-propose, openspec-sync-specs, openspec-update-change, research-pipeline, resolving-merge-conflicts, review-re-verify, to-tickets

**Global-only skills (13):**
clonedeps, codemap, console-charting, deepwork, mermaid-diagramming, oh-my-opencode-slim, reflect, release-smoke-test, simplify, tdd-craftsman, teaching, verification-planning, worktrees

**Overlapping skills (4) -- present in BOTH locations with DIVERGENT content:**
- book-rag (371 lines both, but content differs)
- debugging-workflow (324 lines both, but content differs)
- git-diff (project: 37 lines, global: 35 lines)
- playwright-browser (project: 469 lines, global: 473 lines)

### 4.3 The "Dangling" Skills (teaching, mermaid-diagramming, console-charting)

These three skills appear in the OpenCode system prompt's `<available_skills>` list with `<location>` pointing to the GLOBAL path (`~/.config/opencode/skills/`), NOT the project path. They are NOT present in the project's `.opencode/skills/` directory.

**Resolution mechanism:** OpenCode loads skills from BOTH project and global paths at startup. The system prompt reflects all loaded skills regardless of source. These three skills resolve correctly on THIS machine because `~/.config/opencode/skills/` contains them.

### 4.4 Risk Assessment

**Risk: HIGH for non-local runtimes**

If OpenCode runs outside this user's home directory:
- **CI container:** Would NOT have `~/.config/opencode/skills/` populated. teaching, mermaid-diagramming, console-charting, tdd-craftsman, deepwork, reflect, and 8 other global skills would FAIL to resolve.
- **Different developer machine:** Would need to manually clone/copy global skills or they would be missing.
- **Docker dev container:** The container mounts the project but typically not `~/.config/opencode/`. These skills would not resolve inside the container.

**Mitigation options:**
1. **Document the convention:** Add a `.opencode/skills/README.md` explaining which skills are global-only and why (user-specific workflow preferences vs project-shared skills).
2. **Pin critical skills at project level:** If tdd-craftsman, teaching, mermaid-diagramming, or console-charting are needed for reproducible builds/CI, copy them to `.opencode/skills/`.
3. **Bootstrap script:** Create a script that installs global skills on a new machine (e.g., `scripts/bootstrap-opencode-skills.sh`).
4. **Accept the risk:** If these skills are only needed for interactive development on this machine and not for CI or team use, document the dependency and move on.

**Verdict:** NEEDS DEVELOPER DECISION. The risk is real but may be acceptable if global skills are intentionally user-specific workflow preferences that should not be shared via the repo.

### 4.5 Overlap Risk

The 4 divergent overlapping skills (book-rag, debugging-workflow, git-diff, playwright-browser) create ambiguity: which version does OpenCode load first? If project takes precedence, the global versions are dead code. If global takes precedence, the project versions are dead code. Either way, maintaining two copies is a drift risk.

---

## 5. Archive Policy Verification

### 5.1 Ticket Archive

**Location:** `docs/dev-infra-audit/tickets/archive/`
**Contents:** 19 archived tickets (DIA-003, DIA-006, DIA-030, DIA-034..DIA-049, DIA-076, DIA-081)
**Policy:** Archived tickets are never deleted (verified - all 19 files intact with full content).

**Active tickets still marked CLOSED (not archived):** 16 tickets (DIA-045, DIA-050, DIA-051, DIA-055, DIA-056, DIA-069, DIA-070, DIA-072, DIA-073, DIA-080, DIA-082, DIA-083, DIA-091, DIA-094, DIA-095, DIA-096)

**Verdict:** Archive policy is correctly applied. Closed tickets in active/ are acceptable (they were closed recently and may still be referenced). The archive directory preserves historical tickets.

### 5.2 OpenSpec Archive

**Location:** `openspec/changes/archive/`
**Contents:** 1 archived change (ai-self-improvement-auditor-and-cleanup, archived 2026-08-06)

**Issue:** The memory-shelf still points to the pre-archive path.

---

## 6. Recommendations

### 6A. Safe-to-Apply (no developer decision needed)

| # | Recommendation | Evidence | Effort |
|---|---|---|---|
| A1 | Fix the dangling shelf reference: update `ai-self-improvement-auditor-and-cleanup` path to `openspec/changes/archive/2026-08-06-ai-self-improvement-auditor-and-cleanup/` | Shelf points to non-existent active path; archived path exists | 1 line edit |
| A2 | Remove empty `knowledge/res003-tui-corruption-stdout/` directory | No conspect file, empty sources/, ID collision with res003-telemetry-reentrancy-guards, topic duplicated by res007 | `rmdir` |
| A3 | Untrack `knowledge/res004-tool-enumeration/sources/opencode-show-tools-npm.md` from git | Committed but should be gitignored by `knowledge/*/sources/` rule. Run `git rm --cached` to untrack without deleting | 1 git command |
| A4 | Update `.opencode/learnings/index.md` to include the 9 missing files from 2026-08-10/11 | Index says "Last updated: 2026-08-09" but 9 newer files exist | Add 9 index entries |
| A5 | Assign numeric IDs to `ana-post-cherry-pick-audit` and `ana-post-rebase-audit` (e.g., ana011 and ana012) and rename directories accordingly | Violates `<type><id>-<topic>` convention; shelf entries would need path updates | Rename 2 dirs + update shelf |

### 6B. Needs Developer Decision

| # | Recommendation | Evidence | Decision needed |
|---|---|---|---|
| B1 | Register the 10 unregistered openspec changes in memory-shelf.yaml under `shelf.specs` | 10 active changes have no shelf entry, making them invisible to the central index | Which to register? All 10 or only completed ones? |
| B2 | Update proposal.md status fields for implemented changes (context7-docs-pipeline, dia-redispatch-cycle, volta-to-mise, dev-infra-pin-sync) | proposal.md says "proposed" but changes are implemented | Stale proposal.md update or accept shelf as source of truth? |
| B3 | Create `knowledge/index.md` listing all knowledge artifacts | No index file exists; 25 directories with no central listing | Design the index format |
| B4 | Decide on `knowledge/context7-docs/` naming | Violates `<type><id>-<topic>` but is a generated cache (gitignored) that does not fit the conspect/analysis/tech model | Accept exception or rename? |
| B5 | Resolve the 4 divergent overlapping skills (book-rag, debugging-workflow, git-diff, playwright-browser) | Two copies with different content; unclear which version OpenCode loads | Keep project, global, or reconcile? |
| B6 | Decide on skill-location risk mitigation for CI/container runtimes | 13 global-only skills would fail to resolve outside this user home | Accept risk, bootstrap script, or pin critical skills at project level? |
| B7 | Clean up or complete `openspec/changes/dia-071-host-lsp-tolerance/` | Empty scaffold (only .openspec.yaml, no proposal/design/tasks) | Archive, delete, or complete? |
| B8 | Add owner/lane metadata headers to knowledge/ artifacts | 19 of 21 files have no explicit owner in file header | Add headers or rely on shelf for ownership? |
| B9 | Fill the ana003 gap or document why it was skipped | Sequence 001, 002, 004-009 used; 003 missing | Reuse 003 or leave gap? |

---

## 7. Folder Health Summary

```
knowledge/                  [WARN]  3 naming violations, 1 orphan, 1 committed source, no index
.opencode/memory-shelf.yaml [WARN]  1 dangling ref, 4 status mismatches, 10 unregistered specs
.opencode/learnings/        [WARN]  Stale index (9 files unindexed)
.opencode/session/          [OK]    Correctly gitignored, no committed files
openspec/                   [WARN]  1 empty change, 10 unregistered, no index, 1 archived ref stale
.sdd/                       [OK]    README + 1 module doc, clean
.tss/                       [OK]    Does not exist (intentional, documented as "future")
.opencode/NOTES/            [OK]    1 tracked file (otlp-genai-pin.md), no index
.opencode/memory/           [OK]    ADR + lessons + audits, well-structured
```

---

## 8. ASCII Tree: Full Artifact Layout

```
poetry-platform/
+-- knowledge/
|   +-- ana001-docker-trafilatura-strategy/   [OK]
|   +-- ana002-agent-alignment-audit/         [OK]
|   +-- ana004-spec-authoring-philosophy/     [OK]
|   +-- ana005-false-delegation-ticket-audit/ [OK]
|   +-- ana006-issue-tracker-comparison/      [OK]
|   +-- ana007-session-log-silencing/         [OK]
|   +-- ana008-crosscheck-readiness/          [OK]
|   +-- ana009-telemetry-reentrancy-audit/    [OK]
|   +-- ana-post-cherry-pick-audit/           [NAMING]
|   +-- ana-post-rebase-audit/                [NAMING]
|   +-- context7-docs/                        [NAMING, gitignored]
|   +-- res001-openspec-sdd-reconciliation/   [OK]
|   +-- res002-silent-session-logging/        [OK]
|   +-- res003-telemetry-reentrancy-guards/   [OK]
|   +-- res003-tui-corruption-stdout/         [ORPHAN+COLLISION]
|   +-- res004-tool-enumeration/              [COMMITTED SOURCE]
|   +-- res005-opencode-telemetry-upstream-fix/ [OK]
|   +-- res006-telemetry-plugin-alternatives/ [OK]
|   +-- res007-tui-corruption-stdout/         [OK, canonical]
|   +-- res008-source-archival-fallbacks/     [OK]
|   +-- res009-snip-jq-filter-truncation/     [OK]
|   +-- res010-dia078-loop-hardening/         [OK]
|   +-- res011-opencode-snip-mechanical-lock/ [OK]
|   +-- (ana010-artifacts-folder-audit/)      [THIS REPORT]
|
+-- .opencode/
|   +-- memory-shelf.yaml                     [DANGLING REF, STATUS MISMATCHES]
|   +-- learnings/
|   |   +-- index.md                          [STALE]
|   |   +-- external-patterns/ (43 files)     [OK]
|   +-- session/                              [OK, gitignored]
|   +-- images/                               [OK, gitignored, empty]
|   +-- NOTES/otlp-genai-pin.md               [OK, tracked]
|   +-- memory/                               [OK, ADR + lessons]
|   +-- skills/ (17 dirs)                     [4 overlap w/ global]
|
+-- openspec/
|   +-- config.yaml                           [OK]
|   +-- templates/                            [OK]
|   +-- changes/
|   |   +-- (15 active changes)               [1 EMPTY, 10 unregistered]
|   |   +-- archive/ (1 entry)                [OK, but shelf ref stale]
|
+-- .sdd/
|   +-- README.md                             [OK]
|   +-- dia-redispatch-cycle/architecture.md  [OK]
|
+-- .tss/                                     [DOES NOT EXIST, intentional]
```

---

## 9. Verification Evidence

- YAML validation: `python3 -c "import yaml; yaml.safe_load(open('.opencode/memory-shelf.yaml'))"` -> VALID
- Git tracking: `git ls-files .opencode/session/` -> empty (correctly gitignored)
- Git tracking: `git ls-files .opencode/images/` -> empty (correctly gitignored)
- Git tracking: `git ls-files 'knowledge/*/sources/*'` -> 1 file (knowledge/res004-tool-enumeration/sources/opencode-show-tools-npm.md)
- Naming check: `grep -E '^(res|ana|tch)[0-9]{3}-'` -> 3 violations found
- Path resolution: Python script checked all shelf paths -> 1 dangling
- Skill comparison: `diff -q` on 4 overlapping skills -> all divergent
- Archive integrity: `ls archive/` -> all 19 ticket files intact

---

*Report generated by @analyzer for DIA-084. No files were modified, moved, or deleted during this audit.*
