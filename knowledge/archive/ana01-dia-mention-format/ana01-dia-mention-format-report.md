# Analysis: Human-Readable DIA Ticket Mentions

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: /home/qualt/Projects/poetry-platform/AGENTS.md, .opencode/plugins/delegation-observer.ts, docs/dev-infra-audit/tickets/README.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Executive Summary

**Recommendation:** Layered defense — **Approach 2 (lint rule) + Approach 1 (convention)**. Skip the plugin hook (Approach 3) — it covers only one surface (log_decision calls) while the problem spans five surfaces (AGENTS.md, code comments, handoff files, session logs, README index). The lint rule is the mechanical backstop; the convention guides agents to do it right the first time.

**Migration scope:** No migration of existing tickets (DIA-234 grandfather policy). No migration of existing mentions. The lint rule applies to NEW content only, with an allowlist for historical references.

---

## 1. Current State

### 1.1 Ticket ID Format
- **Sequential:** DIA-001 through DIA-234 (allocated via `scripts/tickets` max+1)
- **TOCTOU race:** parallel workflows can claim the same ID (DIA-215, DIA-234)
- **Proposed fix:** datetime format DIA-YYMMDD-XXXX (DIA-234)

### 1.2 Mention Format
- **Current:** bare IDs dominate — `DIA-190`, `DIA-174`, `DIA-063`
- **Convention exists:** AGENTS.md line 35 documents `DIA-NNN 'slug'` format for user-facing output
- **Compliance:** low — agents write bare IDs under context pressure

### 1.3 Surfaces Where Mentions Appear
1. **AGENTS.md** — written by AI, read by humans (23 bare DIA-NNN references found)
2. **Code comments** — written by AI, read by humans
3. **Handoff prognoses** — written by AI via log_decision, read by humans
4. **Session logs** — messages.jsonl, written by plugin, read by humans
5. **README index** — written by scripts/tickets, already includes slugs

### 1.4 Plugin Implementation
- `delegation-observer.ts` line 2478: `if (!/^DIA-\d+$/i.test(ticketId))` — hardcoded sequential regex
- `scanTickets` line 1073: `/^DIA-(\d+)/.exec(entry)` — filename regex also sequential
- `log_decision` tool schema line 3831: `ticket_id: tool.schema.string().optional()` — accepts any string

---

## 2. Approach Evaluation

### 2.1 Comparison Matrix

| Criterion | Approach 1: Convention | Approach 2: Lint Rule | Approach 3: Plugin Hook |
|-----------|------------------------|------------------------|--------------------------|
| **Reliability** | Low — depends on agent compliance | High — mechanical enforcement | Medium — only covers log_decision |
| **Maintenance cost** | Very low — docs only | Low — one bash script | Medium — plugin code + tests |
| **Developer friction** | None | Medium — blocks commits, requires fix-up | Low — transparent expansion |
| **Drift risk** | High — agents forget under context pressure | Very low — lint catches it | Medium — other surfaces still drift |
| **Implementation complexity** | Trivial | Low — regex + rg | Medium — plugin modification |
| **Surface coverage** | All 5 surfaces | Surfaces 1, 2, 3, 5 (not session logs) | Surface 4 only (session logs) |

### 2.2 Detailed Analysis

#### Approach 1: Convention Only
**Pros:**
- Zero implementation cost
- No developer friction
- Covers all surfaces

**Cons:**
- Relies on agent compliance — agents under context pressure (DIA-191, DIA-219) will forget
- No mechanical enforcement — drift is inevitable
- Historical evidence: AGENTS.md line 35 already documents the convention, but compliance is low (23 bare IDs in AGENTS.md itself)

**Verdict:** Necessary but insufficient. The convention must exist to guide agents, but without enforcement it's aspirational.

#### Approach 2: Lint Rule Now
**Pros:**
- Mechanical enforcement — fails CI on bare IDs
- Covers 4 of 5 surfaces (AGENTS.md, code comments, handoff files, README index)
- Low implementation cost — bash script with rg, ~50 lines
- Low maintenance — regex-based, no state
- Aligns with project pattern — already have validate-agent-names.sh, validate-changelog.sh, validate-decision-variants.sh

