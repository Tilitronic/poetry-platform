---
name: resolving-merge-conflicts
description: Use when you need to resolve an in-progress git merge/rebase conflict.
compatibility: opencode
metadata:
  audience: developers
  workflow: git-merge
  forkedFrom: mattpocock/skills
---

<!-- Forked from mattpocock/skills (MIT License, https://github.com/mattpocock/skills). Original Copyright (c) Matt Pocock. -->
<!-- Adapted for poetry-platform: the automated-checks step now runs OUR gates (make lint, make typecheck, turbo run test / pnpm test, make test-shell); Turborepo per-package gate awareness added. -->

# Resolving Merge Conflicts

1. **See the current state** of the merge/rebase. Check git history, and the conflicting files.

2. **Understand both intents.** Find the primary sources for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets. If either side's intent is ambiguous, ask — do not guess.

3. **Resolve each hunk by intent.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. **Run the project's automated checks.** This is a Turborepo monorepo — for conflicts, check which packages are affected and run the gates per-package (`turbo run <task> --filter=<package>`) as applicable:
   - `make lint`
   - `make typecheck`
   - `turbo run test` (or `pnpm test`)
   - `make test-shell`
   Fix anything the merge broke.

5. **Finish the merge/rebase.** Stage everything and commit. If rebasing, continue the rebase process until all commits are rebased.
