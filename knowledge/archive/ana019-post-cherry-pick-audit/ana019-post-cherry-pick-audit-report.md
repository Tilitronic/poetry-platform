# Post-Cherry-Pick Audit: omo-slim-changes

**Branch:** `omo-slim-changes`
**Date:** 2026-08-11
**Auditor:** @analyzer
**Commit range:** Last 10 commits (head: `48f2255 fix(analyzer): F3 — pure-analyst to artifact-producer tier`)

---

## Executive Summary

```
+------+-------+---------------------------------------------------+
| #    | Check | Result                                            |
+------+-------+---------------------------------------------------+
| 1    | Conflict markers         | PASS                           |
| 2    | JSON/JSONC validity      | PASS                           |
| 3    | Agent name validation    | WARN  (script missing)         |
| 4    | Agent consistency        | PASS                           |
| 5    | Dangling skill refs      | PASS                           |
| 6    | Permission contradictions| FAIL  (openspec-plan)          |
| 7    | pnpm-lock.yaml           | FAIL  (stale lockfile)         |
| 8    | Orphan files             | PASS                           |
| 9    | Duplicate check          | PASS                           |
| 10   | opencode debug config    | WARN  (plugin path dup)        |
+------+-------+---------------------------------------------------+

  PASS: 7/10   WARN: 2/10   FAIL: 2/10   (estimated 20%)
```

---

## 1. Conflict Markers — PASS

Searched all tracked files for git conflict markers (`<<<<<<<`, `=======` at line start, `>>>>>>>`).

**Result:** No conflict markers found. Two matches in `packages/phonetics-core/` are docstring
visual separator lines (80-char `=====` underlines in Python module docstrings), not merge conflicts.

```
packages/phonetics-core/src/atlas/load_atlas.py:3:        ======================
packages/phonetics-core/scripts/generate_phonetic_atlas.py:4: ====================
```

**Verdict:** Clean. No action needed.

---

## 2. JSON/JSONC Validity — PASS

Validated with Node.js `JSON.parse()` after stripping JSONC comments and trailing commas.

| File | Status |
|------|--------|
| `.opencode/opencode.jsonc` | VALID |
| `.opencode/oh-my-opencode-slim.jsonc` | VALID |
| `.opencode/oh-my-opencode-slim/package.json` | VALID |
| `.opencode/memory-shelf.yaml` | VALID (PyYAML safe_load) |

Note: Python's `json` module rejects these files due to control character handling differences.
Node.js parses them correctly — the files are valid JSONC per the spec.

**Verdict:** Clean. No action needed.

---

## 3. Agent Name Validation — WARN

```
$ bash scripts/validate-agent-names.sh
bash: scripts/validate-agent-names.sh: No such file or directory
```

AGENTS.md section 9 references `scripts/validate-agent-names.sh` as the S1 enforcement script
for the 4-source agent-name lockstep contract. The script does not exist at that path. No
`scripts/` directory exists at the workspace root.

**Severity:** Medium — the contract documentation promises an automated enforcement mechanism
that does not exist. Agent name drift would go undetected.

**Fix recommendation:** Create `scripts/validate-agent-names.sh` that cross-checks:
- S1: AGENTS.md naming table
- S2: `.opencode/opencode.jsonc` agent block keys
- S3: `.opencode/oh-my-opencode-slim.jsonc` agents/preset/disabled_agents/council keys
- S4: `.opencode/agents/*.md` filename stems

---

## 4. Agent Consistency — PASS

Every agent in the AGENTS.md routing table has a corresponding definition in `opencode.jsonc`:

```
+---------------------+----------+
| Agent               | Status   |
+---------------------+----------+
| openspec-plan       | PRESENT  |
| conspecter          | PRESENT  |
| resource-manager    | PRESENT  |
| ai-specialist       | PRESENT  |
| ai-auditor          | PRESENT  |
| memory-manager      | PRESENT  |
| code-navigator      | PRESENT  |
| observer            | PRESENT  |
+---------------------+----------+
```

Full agent inventory in `opencode.jsonc` (18 agents):
`ai-auditor`, `ai-specialist`, `analyzer`, `architector`, `code-navigator`, `coder`,
`conspecter`, `council`, `designer`, `explore` (disabled), `general` (disabled),
`memory-manager`, `observer`, `openspec-plan`, `orchestrator`, `researcher`,
`resource-manager`, `reviewer`

