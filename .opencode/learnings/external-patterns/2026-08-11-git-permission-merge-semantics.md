# OpenCode global + project permission merge semantics: a blanket global deny shadows project allow-lists (2026-08-11)

- **Date:** 2026-08-11
- **Source:** DIA-096 session-10 boot restart-verify FAIL (campaign c-20260809-residual-closure) - lane push of `omo-slim-changes` denied at boot despite the project-scoped allow committed in c8a2c5b; root-caused to global/project permission merge semantics; fixed by project-scoped override (c8a2c5b + 82d03d38); ai-auditor APPROVE (cycle 2).
- **Status:** IMPLEMENTED - project-scoped override committed, ai-auditor APPROVE, restart-verify pending at next boot.
- **Outcome note:** project-scoped `"git push *": "allow"` (c8a2c5b) + remote-first --all/--mirror deny closure (82d03d38) land at the next OpenCode boot; restart-verify re-scheduled; DIA-096 stays OPEN pending-validate until the lane push of `omo-slim-changes` succeeds with the new config live.

## Finding (permission merge semantics)

- **OpenCode merges global + project permission configs:** `~/.config/opencode/opencode.jsonc` (global) and `.opencode/opencode.jsonc` (project) are merged into one effective ruleset. Project same-key entries override global ones, but the merged rule set is evaluated as a whole - so a blanket deny in the GLOBAL config can still win over a project-level allow when the deny is more specific or matched later.
- **Rule evaluation uses specific-pattern / last-match semantics:** when multiple permission rules could match a command, the most specific matching pattern wins (longest-pattern-wins), and later denies in the merged order take precedence. This is why the global `{"permission":"bash","pattern":"git push *","action":"deny"}` (line 11 of the global config) shadowed the project's `"git push *": "allow"` - both patterns matched the lane push, and the deny won.
- **A blanket deny in the GLOBAL config shadows project-level allow-lists:** root cause of the DIA-096 session-10 restart-verify FAIL. A project-scoped allow that is textually identical to the global deny (`git push *`) does not neutralize it; the deny is the more restrictive match and wins in the merged ruleset. Fix direction: add the allow AND explicitly re-deny every bypass vector the allow would otherwise open.
- **Deny rules gate agent tool calls only:** the permission config applies to agent tool invocations; the developer's terminal is never blocked. Main-branch protection is a lane policy backed by deny rules, not a hard wall; developer manual confirmation is still required for pushes the lane cannot perform.

## Pattern (project-scoped override design)

- **Developer decision (DIA-096 session-10):** project-scoped override only; the global config is NOT touched. The global blanket deny stays for other projects; this project overrides it locally with `"git push *": "allow"` placed after the catch-all fallback and before all git denies (line 29).
- **Explicitly re-deny every bypass vector the allow opens:** ai-auditor cycle-1 REQUEST-CHANGES found the remote-first option-order variants (`git push origin --all` / `git push origin --mirror`) would have become allowed under the project override (main-push bypass regression). Fix: 6 deny patterns (`git push * --all *`, `git push * --all`, `git push origin --all`, `git push * --mirror *`, `git push * --mirror`, `git push origin --mirror`) at lines 82-87 + skill doc update stating --all/--mirror are denied in BOTH argument orders.
- **Every allow change needs a deny-list audit before it is trusted:** the merge semantics mean a newly-allowed command family can silently re-open destructive paths that were previously protected by a blanket deny; the ai-auditor cycle covers this.

## Source references

- https://opencode.ai/docs/config/ (global + project config merge)
- https://opencode.ai/docs/permissions/ (permission rules, specificity / ordering)
- GitHub issue #16157 and PR #14070 (permission merge / ordering semantics discussion)

## Outcome

- Commit c8a2c5b: `"git push *": "allow"` at line 29 of `.opencode/opencode.jsonc` (project-scoped).
- Commit 82d03d38: 6 remote-first --all/--mirror deny patterns (lines 82-87) + comment block (lines 78-81) + `.opencode/skills/git-permissions/SKILL.md` update.
- ai-auditor cycle 1 REQUEST-CHANGES (remote-first option-order gap) -> cycle 2 APPROVE (both findings verified-closed, no new observations).
- `make test-config` exit 0 both times; husky pre-commit passed; global config UNCHANGED; no push performed.
- Restart-verify re-scheduled at next boot: lane push of `omo-slim-changes` (16 commits ahead) succeeds; targeted denies confirmed; DIA-096 stays OPEN pending-validate - do NOT flip CLOSED.

## Reusable lesson

Permission configs are merged, not layered. A project-scoped allow cannot neutralize a blanket deny in the global config when both match the same command - the deny wins in the merged ruleset (specific-pattern / last-match semantics). Always verify the effective merged ruleset at boot (restart-verify), not just the project file, and treat every allow addition as a trigger to re-audit the deny list for bypass vectors (flag position, argument order, refspec forms).

## Tags

DIA-096, opencode-config, permissions, merge-semantics, global-vs-project, deny-shadowing, git-push, restart-verify, S10