**Cons:**
- Developer friction — blocks commits with bare IDs, requires fix-up
- Does not cover session logs (messages.jsonl) — these are generated, not committed
- Requires allowlist for historical references (DIA-001 through DIA-234)

**Verdict:** Strong backstop. The friction is acceptable because it catches drift at commit time, not in production. The allowlist solves the historical reference problem.

#### Approach 3: Plugin Hook
**Pros:**
- Transparent — auto-expands bare IDs in log_decision calls
- No developer friction
- Covers session logs (the one surface the lint rule cannot)

**Cons:**
- Narrow surface coverage — only covers log_decision calls, not AGENTS.md, code comments, or handoff files
- Medium implementation cost — plugin modification, regex parsing, testing
- Does not solve the root problem — agents still write bare IDs elsewhere
- Creates inconsistency — session logs have expanded mentions, other surfaces have bare IDs

**Verdict:** Incomplete solution. The plugin hook covers only one surface while the problem spans five. The maintenance cost is not justified by the coverage.

---

## 3. Recommendation

### 3.1 Chosen Approach: Layered Defense (Approach 2 + Approach 1)

**Rationale:**
1. **Convention (Approach 1)** guides agents to write `DIA-NNN 'slug'` format from the start. This is the first line of defense — if agents comply, the lint rule never fires.
2. **Lint rule (Approach 2)** is the mechanical backstop. When agents forget (and they will, under context pressure), the lint rule catches it at commit time.
3. **Skip the plugin hook (Approach 3)** — it covers only one surface (session logs) while the problem spans five. The maintenance cost is not justified.

**Why not the plugin hook?**
- The plugin hook only covers log_decision calls (surface 4). It does not help with AGENTS.md (surface 1), code comments (surface 2), or handoff files (surface 3).
- Session logs are generated, not committed — the lint rule cannot cover them. But session logs are ephemeral (rotated, archived), while AGENTS.md and code comments are persistent. The persistent surfaces matter more.
- The plugin hook creates inconsistency — session logs have expanded mentions, other surfaces have bare IDs. This is worse than uniform bare IDs.

### 3.2 Implementation Sketch

#### 3.2.1 Convention (Approach 1)
**File:** AGENTS.md section 2.3 (Implementation)

**Add:**
```markdown
- **Ticket mention format:** when referencing DIA tickets in ANY context
  (AGENTS.md, code comments, handoff prognoses, dispatch payloads), ALWAYS
  use the format `DIA-NNN 'slug-from-filename'` (e.g., "DIA-190 'conspecter
  shelf edit permission'"). Derive the slug from the ticket filename
  DIA-NNN-<descriptor>.md. Bare IDs (DIA-190) are deprecated — they are
  opaque to the developer and fail the lint rule.
```

**Rationale:** The convention already exists in AGENTS.md line 35, but it's scoped to "user-facing output" (session summaries, handoff prognoses, batch approvals). Expand it to ALL contexts.

#### 3.2.2 Lint Rule (Approach 2)
**File:** scripts/validate-dia-mentions.sh