**Verdict:** Clean. No action needed.

---

## 5. Dangling Skill References — PASS

Searched for three skills referenced in `oh-my-opencode-slim.jsonc`:

| Skill | Referenced in slim.jsonc | Exists in `.opencode/skills/` | Status |
|-------|:---:|:---:|--------|
| `teaching` | Lines 33, 77, 98, 108, 217, 236, 302, 327, 337 | YES | OK |
| `mermaid-diagramming` | Lines 36, 146, 181, 220, 305, 376 | YES | OK |
| `console-charting` | Lines 37, 147, 221, 306 | YES | OK |

Complete skill inventory:
- `.opencode/skills/` (13 skills): book-rag, console-charting, debugging-workflow, git-diff,
  mermaid-diagramming, openspec-{apply,archive,explore,propose,sync-specs,update-change},
  playwright-browser, teaching
- `oh-my-opencode-slim/src/skills/` (15 skills): clonedeps, codemap, deepwork,
  feature-interviewer, finishing-a-development-branch, grill-with-docs, loop-engineering,
  oh-my-opencode-slim, reflect, release-smoke-test, simplify, tdd-craftsman,
  verification-planning, worktrees

No overlap between the two directories.

**Verdict:** Clean. No action needed.

---

## 6. Permission Contradictions — FAIL

### Cross-reference: practice-protected.md tier table vs opencode.jsonc actual permissions

#### analyzer — PASS (artifact-producer)

```
Expected:  edit: knowledge/* + memory-shelf.yaml, bash: allow, task: deny
Actual:    edit: {"*":"deny","knowledge/*":"allow",".opencode/memory-shelf.yaml":"allow"},
           bash: "allow", task: "deny"
Match:     YES
```

#### ai-specialist — PASS (pure-analyst)

```
Expected:  edit: deny, bash: curl/wget only, task: deny
Actual:    edit: "deny", bash: {"curl":"allow","wget":"allow","*":"deny"}, task: "deny"
Match:     YES
```

#### openspec-plan — FAIL (artifact-producer mismatch)

```
Expected (practice-protected.md):
  "Classified artifact-producer. Bash scoped to openspec:*,
   edit scoped to openspec/ directory (proposal.md, design.md, tasks.md, specs/)"

Actual (opencode.jsonc):
  edit: "deny"
  bash: {"openspec":"allow", "*":"deny"}

Problem: edit is flat "deny" — no openspec/ scope.
```

**Severity:** HIGH — openspec-plan cannot write files to `openspec/changes/<name>/` as its
workflow requires (proposal.md, design.md, tasks.md, specs/). The practice-protected.md
contract promises scoped edit, but the runtime config denies all edits.

**Fix recommendation:** Change openspec-plan's edit permission to:
```json
"edit": {
  "*": "deny",
  "openspec/*": "allow"
}
```

#### resource-manager — PASS (artifact-producer)

```
Expected:  edit scoped to .opencode/oh-my-opencode-slim/knowledge/*
Actual:    edit: {"*":"deny",".opencode/oh-my-opencode-slim/knowledge/*":"allow"}
Match:     YES
```

---

## 7. pnpm-lock.yaml — FAIL

```
$ pnpm install --frozen-lockfile
ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml
is not up to date with <ROOT>/package.json

Failure reason:
  specifiers in the lockfile don't match specifiers in package.json:
  * 1 dependencies were added: typescript-eslint@^8.67.0
```

The root `package.json` declares `typescript-eslint@^8.67.0` as a devDependency, but the
`pnpm-lock.yaml` has not been updated to include this specifier. This means:
- CI with `--frozen-lockfile` (default in CI) will fail
- `pnpm install` in dev will silently update the lock, masking the drift

**Severity:** HIGH — CI builds will fail.

**Fix recommendation:** Run `pnpm install` in the workspace root to regenerate the lockfile,
then commit the updated `pnpm-lock.yaml`.

Note: `oh-my-opencode-slim` uses `bun.lock` (bun package manager), not pnpm. No staleness
issue there.

---

## 8. Orphan Files — PASS

| Path | Status | Notes |
|------|--------|-------|
| `.opencode/skills/frontend-design/` | Does NOT exist on disk | Referenced only in built-in `/app/.config/opencode/skills/` (external to repo) |
| `.opencode/skills/writing-skills/` | Does NOT exist on disk | Same — built-in path only |
| Untracked files in `.opencode/` | Only `.opencode/session/` | Expected (runtime session data) |

