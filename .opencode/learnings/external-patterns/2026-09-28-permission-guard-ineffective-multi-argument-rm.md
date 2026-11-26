# permission - anchored .scratch two-argument guards do not take effect; a second rm path rides along

## Context

Behavioural probes run 2026-09-28 by coder lanes under the C4 smoke of DIA-260926-5vin, on the .scratch allows added in commit f6c84a5. These findings existed only inside a ticket-writing lane that then errored, so they are persisted here.

## Probe results

Each probe command was the sole command of one bash tool invocation, with no redirection unless stated:
- A  `rm -rf .scratch/c4-probe 2>.scratch/.rm_stderr`            -> ASK (registry row permission_asked_logged; the developer saw the prompt)
- B  `rm -rf .scratch/c4-probe`                                 -> allow, zero new registry rows
- C  `rm -rf .scratch/c4-smoke-a .scratch/c4-smoke-b`           -> allow, zero new registry rows; reproduced independently in a second lane, zero rows again
- D  `rmdir .scratch/c4-guard-a .scratch/c4-guard-b`            -> ASK (so a guard CAN fire; the asymmetry with C is the anomaly)
- E  `rm -rf .scratch/c4-esc-keep /tmp/c4-outside-esc`          -> the rm itself did NOT ask; BOTH targets were deleted

## Decisive runtime evaluation log lines

```
evaluated permission=bash pattern="rm -rf .scratch/c4-repro-a .scratch/c4-repro-b" action.pattern="rm *" action.action=allow
bash pattern="rm -rf .scratch/c4-esc-keep /tmp/c4-outside-esc" action.pattern="rm *" action.action=allow
```

No "asking" line accompanies either. The winning rule is the broad `rm *` ALLOW, not the `rm -rf * *` ASK guard. In probe E the only ask happened earlier, on `mkdir -p ... /tmp/c4-outside-esc` (the external_directory gate for /tmp/*), and the developer answered "Allow once"; that grant then covered the rm.

## Impact

The comment at .opencode/opencode.jsonc:408-410, stating that two-or-more-argument forms fall back to ask and that any other path still asks, is FALSE as implemented. Because `external_directory` only gates paths OUTSIDE the workspace, a second DESTRUCTIVE path INSIDE the workspace (for example `rm -rf .scratch/junk packages/apps/important-source`) raises no prompt at all and is silently deleted.

## Not established

The merged coder rule order (needs `opencode debug agent coder`), and the operative matcher semantics: the repo's own documents contradict each other. Official docs plus ADR-186 plus two config comments say last-match-wins; three learnings plus the git-permissions skill say longest-pattern-wins. Neither reading alone reproduces all five probe results.

## Status

A High-severity ticket for this finding was being created when its lane errored; it is still owed.