**Logic:**
```bash
#!/usr/bin/env bash
# validate-dia-mentions.sh - enforce DIA-NNN 'slug' mention format
# Exit 1 when bare DIA-NNN references are found (without slug).
# Allowlist: historical tickets DIA-001 through DIA-234 (grandfather policy).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Files to check (persistent surfaces, not session logs)
FILES=(
  "$ROOT/AGENTS.md"
  "$ROOT/apps/author-studio/AGENTS.md"
  "$ROOT/tools/opencode-docker/AGENTS.md"
)

# Allowlist: historical tickets (grandfather policy, DIA-234)
ALLOWLIST="DIA-(0[0-9]{2}|1[0-9]{2}|2[0-2][0-9]|23[0-4])"

# Find bare DIA-NNN references (without slug)
# Pattern: DIA-NNN not followed by ' or " (slug delimiter)
FOUND=0
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    continue
  fi
  
  # Extract bare DIA-NNN references (not in allowlist, not followed by slug)
  # rg pattern: DIA-\d+ not followed by ['"]
  BARE=$(rg -n 'DIA-\d+(?![\'"])' "$file" | while read -r line; do
    # Extract the DIA-NNN
    DIA=$(echo "$line" | rg -o 'DIA-\d+')
    # Check if it's in the allowlist
    if ! echo "$DIA" | rg -q "^${ALLOWLIST}$"; then
      echo "$line"
    fi
  done)
  
  if [[ -n "$BARE" ]]; then
    echo "ERROR: bare DIA-NNN references found in $file (missing slug):"
    echo "$BARE"
    FOUND=1
  fi
done

if [[ $FOUND -eq 1 ]]; then
  echo ""
  echo "Fix: use DIA-NNN 'slug-from-filename' format (e.g., DIA-190 'conspecter shelf edit permission')"
  exit 1
fi

echo "OK: all DIA mentions include slugs"
exit 0
```

**Integration:**
- Add to `make test-config` (runs on host, no container needed)
- Add to pre-commit hook (optional — may be too noisy during development)

**Allowlist rationale:** Historical tickets DIA-001 through DIA-234 keep their sequential IDs (DIA-234 grandfather policy). We do not migrate existing mentions. The allowlist prevents the lint rule from flagging historical references.

#### 3.2.3 Plugin Hook (Approach 3) — SKIPPED
**Rationale:** Narrow surface coverage (session logs only), medium implementation cost, creates inconsistency. The lint rule + convention cover the persistent surfaces that matter.

---

## 4. Migration Implications

### 4.1 Ticket ID Migration (DIA-234)
- **Decision:** No migration. Existing tickets DIA-001 through DIA-234 keep sequential IDs.
- **Rationale:** DIA-234 grandfather policy. No backward compatibility concern (critical infrastructure built by experimentation), but migration cost is high (231 tickets × multiple mentions each) with low benefit.

### 4.2 Mention Migration
- **Decision:** No migration of existing mentions.
- **Rationale:** 
  - Historical mentions are in committed files (AGENTS.md, code comments). Migrating them requires a large diff that touches many files.
  - The lint rule allowlist (DIA-001 through DIA-234) prevents false positives on historical references.
  - New content (new AGENTS.md sections, new code comments, new handoff files) must follow the convention.
  - Over time, historical mentions will be replaced naturally as files are updated.

### 4.3 Future Tickets (DIA-235+)
- **Ticket ID format:** DIA-YYMMDD-XXXX (datetime + random, per DIA-234)
- **Mention format:** DIA-YYMMDD-XXXX 'slug-from-filename' (per convention)
- **Lint rule:** applies to new tickets (not in allowlist)

---

## 5. Risk Assessment

### 5.1 Risk: Agent Non-Compliance
- **Likelihood:** High — agents under context pressure will forget the convention
- **Mitigation:** Lint rule catches it at commit time
- **Residual risk:** Low — the lint rule is the backstop

### 5.2 Risk: Lint Rule False Positives
- **Likelihood:** Low — allowlist covers historical tickets
- **Mitigation:** Allowlist is explicit (DIA-001 through DIA-234)
- **Residual risk:** Very low — allowlist is deterministic

### 5.3 Risk: Developer Friction
- **Likelihood:** Medium — lint rule blocks commits with bare IDs
- **Mitigation:** Clear error message with fix instructions
- **Residual risk:** Low — friction is acceptable because it catches drift early

### 5.4 Risk: Session Log Inconsistency
- **Likelihood:** Certain — session logs will have bare IDs (plugin hook skipped)
- **Mitigation:** Session logs are ephemeral (rotated, archived), not persistent
- **Residual risk:** Low — session logs are for debugging, not long-term reference