All `.opencode/skills/` directories are git-tracked. No orphaned remnants.

**Verdict:** Clean. No action needed.

---

## 9. Duplicate Check — PASS

### Skills

```
Intersection of .opencode/skills/ and oh-my-opencode-slim/src/skills/: (empty)
```

No duplicate skill names between the two directories. The two skill sets are complementary.

### Agents

```
Overlap of agent names between opencode.jsonc and oh-my-opencode-slim.jsonc: 0
```

All 18 agents defined exclusively in `opencode.jsonc`. The slim config has zero agent
definitions (it contributes via presets, not agent blocks).

### Plugins (from debug config)

```
Plugins (7):
  1. file:///app/ponytail/.opencode/plugins/ponytail.mjs
  2. file:///app/plugins/opencode-snip/.opencode/plugins/index.ts
  3. envsitter-guard@0.0.4
  4. @tarquinen/opencode-dcp@3.1.14
  5. file:///workspace/.opencode/oh-my-opencode-slim
  6. file://./.opencode/plugins/delegation-observer.ts
  7. file:///workspace/.opencode/plugins/delegation-observer.ts
```

Plugins 6 and 7 resolve to the same file via different paths (relative `file://./` vs absolute
`file:///workspace/`). Not a config duplicate — `opencode.jsonc` has only one entry — but the
runtime resolves it as two distinct plugin origins. Potential double-load risk.

**Severity:** Low-medium — may cause the delegation-observer plugin to load twice, leading to
duplicate event handling.

**Fix recommendation:** Consolidate to one absolute path in `opencode.jsonc`. Remove the
`file://./.opencode/plugins/delegation-observer.ts` entry (or the absolute one) to prevent
double resolution.

---

## 10. opencode debug config — WARN

### Plugin loading

```
✅ omo plugin loads from: file:///workspace/.opencode/oh-my-opencode-slim
✅ openspec-plan agent is present
✅ analyzer has correct permissions (edit scoped, bash allow)
```

### Permission block audit

Three agents have no permission block:
- `explorer` (disabled OMO alias)
- `explore` (disabled built-in)
- `general` (disabled built-in)

**Severity:** Low — these are all disabled agents. No runtime impact. The debug config shows
their permission as `{}` which is correct for disabled entries.

### Delegation-observer double resolution

As noted in check 9, the debug config shows two `plugin_origins` entries for delegation-observer:
```json
{ "spec": "file://./.opencode/plugins/delegation-observer.ts", "scope": "local" }
{ "spec": "file:///workspace/.opencode/plugins/delegation-observer.ts", "scope": "local" }
```

This is a path resolution artifact — the config has one entry, but it resolves to two origins.

---

## Summary Table

| # | Check | Result | Severity | Action Required |
|---|-------|--------|----------|-----------------|
| 1 | Conflict markers | PASS | — | None |
| 2 | JSON/JSONC validity | PASS | — | None |
| 3 | Agent name validation | WARN | Medium | Create `scripts/validate-agent-names.sh` |
| 4 | Agent consistency | PASS | — | None |
| 5 | Dangling skill refs | PASS | — | None |
| 6 | Permission contradictions | **FAIL** | **HIGH** | Fix openspec-plan edit scope |
| 7 | pnpm-lock.yaml | **FAIL** | **HIGH** | Regenerate lockfile |
| 8 | Orphan files | PASS | — | None |
| 9 | Duplicate check | WARN | Low | Consolidate delegation-observer path |
| 10 | opencode debug config | WARN | Low | Review disabled-agent permission blocks |

## Priority Fixes

1. **openspec-plan edit permission** — Add `"openspec/*": "allow"` scope to edit block. Without
   this, openspec-plan cannot write the spec artifacts it's designed to produce.
2. **pnpm-lock.yaml** — Run `pnpm install` and commit the updated lockfile. CI will fail
   otherwise.
3. **delegation-observer path** — Consolidate to a single absolute path to prevent potential
   double-load.
4. **validate-agent-names.sh** — Create the enforcement script documented in AGENTS.md section 9.

---

*Report generated by @analyzer. Registered in memory-shelf under `shelf.analyses`.*
