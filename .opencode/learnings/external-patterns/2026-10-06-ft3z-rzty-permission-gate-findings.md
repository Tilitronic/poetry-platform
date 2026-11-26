---
date: 2026-10-06
topic: Permission gate findings - matcher semantics (last-match-wins), rm two-arg guard diagnosis (DIA-260928-rzty), fetch-wrapper migration order (DIA-260827-ft3z)
source: ai-specialist section-2.5 Phase 1 gate, both campaign tickets
ticket: DIA-260827-ft3z, DIA-260928-rzty
status: registration-only
---

# Section-2.5 gate findings: permission matcher semantics + rm guards + fetch wrapper (DIA-260827-ft3z / DIA-260928-rzty)

Scope: registration of @ai-specialist research findings (AGENTS.md section
2.5, step 1). No config changes, no permission fixes, no implementation in
this file.

## 1. Matcher semantics (DECISIVE - opencode v1.18.32 upstream source + official docs)

1. `evaluate()` uses `findLast` over the merged rule array => **LAST-MATCH-WINS
   in array order**, NOT longest-pattern-wins. When nothing matches, the
   fallback is **ask**.
2. Wildcard match is **anchored** (`^...$`): `*` translates to `.*`, and a
   trailing `" *"` makes that trailing part **OPTIONAL** (so `"rm * *"`
   also matches a single-argument `rm ...`).
3. Agent rules are appended AFTER global config (merge order: defaults ->
   global -> agent), so **agent rules win over global**.
4. Session "always" approvals are appended LAST (the `approved` ruleset) and
   therefore **outrank ALL config rules**.
5. THREE repo documents wrongly claim longest-pattern-wins and need
   correction later (registration only here):
   - `.opencode/skills/git-permissions/SKILL.md:21`
   - `.opencode/learnings/external-patterns/2026-08-11-git-permission-pattern-matching.md:19`
   - `.opencode/opencode.jsonc:356-358` (comment at :358 says
     "longest-pattern-wins regardless of position")

## 2. DIA-260928-rzty - rm two-arg guard findings

### 2.1 Ticket refs stale; verified current config

- coder block `.opencode/opencode.jsonc:329-413`:
  - anchored .scratch allows at `:403-406` (4 keys: `rm -rf /workspace/.scratch/*`,
    `rm -rf .scratch/*`, plus the two rmdir forms)
  - false comment at `:407-409` (claims two-or-more-argument forms fall back
    to ask and "any other path still asks" - FALSE as implemented)
  - two-arg asks at `:410-412` (`rm -rf * *`, `rm * *`, `rmdir * *`)
- coder-escalated block `:433-503`:
  - anchored allows at `:493-496`, two-arg asks at `:500-502`
- grep: **no `"rm *": "allow"` exists anywhere in repo config** (only the
  global `"rm *": "ask"` at `:113` and the `rm * *` asks above).

### 2.2 Probe explanation [INFERENCE, Medium]

Probes A-E from the 2026-09-28 evidence file are most likely explained by a
SESSION "always" rm grant (from probe A, arity prefix `rm *`), NOT by any
config rule: session `approved` rules append last and outrank config
(section 1, item 4), which reconciles the observed `action.pattern="rm *"
action=allow` runtime log lines with the absence of any config allow.

- Exact merged rule array is **UNVERIFIED**: @ai-specialist has bash deny and
  could not run `opencode debug agent coder`. Confirmation needs a
  fresh-session `opencode debug agent coder` run.

### 2.3 Config-only fix IMPOSSIBLE (rejected variants)

- Glob patterns cannot count arguments.
- `"rm * *"` also matches single-argument rm (trailing `" .*"` is optional).
- Rejected: reorder allows (worse, still last-match roulette);
  remove `rm *` allow (none exists in config);
  `"rm * *": "deny"` (would deny ALL flag-bearing rm).

### 2.4 Recommended fix (not implemented here)

- Delete the 4 anchored allows + 3 two-arg asks from BOTH agents
  (coder `:403-412`, coder-escalated `:493-502`), fix the false comment
  (`:407-409` / `:497-499`).