---

## 6. Implementation Plan

### Phase 1: Convention (1 hour)
1. Update AGENTS.md section 2.3 — expand ticket mention format to ALL contexts
2. Update .opencode/agents/*.md — add mention format to agent instructions
3. Test: dispatch a coder agent, verify it writes `DIA-NNN 'slug'` format

### Phase 2: Lint Rule (2 hours)
1. Write scripts/validate-dia-mentions.sh (regex + allowlist)
2. Add bats tests (scripts/__tests__/validate-dia-mentions.bats)
3. Wire into `make test-config`
4. Test: create a file with bare DIA-NNN, verify lint fails
5. Test: create a file with DIA-NNN 'slug', verify lint passes

### Phase 3: Validation (1 hour)
1. Run lint rule on existing AGENTS.md — verify allowlist works
2. Run `make test-config` — verify no regressions
3. Dispatch a coder agent on a new ticket — verify it writes `DIA-NNN 'slug'` format
4. Dispatch a reviewer agent — verify it writes `DIA-NNN 'slug'` format

### Total effort: 4 hours

---

## 7. Alternatives Considered

### 7.1 Alternative: Plugin Hook Only (Approach 3)
**Rejected:** Narrow surface coverage (session logs only), medium implementation cost, creates inconsistency.

### 7.2 Alternative: Migrate All Existing Mentions
**Rejected:** Large diff (231 tickets × multiple mentions), low benefit (historical mentions are in committed files, will be replaced naturally over time).

### 7.3 Alternative: Migrate All Existing Tickets to Datetime Format
**Rejected:** DIA-234 grandfather policy. Migration cost is high with low benefit.

### 7.4 Alternative: No Enforcement (Convention Only)
**Rejected:** Historical evidence shows low compliance (23 bare IDs in AGENTS.md itself). Convention is necessary but insufficient.

---

## 8. Conclusion

**Recommendation:** Layered defense — convention (Approach 1) + lint rule (Approach 2). Skip the plugin hook (Approach 3).

**Key decisions:**
1. No migration of existing tickets (DIA-234 grandfather policy)
2. No migration of existing mentions (allowlist in lint rule)
3. New content must follow the convention (enforced by lint rule)
4. Session logs will have bare IDs (plugin hook skipped, acceptable because session logs are ephemeral)

**Next steps:**
1. Implement Phase 1 (convention) — 1 hour
2. Implement Phase 2 (lint rule) — 2 hours
3. Implement Phase 3 (validation) — 1 hour
4. Register in memory shelf (delegate to @memory-manager)

**Artifact path:** `knowledge/ana01-dia-mention-format/ana01-dia-mention-format-report.md`

---

## Migration Decision: Full vs Grandfather

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: /home/qualt/Projects/poetry-platform/docs/dev-infra-audit/tickets/, scripts/tickets, .opencode/plugins/delegation-observer.ts
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

### Executive Summary

**Recommendation: Grandfather-Only (Option A)** — keep DIA-001 through DIA-234 with sequential IDs, new tickets use datetime format (DIA-YYMMDD-XXXX). No migration of existing tickets or cross-references.

**Justification:** Full migration costs 3-5 days of high-risk work for zero practical benefit. The sequential IDs carry historical value (creation order), and the tooling can support both formats with minimal complexity. Grandfather-only preserves this value while enabling the datetime format for new tickets.

---

### 1. Migration Scope Analysis

#### 1.1 Reference Count

```
Total DIA-NNN references: 10,229
Files with references: 634
Ticket files: 185 (DIA-045 through DIA-234)
```

#### 1.2 Reference Distribution (Top 15)

| File | References | Category |
|------|-----------|----------|
| `.opencode/session/messages.jsonl` | 1,609 | Auto-generated session log |
| `.opencode/session/messages.md` | 524 | Derived view (regenerable) |
| `.opencode/CHANGELOG.yaml` | 425 | Historical changelog |
| `.opencode/CHANGELOG.md` | 284 | Derived view (regenerable) |
| `.opencode/memory/lessons.md` | 217 | Historical lessons |
| `docs/dev-infra-audit/tickets/README.md` | 185 | Ticket index |
| `.opencode/plugins/delegation-observer.ts` | 176 | Plugin code |
| `.opencode/memory-shelf.yaml` | 157 | Knowledge index |
| `scripts/__tests__/worktrees.bats` | 148 | Test suite |
| `.scratch/shelf-backup-pre-rebase.yaml` | 145 | Backup (ephemeral) |
| `.scratch/merge-lane/readme-worktree-final.md` | 145 | Scratch (ephemeral) |
| `knowledge/ana029-*/ana029-*.md` | 132 | Analysis report |
| `.opencode/session/registry.jsonl` | 119 | Session registry |
| `.opencode/memory/adr.md` | 107 | Architecture decisions |
| `knowledge/ana027-*/ana027-*.md` | 91 | Analysis report |

#### 1.3 Categorization

| Category | Files | References | Migration Cost |
|----------|-------|------------|----------------|
| **Auto-generated** (session logs, derived views) | ~10 | ~2,500 | Skip (regenerate or leave as-is) |
| **Historical** (CHANGELOG, lessons, ADRs) | ~20 | ~1,200 | High risk, low value |
| **Ticket files** (frontmatter + cross-refs) | 185 | ~800 | Medium risk, medium effort |
| **Plugin code** (delegation-observer.ts) | 1 | 176 | Low risk, but requires regex updates |
| **Scripts** (tickets, tests) | ~5 | ~300 | Low risk, requires logic updates |
| **Knowledge artifacts** (analyses, conspects) | ~50 | ~1,500 | Medium risk, low value |
| **Ephemeral** (.scratch, backups) | ~10 | ~500 | Skip (delete or ignore) |

**Core migration scope:** ~400 references in ticket files + plugin + scripts. The remaining 9,800+ references are historical/auto-generated and should NOT be rewritten.

---

### 2. Tooling Impact

#### 2.1 Current Sequential Assumptions

**`scripts/tickets` line 212-240:**
```bash
next_dia() {
  local max=0 n f line
  for f in "$TICKETS_DIR"/DIA-*.md; do
    [ -e "$f" ] || continue
    n="$(num_of_file "$f")"
    [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
  done
  # ... README fallback ...
  printf '%03d' "$((max + 1))"
}
```
- Allocates next sequential number (max + 1)
- Parses numeric portion from filename: `DIA-123-foo.md` → `123`
- **Update needed:** support datetime format allocation

**`.opencode/plugins/delegation-observer.ts` line 1073:**
```typescript
const idMatch = /^DIA-(\d+)/.exec(entry)
```
- Extracts ticket ID from filename
- **Update needed:** support datetime format `DIA-YYMMDD-XXXX`

**`.opencode/plugins/delegation-observer.ts` line 2478:**
```typescript
if (!/^DIA-\d+$/i.test(ticketId)) {
```
- Validates ticket ID format
- **Update needed:** accept both sequential and datetime formats

**`.opencode/plugins/delegation-observer.ts` line 2500:**
```typescript
const match = /^DIA-(\d+)/i.exec(f)
```
- Extracts numeric ID from filename
- **Update needed:** support datetime format extraction

#### 2.2 Dual-Format Support Complexity

**Option A (Grandfather-Only):**
- Plugin regex: `/^DIA-(\d+|\d{6}-[a-z0-9]{4})/` — one regex, two capture groups
- `scripts/tickets`: branch on format prefix (sequential vs datetime)
- README index: mixed format (old sequential at top, new datetime appended)
- **Complexity:** Low — ~20 lines of code changes

**Option B (Full Migration):**
- Plugin regex: `/^DIA-(\d{6}-[a-z0-9]{4})/` — single format
- `scripts/tickets`: datetime allocation only
- README index: uniform datetime format
- **Complexity:** Low — but requires 400+ reference updates

**Verdict:** Dual-format support adds ~20 lines of code. Full migration saves no complexity but costs 3-5 days of work.

---

### 3. Risk Assessment

#### 3.1 Full Migration Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Incomplete migration (missed references) | High | High | Automated validation script |
| Broken cross-references (DIA-063 → DIA-260807-a1b2) | High | Medium | Manual review of all 185 tickets |
| Session log corruption (messages.jsonl) | Medium | Low | Skip auto-generated files |
| Historical context loss (DIA-001 was first) | Medium | High | Document mapping table |
| Test failures (worktrees.bats, tickets.bats) | Medium | High | Update test fixtures |
| Plugin regression (ticket gate breaks) | Blocker | Medium | Extensive testing required |

**Estimated effort:** 3-5 days (185 tickets × 10 min/ticket = 30 hours + testing + validation)

#### 3.2 Grandfather-Only Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Mixed format confusion | Low | Medium | Document both formats in AGENTS.md |
| README index ordering | Low | High | Sort by date (old sequential first, new datetime by date) |
| Tooling complexity (dual regex) | Low | Low | Single regex with alternation |

**Estimated effort:** 1 day (plugin regex update + scripts/tickets branch + documentation)

---

### 4. Historical Value

#### 4.1 Sequential IDs Preserve Creation Order

- DIA-001 through DIA-234 encode temporal ordering (DIA-001 was created first)
- This ordering is lost with synthetic datetime assignment (DIA-001 → DIA-260101-a001 is arbitrary)
- Sequential IDs enable quick mental models: "DIA-063 was early, DIA-234 is recent"

#### 4.2 Datetime IDs Encode Creation Date

- DIA-260819-a1b2 encodes creation date (2026-08-19)
- DIA-260101-a001 (synthetic) encodes nothing — it's a placeholder
- **Key insight:** synthetic datetime assignment for old tickets is misleading (DIA-001 was NOT created on 2026-01-01)

#### 4.3 Recommendation

Preserve sequential IDs for historical tickets (DIA-001 through DIA-234) because:
1. They encode real creation order
2. Synthetic datetime IDs are misleading
3. Migration cost is high, benefit is zero

---

### 5. Decision Matrix

| Criterion | Weight | Grandfather-Only | Full Migration |
|-----------|--------|------------------|----------------|
| Practical advantage | 25% | 7/10 (mixed format, but functional) | 8/10 (uniform format) |
| Migration cost | 25% | 9/10 (1 day) | 2/10 (3-5 days) |
| Risk | 20% | 9/10 (low risk) | 3/10 (high risk) |
| Tooling complexity | 15% | 7/10 (dual regex, ~20 lines) | 9/10 (single format) |
| Historical value | 15% | 10/10 (preserves creation order) | 1/10 (loses ordering, synthetic dates misleading) |
| **Weighted score** | **100%** | **8.3/10** | **4.9/10** |

**Winner: Grandfather-Only** (8.3 vs 4.9)

---

### 6. Implementation Plan (Grandfather-Only)

#### Phase 1: Plugin Update (2 hours)

Update `.opencode/plugins/delegation-observer.ts`:
- Line 1073: `/^DIA-(\d+|\d{6}-[a-z0-9]{4})/` — accept both formats
- Line 2478: `/^DIA-(\d+|\d{6}-[a-z0-9]{4})$/i` — validate both formats
- Line 2500: extract ID with format detection

#### Phase 2: Scripts Update (2 hours)

Update `scripts/tickets`:
- `next_dia()`: branch on format (sequential max+1 vs datetime generation)
- Add `--format sequential|datetime` flag (default: datetime for new tickets)
- README index: sort by date (old sequential first, new datetime by date)

#### Phase 3: Documentation (1 hour)

Update `AGENTS.md`:
- Document both formats: "DIA-001 through DIA-234 use sequential IDs; DIA-260819-a1b2 and later use datetime format"
- Update ticket reference convention: "DIA-NNN 'slug' for sequential, DIA-YYMMDD-XXXX 'slug' for datetime"

#### Phase 4: Validation (1 hour)

- Test plugin regex with both formats
- Test `scripts/tickets new` with datetime format
- Verify README index renders correctly
- Run `make test-config` to ensure no regressions

**Total effort:** 1 day (6 hours)

---

### 7. Rejected Alternative: Full Migration

**Why not full migration?**

1. **Cost:** 3-5 days vs 1 day (grandfather-only)
2. **Risk:** 400+ reference updates, high probability of incomplete migration
3. **No benefit:** dual-format support adds only ~20 lines of code
4. **Historical loss:** sequential IDs encode creation order; synthetic datetime IDs are misleading
5. **Session logs:** 1,609 references in messages.jsonl should NOT be rewritten (auto-generated)

**When would full migration make sense?**

- If sequential IDs caused tooling bugs (they don't)
- If datetime format enabled new features (it doesn't)
- If the migration cost was low (it's not)

**Verdict:** Full migration is a solution in search of a problem. Grandfather-only delivers the datetime benefit (TOCTOU race fix, DIA-234) without the migration cost.

---

### 8. Terminal Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│  DIA Ticket ID Migration: Grandfather-Only vs Full Migration    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Reference Distribution (10,229 total)                          │
│                                                                 │
│  Auto-generated (session logs)  ████████████████████  2,500     │
│  Historical (CHANGELOG, ADRs)   ██████████████       1,200     │
│  Knowledge artifacts            █████████████████    1,500     │
│  Ticket files (185)             █████████            800       │
│  Plugin code                    ██                   176       │
│  Scripts + tests                ████                 300       │
│  Ephemeral (.scratch)           ██████               500       │
│                                                                 │
│  ────────────────────────────────────────────────────────────   │
│                                                                 │
│  Migration Scope                                                │
│                                                                 │
│  Grandfather-Only:  ~400 refs (ticket files + plugin + scripts) │
│  Full Migration:    ~400 refs + 9,800 historical (DON'T DO)    │
│                                                                 │
│  ────────────────────────────────────────────────────────────   │
│                                                                 │
│  Decision Matrix                                                │
│                                                                 │
│  Criterion              Grandfather    Full       Winner        │
│  ─────────────────────────────────────────────────────────      │
│  Practical advantage    7/10           8/10       Full          │
│  Migration cost         9/10 ✓         2/10       Grandfather   │
│  Risk                   9/10 ✓         3/10       Grandfather   │
│  Tooling complexity     7/10           9/10       Full          │
│  Historical value       10/10 ✓        1/10       Grandfather   │
│  ─────────────────────────────────────────────────────────      │
│  Weighted score         8.3/10 ✓       4.9/10     GRANDFATHER  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 9. Recommendation

**Adopt Grandfather-Only (Option A):**

1. Keep DIA-001 through DIA-234 with sequential IDs (preserve historical value)
2. New tickets use datetime format DIA-YYMMDD-XXXX (fix TOCTOU race, DIA-234)
3. No migration of existing tickets or cross-references (avoid 3-5 days of high-risk work)
4. Update plugin regex and `scripts/tickets` to support both formats (~20 lines of code)
5. Document both formats in AGENTS.md (mixed format is acceptable)

**Rationale:** Grandfather-only delivers the datetime benefit (TOCTOU race fix) at 20% of the cost (1 day vs 3-5 days) with 10% of the risk. Full migration solves no real problem — dual-format support adds minimal complexity, and sequential IDs carry historical value that synthetic datetime IDs would destroy.

**Next steps:**
1. Implement Phase 1 (plugin regex update) — 2 hours
2. Implement Phase 2 (scripts/tickets branch) — 2 hours
3. Implement Phase 3 (documentation) — 1 hour
4. Implement Phase 4 (validation) — 1 hour
5. Register in memory shelf (delegate to @memory-manager)

**Artifact path:** `knowledge/ana01-dia-mention-format/ana01-dia-mention-format-report.md`
