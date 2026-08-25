# Project Skills (`poetry-platform/.opencode/skills/`)

> **DIA-084 (2026-08-11) — skill-location reconcile.** This README documents
> the project-vs-global skill location convention that governs which skills
> live where, why, and how resolution works. See
> `docs/dev-infra-audit/tickets/DIA-084-artifacts-folder-audit.md` and
> `knowledge/ana010-artifacts-folder-audit/` for the audit and dispositions.

## Two-tier skill architecture

OpenCode loads skills from two locations, both of which appear in the runtime
`<available_skills>` registry:

| Location | Path | Scope | Resolved when |
|---|---|---|---|
| **Project** | `.opencode/skills/` (this directory) | This repo only | Working in `poetry-platform` |
| **Global** | `~/.config/opencode/skills/` | All projects for this user | Any project for this user on this machine |

The project tree is **tracked in git** and is the reproducible, shareable layer:
a fresh clone carries these skills with it. The global tree is **per-user, per
machine**: it is user-specific workflow preference and is NOT part of this
repo.

## Which skills live where (post-DIA-084)

### Project-pinned skills (22)

These resolve in this repo regardless of where the repo is cloned or run. Five
skills (`tdd-craftsman`, `teaching`, `mermaid-diagramming`, `console-charting`)
were **pinned at project level** from the global tree on 2026-08-11
so they load in CI / containers / other machines without this user's home
directory. Four overlapping skills (`book-rag`, `debugging-workflow`,
`git-diff`, `playwright-browser`) keep **project copies only** — the global
copies were deleted so the project versions load (the global copy of
`debugging-workflow` referenced disabled agents and shadowed the project
version — DIA-084 URGENT fix).

```
book-rag, code-review-fowler, console-charting, data-reducer,
debugging-workflow, domain-grilling, git-diff, git-permissions,
mermaid-diagramming, openspec-apply-change, openspec-archive-change,
openspec-explore, openspec-propose, openspec-sync-specs,
openspec-update-change, playwright-browser, research-pipeline,
resolving-merge-conflicts, review-re-verify, tdd-craftsman,
teaching, to-tickets
```

### Global-only skills (9, accepted as non-load-bearing)

These are user-specific workflow tools that intentionally stay in
`~/.config/opencode/skills/`. They are NOT required by this repo's build, CI,
or agent contracts, so they are accepted as non-load-bearing:

```
clonedeps, codemap, deepwork, oh-my-opencode-slim, reflect,
release-smoke-test, simplify, verification-planning, worktrees
```

> **`simplify` ownership note (DIA-260823-v9di):** `simplify` was removed from
> the project-pinned list; the global OMO tree
> (`~/.config/opencode/skills/simplify/`) is its single canonical source and the
> project copy was deleted as stale drift. It remains non-load-bearing for this
> repo (per DIA-084). If a future workflow makes it load-bearing, pin it at
> project level in the same change that adds the dependency.
>
> **Current state vs latent risk:** before deletion, `validate-skills.sh` emitted
> a SOFT warn-only near-duplicate (`warn: near-duplicate skill 'simplify'`, exit
> 0) — no current hard failure. The latent hazard was Tier-1 HARD: if the two
> copies ever became byte-identical, `make test-config` would fail (exit 1).
> Deleting the project copy removes it entirely, so neither the soft warn nor
> the latent hard risk can recur.

## Resolution order and the precedence ruling

**Precedence ruling (ai-specialist deeper research, Session 11):** when the
same skill name exists in BOTH locations, the **global copy shadows the
project copy** (global-wins). That shadowing is a bug when the global copy is
stale — the 2026-08-11 fix removed every global copy that duplicated a project
skill, so this repo now has **no name collisions**: every project skill
resolves to the project copy, and no project skill name exists globally.

Convention going forward:

1. **A skill lives in exactly ONE location.** Never add a same-named copy to
   the other tier — it will shadow (global over project) or be dead weight
   (project over global), and `make test-config` flags byte-exact duplicates
   as HARD failures.
2. **Project-relevant skills go in `.opencode/skills/`** (this directory),
   committed with the repo.
3. **Personal / machine-specific skills stay global** and are documented as
   non-load-bearing (see above). If a repo workflow ever depends on one, pin
   it at project level instead (copy in, remove the global copy).
4. `make test-config` runs `validate-skills.sh`, which checks frontmatter and
   cross-location duplicates. Keep this tree green.

## Risk outside this user home

Because the 9 global-only skills exist only in `~/.config/opencode/skills/`,
an OpenCode runtime **outside this home directory** (CI container, dev
container without the home mount, another developer's machine) will NOT
resolve them. Mitigation per DIA-084 disposition:

- All skills the repo actually needs for builds / tests / agent contracts are
  now **project-pinned** (22 above) and resolve anywhere.
- The 9 global-only skills are deliberately non-load-bearing: if a future
  workflow makes one of them load-bearing, pin it at project level (copy in +
  delete the global copy) in the same change that adds the dependency.
- `make test-config` must stay green; it is the gate that catches accidental
  reintroduction of duplicate skill names.
