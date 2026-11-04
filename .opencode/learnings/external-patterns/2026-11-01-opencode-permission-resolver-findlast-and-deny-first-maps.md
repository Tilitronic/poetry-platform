# OpenCode permission resolver: findLast semantics, deny-first maps, and analyzer over-grant findings

- Date: 2026-11-01
- Ticket: DIA-260827-ft3z (shell permissions bypass write scopes)
- Status: verified (every claim below was checked against shipped source, official docs, or `opencode debug agent` output)

## 1. Resolver semantics (refutes a claim still carried in the repo)

- OpenCode v1.18.32 (matches `opencode --version`) resolver lives at `packages/opencode/src/permission/index.ts`. Function `evaluate(permission, pattern, ...rulesets)` = `rulesets.flat().findLast(rule => Wildcard.match(...) && Wildcard.match(...)) ?? { action: "ask", permission, pattern: "*" }`. `merge()` = `rulesets.flat()`. `fromConfig()` converts config maps in object-key order, and a FLAT STRING value becomes `{permission: key, action: value, pattern: "*"}`.
- Official docs (https://opencode.ai/docs/permissions, fetched 2026-11-01): "Rules are evaluated by pattern match, with the last matching rule winning. A common pattern is to put the catch-all \"*\" rule first, and more specific rules after it." Agents section: "Agent permissions are merged with the global config, and agent rules take precedence."
- Merge order: built-in defaults -> global config -> agent rules appended LAST. Session "always" approvals appended after that, in-memory only.
- REFUTED: "longest-pattern-wins / deny beats allow regardless of position". The DIA-096 incident that appeared to prove it compared two IDENTICAL patterns (`git push *` vs `git push *`) - equal length cannot test specificity; it was plain findLast on merge order all along.
- Binary evidence note: `strings` is useless on the Bun single-file binary; use `grep -a -c findLast /usr/local/bin/opencode` (60 hits) if binary evidence is ever wanted.

### Stale carriers to correct later (do not edit now, listed for a follow-up pass)

- `.opencode/learnings/external-patterns/2026-08-11-git-permission-merge-semantics.md:11,37`
- `.opencode/skills/git-permissions/SKILL.md:21`
- `.opencode/opencode.jsonc:377-379` (and the coder comment at `:377-384` - the git denies there are correct only because they are POSITIONED after the allows, not because of specificity).

## 2. The trailing-flat-allow deny-evasion mechanism

- A flat `"bash": "allow"` on an agent becomes a trailing `{bash, *, allow}` rule. Under findLast it is the last match for EVERY bash input, so the global deny list (sudo, git destructive) and the rm/chmod/chown asks remain present in the resolved array but are DEAD for that lane.
- Observed at `.opencode/opencode.jsonc:289` (analyzer) and `:313` (analyzer-escalated). Verified via `opencode debug agent analyzer` (exit 0): global denies present mid-array, then agent flat allow last.
- General rule: ANY agent bash map without a leading `"*": "deny"` leaves the global deny list either dead (flat string) or non-binding (allow-list without catch-all).

## 3. Deny vs ask for unattended artifact lanes -> choose DENY

- ask without --auto = deterministic 5-minute stall then death (15 `permission_auto_rejected` rows, `no_human_response_within_threshold`, timeout_seconds 300 - `docs/dev-infra-audit/tickets/DIA-260926-5vin-*.md:50-51`).
- ask WITH --auto is silently AUTO-APPROVED (docs: "automatically approve permission requests that are not explicitly denied") - so an ask catch-all equals allow, the widest grant.
- deny returns DeniedError BEFORE any prompt or wait - clean, reportable failure, no stall.
- --auto does NOT cascade to child-session asks; the unattended fast-path (`.opencode/plugins/lib/permission-fast-resolve.ts`) only replies once/reject and is fail-closed.

## 4. Ordering and pattern traps (implementation-critical)

- The catch-all MUST be FIRST. If the LAST bash rule is `{pattern:"*", action:"deny"}`, `disabled()`/`visibleTools()` HIDE the bash tool entirely (DIA-126 ordering bug, fixed in `2faae73`; `.opencode/learnings/external-patterns/2026-08-13-bash-permission-wildcard-anti-pattern.md:14,21,29`).
- Matching is whole-value anchored: `*` = zero-or-more chars. `scripts/data-reduce.sh *` does NOT match `bash scripts/data-reduce.sh ...` - both prefixes must be granted.
- A bare pattern without a trailing ` *` denies all arg-bearing invocations.
- Flat-string permission values degrade to `{key, *, action}`; always use the nested-object form (DIA-154).

## 5. Layer separation

- `.opencode/plugins/lib/permission-fast-resolve.ts` is ONLY an unattended ASK fast-path (classifies already-pending asks, replies once/reject, fail-closed). It is NOT the rule resolver. All allow/deny ordering questions belong to core `evaluate()`.

## 6. Analyzer-specific findings

- The "Mermaid CLI + analysis tooling" justification at `.opencode/opencode.jsonc:277-280` is UNSUPPORTED: repo-wide grep for `mmdc|mermaid-cli|@mermaid-js` returns exactly one hit, and it is a risk note inside `knowledge/ana-260929-8t6u-...-report.md:185`, not an invocation. The mermaid-diagramming skill authors markdown blocks rendered by VS Code/GitHub/docs.
- `npx *` must never be granted to an artifact lane - it is a universal remote-code-execution channel (downloads and executes arbitrary packages), strictly wider than `python3 *`.
- `python3 *` is a universal write primitive (`python3 -c 'open(...,"w")'`) and reopens the write-scope hole this ticket exists to close; scope to `python3 .opencode/scripts/query_rag.py *` instead. Note `python3 *` does not match the skills' documented `python -c` form.
- console-charting inline Rich/plotext degrades to its documented no-python fallbacks (markdown table, Unicode block mapping, `console-charting SKILL.md:203-206`) once free python is denied.

### Doc drift to fix later (list only)

- `.opencode/agents/analyzer.md:21` and `analyzer-escalated.md:33` still say `bash: allow`.
- `.opencode/oh-my-opencode-slim.jsonc:331` says "bash (Mermaid CLI, terminal tools)".
- `.opencode/skills/data-reducer/SKILL.md:40` references `.opencode/scripts/jsonl-stats.sh` - that file DOES exist; it is scoped to the orchestrator session log (`.opencode/session/messages.jsonl`), not to an analyzer need (the earlier "does not exist" claim was false).

## 7. Durability boundary

- Session "always" approvals outrank ALL config rules on shipped v1.18.32 (in-memory, dies on restart; upstream #31540, #9554). Dev branch adds a configured-deny short-circuit (PR #45617) - not shipped. So no config-level fix is durable against one interactive "always"; keep the unattended fast-path never replying "always".

## 8. Cross-references

- DIA-260827-ft3z (parent - shell permissions bypass write scopes)
- DIA-260827-ld2l (memory-manager and designer over-granted permissions - same fix pattern)
- DIA-260928-rzty (permission guard ineffective on multi-argument rm - shared tool.execute.before seal)
- DIA-260926-5vin (unattended ask stalls)
- `knowledge/ana-260929-8t6u-knowledge-lane-trio-argument-b/` (prior independent audit flagging the same analyzer surface)

## Outcome

Outcome: pending implementation (update after DIA-260827-ft3z lands)
