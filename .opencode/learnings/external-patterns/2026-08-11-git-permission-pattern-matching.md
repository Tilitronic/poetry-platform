# OpenCode permission-rule matching semantics + git push deny-list design (2026-08-11)

- **Date:** 2026-08-11
- **Source:** DIA-096 (git push permission policy - allow push, restrict destructive commands and main) - developer directive 2026-08-11 filed by the coder lane; Option A+B implemented by coder lane (commits 31a6cce2 + 1759575); S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED + ai-auditor APPROVE-WITH-NITS (cycle 2, Major finding verified-closed); session-10 project-scoped override committed (c8a2c5b + 82d03d38) with ai-auditor APPROVE (cycle 2); restart-verify re-scheduled (next OpenCode boot) after the session-10 item-1 FAIL.
- **Outcome note:** safe branch push now allowed (falls through to catch-all allow) while force-push / main-push / destructive commands are explicitly denied; session-10 added the project-scoped override (global blanket deny was shadowing the project allow-list in the merged ruleset - see `2026-08-11-git-permission-merge-semantics.md`) and closed the remote-first --all/--mirror option-order nit; ticket DIA-096 stays OPEN pending-validate until the next-boot restart-verify (lane push succeeds; force-push / main-push / bypass forms denied; developer terminal push unaffected; make test-config exit 0) is confirmed.

## Ticket

- **DIA-096** (Major, OPEN pending-validate) - "Git push permission policy - allow push, restrict destructive commands and main".
- **Related:** DIA-094 (husky pre-commit / docker gate - commit gate not weakened), DIA-063 (ticket gate), DIA-095 (S10-routed AGENTS.md/config change pattern).

## Topic

- OpenCode permission-rule matching semantics and the deny-list design approach for git push (safe vs destructive split, main-branch protection).

## Finding (permission-rule matching semantics)

- **Longest-pattern-wins:** when multiple bash permission rules could match a command, the longest matching pattern decides. Order in the config is irrelevant; pattern length is the tie-breaker.
- **`git push *` trailing-space optimization:** the old blanket deny was written as `git push *` (trailing space). That pattern matches any push with at least one argument but NOT the bare form `git push` - hence the "trailing-space optimization" idiom: the space-less bare command escapes the pattern and can be matched separately. Any deny of a command family should pair the argument form with the argument-less form explicitly.
- **Default unmatched = ask:** in the bash permission block, a command matched by no explicit rule falls through to the fallback `"*": "allow"` if present, otherwise to the platform default. With `"*": "allow"` as the catch-all, everything not explicitly denied is allowed - so the policy must enumerate the destructive split rather than relying on implicit denies.
- **Deny rules gate agent tool calls only:** the permission config applies to agent tool invocations; it never restricts the developer's own terminal. This is why a lane that needs a main push must ask the developer to run it manually - the deny list cannot (and should not) block the developer.

## Pattern (git push deny-list design)

- **Safe vs destructive split:** enumerate safe operations (feature-branch push, `-u` first push, pull/fetch, commit/add, read-only, non-force merge/rebase/branch) that fall through to allow, and destructive operations that get explicit denies. Never rely on implicit defaults.
- **Force-push in any position:** deny `--force`, `-f`, `--force-with-lease` both as leading flags (`git push --force *` + argument-less) and as ref-first variants (`git push * --force *` + argument-less), because git accepts the flag in either position.
- **Main-branch protection must cover bypass vectors, not just `git push origin main`:** the ai-auditor cycle-1 Major finding was that five bypass forms resolved to main while only the direct form was denied:
  1. `HEAD:main` refspecs (`git push origin HEAD:main`, `git push * HEAD:main`)
  2. `--all` pushes (`git push --all *` + argument-less)
  3. `--mirror` pushes (`git push --mirror *` + argument-less)
  4. plus-force refspecs (`git push origin +*:main`, `git push * +*:main`)
  5. delete-by-refspec (`git push origin :main`, `git push * :main`)
- **Remaining accepted caveats (ai-auditor cycle-2 nits):** option-order variants (`git push <remote> --all` / `git push <remote> --mirror`) are not yet covered and should be verified at next boot; the upstream-main caveat (a branch whose upstream is main can be updated by a bare `git push` because git then resolves the upstream ref) was accepted by design since a bare `git push` falls through to allow.

## Outcome

- Commit 31a6cce2: config deny-list replacing the blanket `git push *` deny (safe push falls through to catch-all allow; force-push / main-push / destructive commands explicitly denied; rm/chmod/chown stay ask) + companion `.opencode/skills/git-permissions/SKILL.md` documentation layer.
- Commit 1759575 (ai-auditor cycle-1 fix): 10 deny patterns closing all 5 main-push bypass vectors (HEAD:main x2, --all x2, --mirror x2, +*:main x2, :main x2) + skill doc line covering the bypass forms.
- ai-auditor cycle 2 VERDICT APPROVE-WITH-NITS: Major finding verified-closed, RESTART_VERIFY_READY yes. Non-blocking: option-order variants to verify at next boot; upstream-main caveat accepted by design.
- Restart-verify PENDING (S10 Phase 5): on next OpenCode boot, a lane push of a feature branch should succeed, force-push / main-push / bypass forms should be denied, the developer terminal push should be unaffected, and `make test-config` should exit 0. Ticket stays OPEN pending-validate - do NOT flip to CLOSED.
- **Session-10 resolution (2026-08-11, DIA-096):** boot restart-verify item 1 FAIL - lane `git push -u origin omo-slim-changes` denied by the GLOBAL blanket `git push *` deny (`~/.config/opencode/opencode.jsonc` line 11) shadowing the project allow-list in the merged ruleset (see `2026-08-11-git-permission-merge-semantics.md`). Fix: commit c8a2c5b (project-scoped `"git push *": "allow"` at `.opencode/opencode.jsonc` line 29) + commit 82d03d38 (6 remote-first option-order deny patterns at lines 82-87: `git push * --all *` / `git push * --all` / `git push origin --all` / `git push * --mirror *` / `git push * --mirror` / `git push origin --mirror` + comment block 78-81 + git-permissions skill doc update). ai-auditor cycle 1 REQUEST-CHANGES (remote-first option-order gap) -> cycle 2 APPROVE (both findings verified-closed). This closes the previously-accepted option-order nit from the cycle-2 APPROVE-WITH-NITS. `make test-config` exit 0 both times; husky pre-commit passed; global config UNCHANGED; no push performed. Restart-verify re-scheduled at next boot - DIA-096 stays OPEN pending-validate (session-10 item 1 FAILed, so the restart-verify has NOT fully passed yet).

## Reusable lesson

When writing git (or any command-family) permission denies, think in bypass vectors, not canonical forms. A deny list that only matches the textbook invocation (`git push origin main`) leaves every alias and refspec variant open: HEAD refspecs, --all/--mirror flags, plus-force refspecs, delete-by-refspec, and flag-position variants. Enumerate the flag in every position and every argument ordering git accepts. And remember the two asymmetries that make permission rules surprising: longest-pattern-wins (not first-match, not config order) and the trailing-space trick that lets a bare command escape a `*`-suffixed pattern. Finally, the config only gates agent tool calls - the developer's terminal is never blocked, so main protection is a lane policy backed by the deny list, not a hard technical wall.

## Tags

DIA-096, git-push, permission-rules, longest-pattern-wins, deny-list, main-branch-protection, bypass-vectors, HEAD:main, --all, --mirror, force-push, git-permissions, opencode-config, S10, restart-verify-pending
