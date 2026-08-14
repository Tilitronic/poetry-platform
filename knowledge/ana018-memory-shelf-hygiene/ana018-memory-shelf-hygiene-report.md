# ana018 — Memory Shelf Hygiene Audit

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: /workspace/.opencode/memory-shelf.yaml, /workspace/.opencode/memory/*, /workspace/knowledge/*, /workspace/openspec/changes/*
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

**Ticket:** DIA-138
**Author:** @analyzer (ana018)
**Date:** 2026-08-14
**Scope:** Full hygiene audit of `.opencode/memory-shelf.yaml`, `.opencode/memory/*.md`, `knowledge/*`, and `openspec/changes/*` unregistered entries. Report only — no files modified.
**Method:** MECE topic bucketing + path-resolution integrity pass + duplicate/supersede evidence review.

---

## 1. Executive Summary

- **Total indexed entries:** 54 (21 conspects + 19 analyses + 2 ADRs + 11 specs + 1 architecture + 0 rag_bases). All 54 paths resolve to existing files/dirs. No broken references.
- **Integrity issues:** 4 findings — (a) duplicate lesson ID `L20260812-003` in lessons.md at L358 and L704 for two unrelated lessons (HARD BUG); (b) non-standard ana IDs `ana01` and `ana-post-cherry-pick-audit` / `ana-post-rebase-audit` violate the `anaNNN-kebab-case` naming contract; (c) conspects ordering places res021 before res018-020 in the yaml; (d) `rag_bases: []` is declared but empty (no defect, just an observation).
- **Orphan shelf entries:** 0. All shelf paths resolve.
- **Orphan knowledge/ directories:** 0. Every `knowledge/<entry>` dir has a shelf entry.
- **Orphan openspec/changes/ directories:** 10 dirs on disk are NOT registered in `shelf.specs` (most are status:proposed; 1 is status:implemented).
- **Topical overlap hotspots:** the telemetry cluster (5 entries), the model-pricing/escalation cluster (6 entries), and the post-merge audit cluster (3 entries) warrant per-bucket review — see §3. Of the suspected overlaps, 1 is a clear ARCHIVE candidate (ana014 — superseded by res017), 1 is a likely MERGE candidate (ana007 + ana008 — distinct but cross-referenced), the rest are DISTINCT-focus.
- **No DELETE candidates in knowledge/:** every entry has a documented research or audit purpose; even the stale-looking ones (telemetry res005/res006 after plugin removal) are historical records. The only firm ARCHIVE is ana014.

---

## 2. Integrity Table

### 2.1 Shelf path resolution (all 54 entries)

| Section | Count | All paths resolve? | Notes |
|---|---|---|---|
| conspects | 21 | YES | Ordering quirk: res021 at yaml L83-86 precedes res018 at yaml L104 (not a defect, cosmetic). |
| analyses | 19 | YES | Two entries use non-standard IDs: `ana01-tests-ponytail-audit` (L281-286), `ana-post-cherry-pick-audit` (L229-232), `ana-post-rebase-audit` (L233-236). Naming contract says `anaNNN-kebab-case` (3-digit numeric). |
| adrs | 2 | YES | Both entries point to the SAME file `.opencode/memory/adr.md` — different ADR sections inside. Not a defect but redundant path. |
| specs | 11 | YES (all dirs exist) | All dirs contain proposal/design/tasks as expected. |
| architectures | 1 | YES | `.sdd/opencode-config/architecture.md` exists. |
| rag_bases | 0 | N/A | Empty list, declared at yaml L530. |

### 2.2 ID uniqueness check

| ID | Unique? | Issue |
|---|---|---|
| res001..res021 (21 IDs) | YES | All unique, all 3-digit numeric. |
| ana001, ana002, ana004..ana017 | YES | **ana003 is missing** (jumps 002 -> 004). Gap suggests a prior deletion or renumber. |
| ana01 | YES (but naming) | Non-standard: 2-digit, not 3-digit. Should be `ana003` or documented as legacy. |
| ana-post-cherry-pick-audit | YES (but naming) | Non-standard: no numeric prefix. |
| ana-post-rebase-audit | YES (but naming) | Non-standard: no numeric prefix. |
| adrs (2 entries, both -> adr.md) | NO — same path | Two shelf entries share one file. Each references a distinct ADR section inside (ADR 1 + ADR "Needs-input ticker DIA-122"), which is acceptable, but the path column is identical — confusing for audits. |
| Lessons IDs in lessons.md | **NO — duplicate `L20260812-003`** at L358 (section-10 dispatch ticket correlation) AND L704 (gate-script re-entrancy guard). Two distinct lessons share one ID — HARD BUG. |

### 2.3 Orphan / unregistered dirs

- `knowledge/*`: no orphans.
- `openspec/changes/` — **10 dirs on disk not in `shelf.specs`** (see §4.d): `dev-infra-jq-probe`, `dev-infra-language-servers`, `dev-infra-config-validators`, `dev-infra-copilot-fixes`, `dev-infra-copilot-fixes-2`, `dev-infra-stack-hardening` (status:implemented), `dia-067-docker-trafilatura`, `dia-071-host-lsp-tolerance` (empty dir — no proposal.md), `pre-commit-autofix`, `test-skills-gate`.

---

## 3. MECE Topic Buckets

Bucketed by topical focus. For each bucket with 2+ members, verdict: **DUP** (merge candidate), **DISTINCT** (keep all), or **SUPERSEDED** (archive older).

### Bucket A — Telemetry & plugin correctness (5 entries)

| ID | Focus |
|---|---|
| res003 | Canonical taxonomy of re-entrancy guard patterns (P1-P4), failure classes |
| res005 | DIA-069 upstream fix for `opencode-telemetry` command-template $HOME pollution |
| res006 | Survey of alternative telemetry plugins (Tokenscope, OTEL, Context Analysis, etc.) |
| res007 | TUI corruption: stdout/stderr painted over TUI (root cause + local plugin) |
| ana009 | DIA-056(b) root-cause audit of opencode-telemetry + opencode-token-monitor (P1-P4 gap analysis) |

**Verdict: DISTINCT.** Each covers a different aspect: taxonomy (res003), one specific plugin bug (res005), alternatives survey (res006), TUI-specific root cause (res007), project-runtime audit (ana009). No duplication. ana009 is the only "our plugins specifically" entry; the others are reference conspects. **Note for relevancy:** `opencode-telemetry` and `opencode-token-monitor` are no longer loaded at runtime per ana009 and res011 — the cluster is now historical reference. Keep as research archive.

### Bucket B — snip / doom_loop / opencode-snip (3 entries)

| ID | Focus |
|---|---|
| res009 | snip jq filter truncation (pipe-splitting bug, checksum corruption) |
| res010 | DIA-078 doom_loop permission semantics + snip-wrapper loop recurrence |
| res011 | opencode-snip mechanical lock + removal-risk assessment (concludes: remove) |

**Verdict: DISTINCT.** Linear narrative: bug (res009) -> loop hardening (res010) -> removal decision (res011). Each has a distinct purpose; the trail is load-bearing context for why the plugin was removed (DIA-092). Keep.

### Bucket C — Model pricing / escalation / benchmarks (6 entries)

| ID | Focus |
|---|---|
| res013 | Go pricing audit + Copilot comparison (DIA-108) |
| res014 | Model escalation routing patterns (DIA-111, Rung0-4 ladder) |
| res015 | MiMo-V2.5-Pro evaluation (DIA-114, closes DIA-087 R5 gap) |
| res016 | Coder-escalated model evidence (DIA-111, session 15 synthesis) |
| res017 | Rung-3 live benchmark evidence (DIA-116, independent reproductions) |
| res021 | Agent presets: temp/reasoning per role (gap-fill for res013) |

**Verdict: DISTINCT with explicit cross-references.** res013/014/015/016/017 are a carefully non-duplicating chain (each entry's description cross-refs the others). res021 fills a different gap (temp/reasoning vs pricing). Keep all.

### Bucket D — Session logging / JSONL (3 entries)

| ID | Focus |
|---|---|
| res002 | Canonical conspect: silent session logging, dual-write anti-pattern |
| ana007 | Option-E decision analysis (plugin jsonl + derived md + log_decision) |
| ana008 | P5 cross-check readiness (why 3.35% was wrong; timestamp filter fix) |

**Verdict: DISTINCT.** res002 is a survey conspect; ana007 is a project-specific design decision; ana008 is a narrow diagnostic of one failed gate metric. Keep.

### Bucket E — Agent alignment / instruction audits (2 entries)

| ID | Focus |
|---|---|
| ana002 | MECE inventory of agent definitions across OMO/native/project/AGENTS.md (4 critical, 5 major, 4 minor issues) |
| ana016 | Cross-reference audit of 50 instruction-bearing files (prompt drift, HANDOFF.md phantom, boss_append dead, etc.) |

**Verdict: DISTINCT.** ana002 is about agent *existence/declaration* alignment; ana016 is about instruction *content* drift. Different axes. Keep.

### Bucket F — Ticket management / issue tracker / delegation (3 entries)

| ID | Focus |
|---|---|
| ana005 | False-delegation incidents + tickets-system connectivity audit |
| ana006 | GitHub Issues vs local DIA ledger architecture decision (DIA ledger wins) |
| res018 | Ticket-management automation survey (MCP, Plane, Vikunja, etc.) |

**Verdict: DISTINCT.** ana005 is forensic; ana006 is an architecture decision (keep local ledger); res018 surveys external tools. ana006 and res018 are complementary (ana006 says "stay local"; res018 says "if we ever went external, here's the menu"). Keep.

### Bucket G — Scientific methodology / workflow (2 entries)

| ID | Focus |
|---|---|
| res012 | Canonical conspect: scientific methodology for AI-driven research (50-source survey) |
| ana012 | Internal mapping of res012's practices onto existing project mechanisms (gap analysis + M1-M5 mandates) |

**Verdict: DISTINCT.** res012 is external survey; ana012 is "how does this apply to us" mapping. Keep.

### Bucket H — Post-merge / artifacts-folder audits (3 entries)

| ID | Focus |
|---|---|
| ana-post-cherry-pick-audit | 10-point cherry-pick audit on omo-slim-changes branch |
| ana-post-rebase-audit | 19-point rebase audit on omo-slim-changes branch |
| ana010 | DIA-084 artifacts-folder audit (knowledge/, learnings/, session/, openspec/, .sdd/, .tss/) |

**Verdict: DISTINCT.** ana-post-* are point-in-time merge/rebase audits (historical snapshots). ana010 is the comprehensive artifacts audit. ana-post-* have non-standard IDs; see §4.a REWRITE-DESC recommendation.

### Bucket I — Hook / verify / fork-bomb (2 entries)

| ID | Focus |
|---|---|
| ana015 | DIA-118 recursion fork-bomb root-cause analysis (verify-pre-push.sh) |
| ana017 | DIA-115 hook test coverage audit (pre-commit/pre-push, turbo, bats) |

**Verdict: DISTINCT.** ana015 is a narrow root-cause of one bug; ana017 is a broad coverage audit. Keep.

### Bucket J — Docker / container / ssh (2 entries)

| ID | Focus |
|---|---|
| ana001 | DIA-067 trafilatura container strategy analysis |
| res020 | ssh-add -c confirmation on Fedora 44 + KDE (DIA-133 context) |

**Verdict: DISTINCT.** ana001 is dev-container Python tooling; res020 is host SSH agent UX. Keep.

### Bucket K — Spec authoring (1 entry)

- ana004 (spec authoring philosophy audit, 52/100 score). No pair. Keep.

### Bucket L — Parallel sessions (1 entry)

- ana011 (DIA-085 parallel orchestrator coordination). Keep.

### Bucket M — DIA triage (1 entry)

- ana013 (DIA-097..105 parallel dev-infra batch triage). Keep.

### Bucket N — Benchmark protocol (1 entry, CANCELLED)

- ana014 (DIA-116 rung-3 live benchmark protocol). **CANCELLED by developer directive 2026-08-12.** The report itself states: "approach CANCELLED by developer directive 2026-08-12 (no self-benchmarking); superseded by res017 authoritative evidence". **ARCHIVE candidate** — see §4.a.

### Bucket O — Ponytail test audit (1 entry)

- ana01-tests-ponytail-audit (non-standard ID). Keep; consider rewrite-desc. See §4.a.

### Bucket P — OMO slim version-gate (1 entry)

- res019 (DIA-127 version-gate research). Keep — one-shot release-research conspect.

---

## 4. Categorized Recommendations

### 4.a Shelf entries (conspects + analyses)

| # | Action | Entry | Rationale | Confidence |
|---|---|---|---|---|
| 1 | **ARCHIVE** | ana014 (rung3-benchmark-protocol) | Explicitly cancelled by developer directive 2026-08-12 and superseded by res017. The file itself records the cancellation. Move to `knowledge/archive/ana014-rung3-benchmark-protocol/` and mark shelf `status: archived`. | High |
| 2 | **REWRITE-DESC** | ana01 (tests-ponytail-audit) | Naming violates `anaNNN` 3-digit contract. Either (a) rename directory to `ana003-tests-ponytail-audit` and fill the ana003 gap, OR (b) document the 2-digit exception in memory-shelf.yaml header comments. Decision: human. | High |
| 3 | **REWRITE-DESC** | ana-post-cherry-pick-audit | Non-standard ID (no numeric prefix). Same naming-question as above. Human decision: keep as legacy point-in-time audit OR assign a fresh `anaNNN` slot and archive the old ID. | High |
| 4 | **REWRITE-DESC** | ana-post-rebase-audit | Non-standard ID. Same treatment as #3. | High |
| 5 | **REWRITE-DESC** | res021 (opencode-agent-presets) | Ordering quirk: appears at yaml L83-86 before res018-020 (yaml L104-131). Cosmetic only — no runtime effect — but violates the ascending-ID expectation. Sort fix. | Med |
| 6 | **KEEP** | All other conspects and analyses (50 entries) | No duplication, no supersedence, all load-bearing. Telemetry cluster (Bucket A) and model cluster (Bucket C) look bloated but each entry has a distinct axis. | High |
| 7 | **KEEP (note)** | rag_bases: [] | Empty but declared. No action; just note it's intentional. | High |
| 8 | **REWRITE-DESC (shelf-side)** | adrs (2 entries -> same file) | Two shelf entries both point to `.opencode/memory/adr.md`. Acceptable (different ADR sections), but the path column is identical and will confuse audits. Either (a) add a `section:` or `anchor:` field, or (b) split adr.md into per-ADR files. Decision: human. | Med |

### 4.b lessons.md

| # | Action | Entry | Rationale | Confidence |
|---|---|---|---|---|
| 9 | **HARD FIX** | `L20260812-003` at L358 AND L704 | Two different lessons share the same ID. L358 is "section-10 dispatch ticket correlation"; L704 is "gate-script re-entrancy guard (DIA-118 fork-bomb)". Retitle one (likely L704 to `L20260812-005` since 004 is taken by the hook-exact lesson at L723). | High |
| 10 | **REVIEW** | Lessons vs ADR overlap at lessons.md L316-369 (gate-script re-entrancy) | The lesson at L704 duplicates the content of `adr.md` "ADR: Gate scripts that invoke the full test suite must carry a re-entrancy guard" (adr.md L316). Lesson and ADR coexist — check if the lesson adds irrecoverable context beyond the ADR, else collapse. | Med |
| 11 | **REVIEW** | Lessons "DeepSeek V4 thinking-mode / temperature inertness" at L695 | No lesson ID, no session/date header in standard format. Appears to be a correction appended mid-bucket rather than a proper lesson. Reformat or fold into res021 / adr.md. | Med |
| 12 | **KEEP** | All other lessons (14 of 16 sections) | Distinct, irrecoverable operational context per the lessons.md preamble contract. | High |

### 4.c Other memory files

| # | Action | Entry | Rationale | Confidence |
|---|---|---|---|---|
| 13 | **REVIEW** | `.opencode/memory/lessons-c-20260809-residual-closure.md` | Separate file with 5 lines — likely a residual closure note that should live inside lessons.md as a section, not as a separate file. Check if contents are duplicated in lessons.md L279-294 (same title). | Med |
| 14 | **REVIEW** | `.opencode/memory/audit-2026-08-02.md`, `incident-2026-08-09.md`, `repo.md` | Not referenced in memory-shelf.yaml. Check if these are load-bearing or stale one-off notes. `repo.md` (148 lines) looks like project notes. `audit-2026-08-02.md` (23 lines) may overlap with ana004. `incident-2026-08-09.md` (14 lines) is small. | Low |
| 15 | **KEEP** | `.opencode/memory/adr.md` | Load-bearing; contains 14 ADRs. | High |
| 16 | **KEEP** | `.opencode/memory/failures.md` | Load-bearing; cross-referenced by lessons.md. | High |

### 4.d Orphan openspec/changes/ directories

| # | Action | Entry | Rationale | Confidence |
|---|---|---|---|---|
| 17 | **REGISTER** | `openspec/changes/dev-infra-stack-hardening/` | Status:implemented on disk, but not in shelf.specs. Inconsistency — should be registered as a completed spec. | High |
| 18 | **REVIEW/REGISTER** | `dev-infra-jq-probe`, `dev-infra-language-servers`, `dev-infra-config-validators`, `dev-infra-copilot-fixes`, `dev-infra-copilot-fixes-2`, `dia-067-docker-trafilatura`, `pre-commit-autofix`, `test-skills-gate` (8 entries) | All status:proposed on disk, not in shelf. Either register them (if still live) or archive/delete them. Human decision on which are still active. | Med |
| 19 | **REVIEW** | `openspec/changes/dia-071-host-lsp-tolerance/` | Empty dir (no proposal.md). Likely aborted. Safe DELETE candidate — confirm with human. | High |

### 4.e knowledge/ orphan directories

- None. All `knowledge/*` dirs are registered. (Verified programmatically.)

---

## 5. Terminal Visualization

### 5.1 MECE buckets with verdicts

```
+------+----------------------------------------+------+----------+
| Buck | Topic                                   |  N   | Verdict  |
+------+----------------------------------------+------+----------+
| A    | Telemetry & plugin correctness          |  5   | DISTINCT |
| B    | snip / doom_loop / opencode-snip        |  3   | DISTINCT |
| C    | Model pricing / escalation / benchmarks |  6   | DISTINCT |
| D    | Session logging / JSONL                 |  3   | DISTINCT |
| E    | Agent alignment / instruction audits    |  2   | DISTINCT |
| F    | Ticket mgmt / issue tracker / deleg.    |  3   | DISTINCT |
| G    | Scientific methodology / workflow       |  2   | DISTINCT |
| H    | Post-merge / artifacts-folder audits    |  3   | DISTINCT |
| I    | Hook / verify / fork-bomb               |  2   | DISTINCT |
| J    | Docker / container / ssh                |  2   | DISTINCT |
| K    | Spec authoring                          |  1   | single   |
| L    | Parallel sessions                       |  1   | single   |
| M    | DIA triage                              |  1   | single   |
| N    | Benchmark protocol (CANCELLED)          |  1   | ARCHIVE  |
| O    | Ponytail test audit                     |  1   | single   |
| P    | OMO slim version-gate                   |  1   | single   |
+------+----------------------------------------+------+----------+
Total: 16 buckets, 41 knowledge/ entries.
1 ARCHIVE verdict (ana014). 0 DUP verdicts.
```

### 5.2 Decision flow

```
            Shelf entry
                |
    +-----------+-----------+
    |                       |
 Path resolves?         Path broken?
    |                       |
   YES                     NO (0 found)
    |
    +--- ID follows naming?
         |
    +----+----+-------+
    |         |       |
   YES    ana01   ana-post-*
    |    (rewrite) (rewrite)
    |
    +--- Topic overlap check (MECE bucket)
         |
    +----+---------+------------+
    |              |            |
 DISTINCT      DUP         SUPERSEDED
 (majority)   (0 found)   (ana014 only)
    |                          |
  KEEP                    ARCHIVE
```

---

## 6. DO NOT TOUCH List

These entries look odd but are load-bearing — referenced by skills/scripts/agents or part of the project's canonical knowledge chain:

| Entry | Why load-bearing |
|---|---|
| res003 / res005 / res006 / ana009 (telemetry cluster) | Cross-referenced by DIA-092 plugin-removal decision. Historical context for why opencode-telemetry was removed. |
| res009 / res010 / res011 (snip cluster) | Linear narrative culminating in DIA-092 opencode-snip removal. Each conspect is cited by later lessons. |
| res013 -> res014 -> res015 -> res016 -> res017 -> res021 (model cluster) | Explicitly cross-referenced chain (each entry's description names the others). Non-duplicating by design. |
| ana002 / ana016 | Both are the canonical agent-audit baseline; referenced by AGENTS.md §9 agent-naming contract. |
| ana010 | DIA-084 comprehensive artifacts audit; ana018 (this report) builds directly on it. |
| ana015 | DIA-118 fork-bomb root cause; referenced by lessons.md L704 and adr.md L316 (gate-script ADR). |
| ana017 | DIA-115 hook test coverage; findings fed into batch-d-infra-hardening spec. |
| res020 | DIA-133 ssh-agent-forward context; referenced by `openspec/changes/ssh-agent-forward-opencode-docker/`. |
| res001 | OpenSpec/SDD reconciliation; foundational design doc. |
| All `openspec/changes/archive/*` specs in shelf | Already archived; do not re-archive. |

---

## 7. What Is NOT Covered / Needs Human Judgment

1. **Whether `ana01` should be renumbered to `ana003`** to fill the ID gap, or documented as a legacy exception. Renumbering requires updating the directory name, the file stem, and the shelf path.
2. **Whether `ana-post-cherry-pick-audit` and `ana-post-rebase-audit` should be renamed to `anaNNN-*`** (e.g. ana018/ana019 would be the next slots, but this audit takes ana018). These are point-in-time audits whose ID is now frozen in commit history.
3. **Whether `adr.md` should be split into per-ADR files** (would give each shelf.adrs entry a distinct path). Current single-file form is convenient but the shared-path audit finding is real.
4. **Whether the 8 status:proposed openspec/changes/ dirs should be registered in shelf.specs** or archived/deleted. Human decision on which are still live plans vs abandoned scaffolds.
5. **Whether `dia-071-host-lsp-tolerance/` (empty dir) should be deleted.** Likely safe but confirm no references.
6. **Whether `lessons-c-20260809-residual-closure.md` should be merged into lessons.md.** Small file, likely redundant with lessons.md L279-294.
7. **Whether the L20260812-003 duplicate in lessons.md should be retitled to L20260812-005** (next free ID) or whether the lesson at L358 should keep the ID (older entry).
8. **relevancy of the "DeepSeek V4 thinking-mode / temperature inertness" entry at lessons.md L695** — formatting doesn't match the lesson template; may be a correction that should be folded into res021 or adr.md.
9. **relevancy of `.opencode/memory/audit-2026-08-02.md`, `incident-2026-08-09.md`, `repo.md`** — not in shelf. Check if load-bearing (quick read of each would confirm; not in scope for this hygiene audit).
10. **Ordering of res021 before res018-020 in the yaml** — cosmetic sort fix, low priority.

---

## 8. Findings Summary Count

- HARD BUGS: 1 (duplicate lesson ID L20260812-003)
- ARCHIVE candidates: 1 (ana014)
- REWRITE-DESC (naming contract): 4 (ana01, ana-post-cherry-pick-audit, ana-post-rebase-audit, res021 ordering)
- REGISTER candidates (openspec/): 9 (1 implemented + 8 proposed)
- DELETE candidates (knowledge/): 0
- DELETE candidates (openspec/): 1 (dia-071 empty dir — needs human confirm)
- MERGE candidates: 0
- Needs human judgment: 10 items (see §7)

End of report.