- Add a bash branch to `tool.execute.before`: reuse `isProtectedPath()`
  (delegation-observer.ts:1509) for path targets, and extend the
  arg-counting tokenizer in `.opencode/plugins/lib/permission-fast-resolve.ts:62-78`
  to all modes (it currently guards only the unattended rm allow-sublist).

### 2.5 Companions

- Correct `.sdd/scratch-lifecycle/architecture.md` ADR-001 decision item :26
  (its status line already says superseded(partial); the decision item text
  still carries the old claim).
- Commit the still-untracked evidence file
  `.opencode/learnings/external-patterns/2026-09-28-permission-guard-ineffective-multi-argument-rm.md`.

## 3. DIA-260827-ft3z - curl/wget write-scope bypass, fetch-wrapper migration

### 3.1 Current config (ticket refs are STALE)

- researcher `.opencode/opencode.jsonc:524-541` - bash map at `:532-538`
  (`curl *`/`wget *`/`trafilatura *`/`crwl *` allows at `:534-537`,
  `"*": "deny"` first at `:533`)
- resource-manager `:625-642` - bash map at `:634-639` (curl/wget/trafilatura
  at `:636-638`)
- coder broad interpreters `:350-354` (`node *`, `bun *`, `python3 *`) -
  **out of scope** (separate ticket, per prior developer scoping)

### 3.2 No existing fetch wrapper

Checked `scripts/`, `.opencode/tools/`, `.opencode/scripts/query_web.py`:
nothing to reuse. The wrapper must be created.

### 3.3 Migration order is wrapper-FIRST

Removing the curl/wget allows BEFORE `scripts/fetch-source` exists breaks
researcher Phase A (the `sources/` archive + `.source-urls.txt` checkpoint,
`.opencode/agents/researcher.md:45,52-54` and the Phase A hard rule).

### 3.4 Recommended minimal fix (not implemented here)

1. New `scripts/fetch-source <url> <artifact-dir> [slug]` (~15-20 lines,
   realpath containment under `knowledge/*/sources`).
2. Replace the four allows in both agents with
   `"scripts/fetch-source *": "allow"`.
3. Update `.opencode/agents/researcher.md:45,52-54` and
   `.opencode/skills/research-pipeline/SKILL.md:20-22` (the 3-tier chain
   currently names curl/trafilatura/crwl directly).

### 3.5 Shared root cause with rzty

Neither ticket has any bash pre-execution path/argument validation. The SAME
`tool.execute.before` bash branch addresses both, and also closes the
editor-interpreter route (coder `node *`/`bun *`/`python3 *` allows).

## 4. Sources (verified against the tree, 2026-10-06)

- `.opencode/opencode.jsonc` (:113, :350-358, :399-412, :489-502, :524-541, :625-642)
- `.opencode/agents/researcher.md` (:45, :52-54, Phase A rule :59-65)
- `.opencode/skills/research-pipeline/SKILL.md` (:17, :20-22, :89-90)
- `.opencode/plugins/lib/permission-fast-resolve.ts` (:62-78 arg tokenizer)
- `.opencode/plugins/delegation-observer.ts` (:1509 `isProtectedPath`)
- `.sdd/scratch-lifecycle/architecture.md` (ADR-001 decision item :26)
- `.opencode/learnings/external-patterns/2026-09-28-permission-guard-ineffective-multi-argument-rm.md` (probe A-E evidence, untracked)
- `.opencode/learnings/external-patterns/2026-09-10-shell-redirection-write-scope-bypass.md` (ft3z predecessor entry)
- opencode v1.18.32 upstream matcher source + official docs (fetched by @ai-specialist this session)

Outcome: PENDING (by design - registration only; implementation is a later
step-4/5 dispatch under AGENTS.md section 2.5, after developer review)

## Tags

DIA-260827-ft3z, DIA-260928-rzty, opencode-config, permissions,
last-match-wins, findLast, session-approved-outranks-config, rm-guard,
fetch-source-wrapper, tool.execute.before, bash-pre-exec-validation,
S10, ai-specialist-gate
