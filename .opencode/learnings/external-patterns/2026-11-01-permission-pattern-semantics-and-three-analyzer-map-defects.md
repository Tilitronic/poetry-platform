# Permission pattern semantics and three defects in the analyzer bash map (2026-11-01)

## Context
An independent audit of commits 36f3eb6 and 9ff2b8c (range fa2555d..HEAD) found the deny-first bash map shipped by 36f3eb6 to be simultaneously too tight for the analyzer lanes' contracted tooling and too loose as a security boundary. A read-only research gate then settled the matcher semantics from shipped source and surfaced a third defect.

## Verified matcher semantics (source, not inference)
- The wildcard helper compiles a pattern to an anchored regex: specials escaped, `*` to `.*`, `?` to `.` (opencode packages/opencode/src/util/wildcard.ts). A pattern ending in ` *` is rewritten to make the trailing part optional, so one rule `X *` matches both `X` and `X <anything>`.
- Because the dot matches newlines, `*` spans multiple whitespace-separated arguments. `git commit -m foo` matches `git *`.
- Wildcards are valid at any position, not only at the end. Mid-pattern rules are syntactically accepted.
- The permission resolver evaluates merged rulesets with findLast, so the LAST matching rule wins. This confirms the deny-first requirement: catch-all deny first, narrow allows after, and any negative re-assertions LAST.
- The bash tool derives permission patterns from the RAW COMMAND TEXT, and compound commands are split into separate patterns that must all pass. Therefore `helper && evil` is denied.
- UNVERIFIED for the shipped binary: whether shell command substitution inside matched text is decomposed into its own pattern. Source review indicates it is NOT on the current generation, which means `helper $(evil)` could match the helper allow while the shell still executes the substitution. A live probe is mandatory before relying on pattern-level sealing.

## Defect 1 - the map blocks the lane's contracted output tool
Both analyzer lanes are assigned the console-charting skill, whose prescribed invocation is `python -c "..."` for Rich tables/trees/panels and Plotext/asciichartpy/termplotx/termatplotlib charts. No pattern in the seven-item allow list matches any `python -c` or `python3 -c` form, and the catch-all deny is last-matching, so every chart step is denied at runtime while the agent document still advertises `bash: allow`.

CLOSED (2026-11-04, DIA-260827-ft3z): both halves of the claim above are false
now, kept as history. The agent documents no longer advertise `bash: allow` -
`analyzer.md` and `analyzer-escalated.md` state the deny-first enum (jq, rg,
wc, the data-reduce wrapper, the fixed-path query_rag.py helper, the four
read-only openspec subcommands), and the preset prompt states the same
enumerated grant. The interpreter need is gone too: console-charting was
de-scoped from every agent (`!console-charting` in oh-my-opencode-slim.jsonc),
so no analyzer chart step asks for `python -c` any more.

## Defect 2 - the data-reduce pass-through defeats the map
`bash scripts/data-reduce.sh *` and `scripts/data-reduce.sh *` are allows. The script collects everything after `--` into a command array and executes it argv-direct, so `bash scripts/data-reduce.sh /dev/null -- python3 -c "<anything>"` matches an allowed prefix and runs arbitrary code. Lesson: the pattern layer sees only raw command text and cannot pin a script's own argument semantics. The boundary must live at the script layer, where the command boundary is visible.

CLOSED at the script layer (2026-11-04): `scripts/data-reduce.sh` now rejects
any reducer whose first element is not on its bare-name allowlist (jq, rg, wc,
head, tail, cut, tr, uniq), so the `-- python3 -c ...` pass-through exits 2
before it can execute. The two pattern allows remain by design - the wrapper
itself is still the sanctioned entry point.

## Defect 3 - a write-anywhere primitive was allow-listed
`scripts/session-log *` was an allow on both analyzer lanes although neither lane's skills nor prompt name it. Its `--output` argument is unrestricted and its render path writes that path atomically, so it can overwrite any workspace file - for example overwriting an allowed-path helper - which bypasses the lane's edit restriction entirely. Any allow for a script whose arguments can name a write destination is a write grant, not a read grant.

CLOSED (2026-11-04): the allow is gone from both analyzer maps - `scripts/
session-log` was removed as an unreferenced pure write grant - and the render
path independently refuses an `--output` that does not resolve inside
`.opencode/session/`.

## Gaps found in the same map
- The lanes carry the openspec-explore skill, which mandates read-only openspec CLI calls (list, status, show, context), none of which were allowed. Allowing the whole `openspec` binary would be wrong because it also has writing subcommands.
- `.opencode/scripts/jsonl-stats.sh` DOES exist and was mis-recorded as missing in the earlier 2026-11-01 deny-first-maps learning; it is scoped to the orchestrator, not an analyzer need.
- The Mermaid CLI justification in the agent prose is unsupported: mermaid-diagramming authors markdown blocks and needs no CLI. CLOSED (2026-11-04): the justification is no longer present anywhere - not in the agent prose, not in the preset prompt, not in the config comment - and check B now forbids `Mermaid CLI` / `mmdc` on every in-scope agent doc surface.
- Blast radius: console-charting is assigned to three lanes across two presets (architector, analyzer, analyzer-escalated). Only the two analyzer lanes have interpreter access, so only they gain anything from a chart helper; architector and the orchestrator must keep using the skill's no-interpreter fallback table.

## Transferable rules
1. A leading catch-all deny plus narrow allows is the only correct shape under findLast; a negative re-assertion must be the last rule.
2. Prefix allows for a script that execs its arguments convert the whole map into a shell-text allow. Fix the script, or do not allow the script.
3. A script allow is a write grant whenever any argument can name an output path.
4. Enumerate the commands a lane's assigned skills actually prescribe; execution-class skills (debuggers, profilers) confer methodology, not interpreter rights.
5. When a permission contract changes, agent markdown, preset prompt text and config comments drift silently. There is no permission-parity validator today; the name lockstep validator and the coder/coder-escalated clone check are the patterns to mirror.
6. Pattern-level metacharacter sealing is a partial control: deny shapes for `(`-substitution, backtick, `${`, and output redirection can be appended after a helper allow, but they cost false positives on legitimate arguments containing those characters, and they cannot close every shell expansion class.

## Outcome
Updated as of the DIA-260827-ft3z gate-hardening pass (2026-11-04):
- The console-charting skill has been de-scoped from every agent (the skill file is retained).
- The script-layer fixes hold: `data-reduce.sh` rejects any reducer whose first element is not on its bare-name allowlist, and session-log render refuses an `--output` that does not resolve inside `.opencode/session/`.
- The permission-map edit is no longer "still to come" - it LANDED. Both analyzer maps are the enumerated deny-first contract: catch-all `"*": "deny"` first, the eight `rg --pre` / `rg --pre-glob` denies pinned AFTER the `rg *` allow (last-match-wins), and the four bare openspec subcommands beside their starred twins. Defects 1-3 and the Mermaid bullet above are closed; their original text is kept as history.
- The contract is now mechanically gated instead of prose-only: `--lockstep` fails on a missing or empty pair member rather than printing a green zero-coverage line, and reports top-level keys plus leaf rules; `--doc-drift` decides restriction semantically (flat `"deny"` and reordered catch-alls are in scope), scans the `.prompt` fields and the live prompt-override files, reports every forbidden occurrence on a line, and enforces the edit-deny -> bash-deny invariant with an explicit tracked-debt exemption set (DIA-261006-ldfs).
