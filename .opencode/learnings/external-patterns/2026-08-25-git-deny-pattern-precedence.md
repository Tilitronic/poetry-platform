# Git deny-pattern precedence over broad agent allow-lists (2026-08-25)

- **Date:** 2026-08-25
- **Ticket:** DIA-260825-nts7 'permission: extend coder bash allow-list'
- **Source:** ai-specialist gate research (binding findings) + official docs https://opencode.ai/docs/permissions/ + prior learning `2026-08-11-git-permission-pattern-matching.md`
- **Trigger:** ai-auditor FAIL on commit 3fe6937 - CRITICAL destructive git forms passed the new broad coder/coder-escalated allows ("git branch *", "git checkout *", "git commit *").

## Finding

(a) **Matching semantics - longest-pattern-wins AND last-match-wins.** When
multiple bash permission rules match one command, the LONGEST matching pattern
decides (config order irrelevant); among equal-length matches the LAST one
wins. Official docs: https://opencode.ai/docs/permissions/. Consequence: a
specific deny beats a broad allow no matter where each sits in the map, so
`"git commit *": "allow"` + `"git commit --no-verify *": "deny"` resolves to
deny. This extends the 2026-08-11 learning (which established
longest-pattern-wins for the git push policy).

(b) **Trailing-space gotcha.** A pattern written `"git branch -D *"` (space
before `*`) requires at least one argument and does NOT match the argument-less
form `git branch -D`. Every deny of a command family must pair the starred form
with the bare form explicitly.

(c) **Flag-position variants.** Git accepts flags in multiple positions
(`git commit --no-verify -m x`, `git commit -m x --no-verify`,
`git commit -m x --no-verify -m y`). Covering them needs BOTH the flag-first
pattern (`"--flag *"`) AND the mid/end-of-command variants (`"* --flag *"`,
`"* --flag"`), plus the bare flag-only form. Same idiom already proven by the
global `git push * --force *` family.

(d) **Proven precedent in current config.** The allow-broad + deny-specific
split is already in production at the global level: `"git push *": "allow"`
coexists with `"git push --force *": "deny"` etc., and the deny wins by rule
(a). The coder/coder-escalated agent maps now use the identical structure.

## Outcome

Applied under DIA-260825-nts7: deny entries appended after the allows in both
coder and coder-escalated bash maps (--no-verify quartet, checkout-destructive
quartet, branch -D pair, plus re-stated global destructive denies since an
agent-level map does not inherit the global baseline). make test-config exit 0;
ai-auditor re-audit pending; ticket stays OPEN until re-audit passes.

## Tags

DIA-260825-nts7, permission-rules, longest-pattern-wins, last-match-wins,
trailing-space-gotcha, flag-position, deny-beats-allow, git-permissions,
opencode-config, pre-commit-bypass, no-verify
