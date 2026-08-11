---
name: git-permissions
description: Activate when working with git push, force push, destructive git commands, or branch protection - documents the safe vs destructive command split enforced by the OpenCode permission config (DIA-096).
compatibility: opencode
metadata:
  audience: agents
  workflow: git-workflow
---

# Git Permissions - Safe vs Destructive Split (DIA-096)

This skill is the documentation layer for the git push permission policy
enforced by the OpenCode permission config (`.opencode/opencode.jsonc`,
top-level `permission.bash` block, DIA-096). The config enforces; this skill
explains. Agents should consult this skill whenever a task involves `git
push`, force push, branch deletion, history rewriting, or any command listed
below as destructive.

## The Split

The permission config uses longest-pattern-wins matching. `"*": "allow"` is
the fallback, so anything not explicitly listed is allowed. Every command in
the deny lists below is blocked for agent tool calls; every command in the
safe list is allowed because it falls through to the allow rule.

## Project-Scoped Override (DIA-096)

This project INTENTIONALLY overrides the global OpenCode config
(`~/.config/opencode/opencode.jsonc`), which denies `"git push *"`, with a
project-scoped `"git push *": "allow"` in `.opencode/opencode.jsonc` (line 29).
OpenCode merges project config over global config (project-overrides-global
merge semantics), so within this repo agent tool calls may push feature
branches without asking. This is NOT a misconfiguration: safe pushes were
chosen to be frictionless for lanes. Every destructive form remains denied by
explicit patterns listed below, including `--all` / `--mirror` in both
flag-first and remote-first orderings, so main-push and force-push protection
is preserved. Future maintainers: keep the project allow line, and keep every
destructive deny pattern (both argument orders) alongside it.

### Safe (allowed, falls through to allow)

- `git push <branch>` - pushing a feature branch to its own upstream
- `git push -u origin <feature-branch>` - first push of a feature branch
- `git push` with no force flag and no main refspec
- `git pull` / `git fetch`
- `git commit` / `git add` / `git status` / `git diff` / `git log`
- `git merge` / `git rebase` on non-main branches (non-force)
- `git branch` create / list (non-force; `git branch -D` is denied)

### Destructive / denied (agent tool calls are blocked)

Force push in any position:

- `git push --force-with-lease *`, `git push --force *`, `git push -f *`
  and their argument-less forms, plus the ref-first variants
  (`git push * --force-with-lease *`, `git push * --force *`,
  `git push * -f *`, and their argument-less forms)

Push targeting main (only the developer may push to main):

- `git push origin main`, `git push origin main:*`,
  `git push * origin main`, `git push * origin main:*`

Branch deletion / history rewrite / destructive local ops:

- `git push --delete *` (and `git push origin --delete *`,
  `git push * --delete *`)
- `git reset --hard`
- `git clean -f*` (including `-fd`, `-fdx`)
- `git checkout -- .`
- `git restore .`, `git restore --staged .`
- `git branch -D *`
- `git filter-branch *`, `git filter-repo *`
- `git tag -d *`
- `git remote add/remove/set-url/prune/rename`

Still interactive (ask):

- `rm -rf *`, `rm *`, `rmdir *`, `chmod *`, `chown *`

## Main-Branch Rule

Only the developer may push to main. No agent lane may push to main, even
with a force flag or through an alias. Bypass forms that resolve to main are
also denied: `HEAD:main` refspecs, `--all` / `--mirror` pushes in BOTH
argument orders (flag-first `git push --all ...` / `git push --mirror ...`
and remote-first `git push <remote> --all ...` / `git push <remote> --mirror
...`, e.g. `git push origin --all`), plus-force refspecs (e.g. `+HEAD:main`),
and delete-by-refspec (`:main`). The permission
deny rules gate agent tool calls only; they never restrict the developer's
terminal. When a lane needs a main push, the lane must ask the developer to
run it manually.

## Safe-Push Cookbook for Lanes

1. Push a feature branch to origin (safe, allowed):

   ```bash
   git push -u origin <feature-branch>
   ```

   For an existing upstream, a plain `git push` is allowed.

2. Ask the developer to push when any of these apply:

   - The target branch is `main` (or the refspec resolves to main).
   - The push needs a force flag (`--force`, `-f`, `--force-with-lease`).
   - The task involves any denied command from the list above.

3. Before asking, stage everything so the developer only needs to run the
   push: commit locally, then hand over the exact command to run.

## Related Tickets

- DIA-096: this git push permission policy (config + this skill).
- DIA-094: the husky pre-commit hook runs on every commit; never bypass it
  with `--no-verify`.
- DIA-063: no engineering work starts without a DIA ticket.
