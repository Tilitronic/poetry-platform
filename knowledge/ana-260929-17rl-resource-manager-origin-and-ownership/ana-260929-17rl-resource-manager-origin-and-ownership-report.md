# ana-260929-17rl - resource-manager: Origin, Ownership, Usage, and Verdict

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/opencode.jsonc; .opencode/session/registry.jsonl; .opencode/CHANGELOG.yaml
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket DIA-260929-nc6w (agent-role consolidation study). Lane question:
**Does the resource-manager agent need to exist?**

## RESULT (up front)

No. The lane is declared in every config surface but has **zero recorded
dispatches** across the entire retained session-registry history (2026-08-06
through 2026-09-29, 131,163 rows). Its one unique write target
(ai-assist-sources.yaml + OMO knowledge dir) has been maintained exclusively by
developer/coder commits, never by the lane. Its two designed distinguishing
capabilities (sub-dispatch, curl/wget caching) were found non-functional at
runtime by two separate lessons entries. Verdict: **merge into @researcher**;
interim minimal option: keep-but-narrow (which also closes the stale OPEN
ticket DIA-260827-ic3r).

---

## 1. What it is today (declared state)

No `.opencode/agents/resource-manager.md` file exists and none ever did
(`git log --follow --diff-filter=A -- .opencode/agents/resource-manager.md`
returns empty). It is a **config-only agent**, defined in three places:

| Surface                       | Location                                                          | What it says                                                                 |
| ----------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| opencode.jsonc (S2)           | lines 623-646                                                     | Full permission block: "knowledge-source curation lane (DIA-007 split)"      |
| oh-my-opencode-slim.jsonc (S3)| `agents.resource-manager` at line 832; prompt line 826; orchestratorPrompt line 834; presets lines 181, 425, 658, 796 | Purpose, routing summary, model per preset                                    |
| AGENTS.md S1 naming table     | line 272                                                          | "@resource-manager - Knowledge-source curation (ai-assist-sources.yaml, Tier-1 caching)" |

Declared permission block (opencode.jsonc:628-646):

```
mode: subagent
edit:  "*" deny; ".opencode/oh-my-opencode-slim/knowledge/*" allow   <-- unique write scope
bash:  "*" deny; "curl *"; "wget *"; "trafilatura *" allow            <-- identical minus crwl to @researcher
task:  allow                                                           (intended: @researcher/@conspecter only)
```

- **May write:** `.opencode/oh-my-opencode-slim/knowledge/` only - which today
  contains exactly 2 files: `ai-assist-sources.yaml` (12,796 B) and
  `opencode-best-practices.md` (4,704 B).
- **Must not do:** source-file or config edits (practice-protected.md:73-78);
  config changes go to @coder, research analysis to @ai-specialist/@analyzer
  (oh-my-opencode-slim.jsonc:834).
- **Tier:** artifact-producer (practice-protected.md:59, DIA-007 classification).
- **Purpose as declared:** curate ai-assist-sources.yaml, maintain Tier-1
  Markdown caches, re-fetch Tier-2 volatile sources, evaluate awesome-opencode
  tools by star count (<100 experimental / 100-500 reasonable / 500+ established).

## 2. Provenance

Created **2026-08-03** by commit `9d272ec3` -
"feat(devtools): DIA-007 split ai-specialist into resource-manager + rebalance
cebula preset to Copilot". CHANGELOG.yaml (DIA-007 entry, partial per-ticket
query): split approved by owner as "Alternative D" with all 6 design decision
points approved; the owner wanted to separate the read-only analyst
(ai-specialist, pure-analyst) from the write-capable curator (resource-manager,
artifact-producer). The referenced `DIA-007.md` ticket file no longer exists in
the ledger (`scripts/tickets show DIA-007` -> "ticket not found"; absent from
archive); provenance rests on CHANGELOG + learnings
(`.opencode/learnings/external-patterns/2026-08-03-dia007-ai-specialist-split.md`).

Zero ADR entries (`adr.md`: 0 mentions). memory-shelf.yaml: 0 lane entries.
Six mentions in `lessons.md` (lines 209, 214, 220, 589, 711, 3478) - all of
them about the lane being *broken or constrained*, none about curation work it
did. Full CHANGELOG.yaml picture (11 entries mention it, 2026-08-03..2026-09-28):
every post-creation touch is **routing/maintenance churn** (model swaps
DIA-087/DIA-208/DIA-260824-1c3e/DIA-260826-spu5, preset rebalances, permission
hardening DIA-126, token denies DIA-055/056), never a completed curation task.

## 3. Is it actually used?

**Declared vs dispatched - the distinction that matters.**

Dispatch counts from `subagent_type` fields, union of
`.opencode/session/registry.jsonl` (2,790 rows, to 2026-09-29) and
`registry-archive/registry-20260916...jsonl` (128,373 rows, 2026-08-06..09-15):

```
Lane               Recorded dispatches   Note
coder                      317
ai-specialist               42   (the lane it was split FROM; active)
memory-manager              40
researcher                 12   (the lane it would merge INTO; active)
analyzer                   11
conspecter                  6
resource-manager            0   <-- zero
```

- `grep resource-manager` over both registry files: only 2 incidental matches
  inside unrelated capability_minted reason text. `messages.jsonl`: 1 mention -
  a 2026-09-17 handoff (DIA-260917-knz2) about a *config edit to the lane's
  preset model entry*, not a lane run.
- References elsewhere: opencode.jsonc task-allowlist (line 230), 4 preset
  blocks (active `mimo-balanced` routes it to opencode-go/mimo-v2.6-flash),
  orchestrator DELEGATION DIRECTORY prompt, NEXT-RUN.md:157,
  ai-specialist.md:31 ("recommend the orchestrator dispatch @resource-manager"),
  ai-auditor.md:23. Not in `disabled_agents` (only oracle/fixer/explorer/
  librarian are), not a council member, no skill/command/plugin reference.
- **The referral chain has never fired:** ai-specialist (42 dispatches, active)
  is the designated referrer, yet the referred-to lane has 0 dispatches.
- **Who did its job instead:** git log of `ai-assist-sources.yaml` shows every
  content refresh committed by developer/coder lanes - `20c2a03b` 2026-08-12
  (DIA-108 "refresh ai-assist-sources.yaml - add 8 Go models"), `dcc72603` +
  `2fb3f484` 2026-08-11 (DIA-087), `74d6bd10` 2026-08-07 (DIA-045), `a0462440`
  2026-08-14 (DIA-136). The owner never edited it.
- Runtime reality contradicted the design twice: lessons.md:209-214 - during
  the DIA-045/059 campaign (2026-08-04/05) the resource-manager runtime "lacked
  a bash/shell callable-tool", so host probes/validation fell to a coder lane;
  lessons.md:220 (2026-08-12) - it "runs with subagent_depth=1 in the OMO
  runtime, which BLOCKS nested dispatch", so its `task: allow` is inoperative
  and even its authored edits must be handed "to a SEPARATE coder lane for
  validation + commit + push"; lessons.md:589-599 (DIA-126, 2026-08-13) -
  trailing catch-all `"*": "deny"` hid the whole bash tool from its schema.
  Net: both differentiators (scoped writes + sub-dispatch) either never fired
  or fired broken.
- An **OPEN ticket about hardening this unused lane** sits in the ledger since
  2026-08-27: DIA-260827-ic3r "[MEDIUM] Resource-manager can delegate any lane
  (task allow unrestricted)" - pure maintenance liability with no offsetting use.

## 4. Scope distinctness

| Capability                        | resource-manager | researcher | conspecter | ai-specialist | memory-manager |
| --------------------------------- | ---------------- | ---------- | ---------- | ------------- | -------------- |
| edit OMO knowledge/ (sources.yaml)| **ONLY**         | no         | no         | no            | no             |
| edit knowledge/ (reports)         | no               | yes        | yes        | no            | no             |
| edit .opencode/memory/ + shelf    | no               | no         | no         | no            | yes            |
| curl/wget/trafilatura bash        | yes              | yes (+crwl) | no        | no            | no             |
| webfetch (external research)      | mcp websearch    | yes        | no(deny)   | yes           | -              |
| star-count eval methodology       | yes              | no         | no         | **yes (dup!)** | no            |
| Tier-2 re-fetch policy            | yes              | -          | -          | **yes (dup!)** | no            |
| sub-dispatch task: allow          | yes (broken^1)   | deny       | deny       | deny          | -              |

^1 lessons.md:220 (subagent_depth=1).

- **Overlap with ai-specialist:** the star-count rule and Tier-2 re-fetch
  policy exist verbatim in BOTH prompts (ai-specialist.md:16-25 and
  oh-my-opencode-slim.jsonc:826). The split separated reader from writer but
  duplicated the reader's methodology text into the writer.
- **Overlap with researcher:** identical fetch toolchain (minus `crwl`) and
  the same artifact-producer tier; only the edit glob differs. The merger is a
  one-glob change, not a capability transfer.
- **Unique residue:** write access to `.opencode/oh-my-opencode-slim/knowledge/`
  (2 files, 17.5 KB total) and curation vocabulary. Nothing that requires a
  whole agent lane at the observed edit frequency (~5 commits in 8 weeks,
  all by other lanes).

## 5. Verdict - EBDV decision variants (DIA-115)

All variants are section-10 / AGENTS.md-2.5 policy-class changes (opencode
config + AGENTS.md + naming-table lockstep): route through the
ai-specialist gate -> owner decision -> @coder -> `make test-config` ->
@ai-auditor review -> CHANGELOG. Effort counts the 4-source name lockstep
(`scripts/validate-agent-names.sh`) plus the prose surfaces: AGENTS.md:272,
NEXT-RUN.md:157, practice-protected.md:59+73-78, ai-auditor.md:23,
ai-specialist.md:31, orchestrator DELEGATION DIRECTORY (repeated in 4 presets
of oh-my-opencode-slim.jsonc), ai-assist-sources.yaml:238, plus the
resource-manager permission/prompt/preset blocks in the two jsonc files.

### Option 0 - Status quo / abort (do nothing now) [always-included variant]

Keep the lane exactly as declared; keep DIA-260827-ic3r OPEN.
- Evidence for: creation was an owner-approved design decision, "Alternative
  D", 2026-08-03 (CHANGELOG DIA-007; Tier-1 committed pointer).
- Pros: zero diff, zero risk; decision remains reversible.
- Cons: a dead lane carries standing cost - it has already generated 8 routing
  churn commits and 1 OPEN hardening ticket; the orchestrator prompt advertises
  a delegation option that has never been used (misleading surface); the ic3r
  finding (unrestricted task: allow) stays live in the ledger.
- Effort: 0. Section-10 flag: none.

### Option A - Merge into @researcher (remove resource-manager) [RECOMMENDED]

Add `.opencode/oh-my-opencode-slim/knowledge/*` to researcher's edit map;
redirect ai-specialist.md:31 and ai-auditor.md:23 referrals to @researcher;
delete the lane from S1/S2/S3 surfaces, presets, prompts, practice-protected,
AGENTS.md:272, NEXT-RUN.md:157, ai-assist-sources.yaml:238.
- Evidence for: 0 dispatches vs researcher's 12 in the same 8-week window
  (registry.jsonl + archive); researcher already holds the identical bash fetch
  set (opencode.jsonc researcher block); every ai-assist-sources.yaml refresh
  was already done outside the lane (`20c2a03b`, `a0462440`).
- Pros: one fewer 4-surface name to keep in lockstep; removes the duplicated
  star-count policy (single home in ai-specialist's methodology); the OPEN
  ic3r ticket is resolved by deletion (its attack surface disappears); curation
  keeps a write-capable home with a proven-active lane.
- Cons: loses the explicit analyst/curator separation the owner chose 2026-08-03
  (mitigation: researcher gains one glob, the separation that mattered -
  read-only ai-specialist - is preserved); touches ~10 files in one atomic set.
- Effort: Medium - one section-2.5 config session, mechanical multi-file edit +
  validator. Section-10 flag: **yes** (agent removal = policy-class; needs
  ai-auditor review + CHANGELOG entry + owner approval).

### Option B - Keep-but-narrow (dormant but safe)

Fix the open findings, keep the declaration: narrow `task` to a deny-first map
allowing only researcher+conspecter (closes DIA-260827-ic3r per its own
recommended fix), drop the duplicated star-count/Tier-2 text from its prompt,
and mark it "use only on owner request" in the orchestrator directory.
- Evidence for: ic3r body prescribes exactly this ("deny *, allow only
  researcher and conspecter"); lessons.md:220 shows sub-dispatch is blocked at
  runtime anyway, so narrowing costs nothing that actually works today.
- Pros: smallest honest diff (~4 files); owner-approved split architecture kept
  intact; zero risk to other lanes.
- Cons: preserves a 0-dispatch surface with standing lockstep cost; the
  misleading delegation-directory entry survives in every orchestrator prompt
  copy; decision debt - the question resurfaces at the next consolidation pass.
- Effort: Small. Section-10 flag: yes.

### Option C - Merge into @memory-manager (rejected on evidence)

Rationale someone might give: both are knowledge-writers.
- Rejected: disjoint edit scopes (memory/.opencode/* vs OMO knowledge/),
  different tiers of work (ADR/lesson persistence vs external-source
  curation), and memory-manager is the shelf gatekeeper with 40 dispatches -
  widening its scope toward web-fetch tooling cuts against its no-bash profile.
  [INFERENCE from scope comparison - labeled, and the rejection also rests on
  the Tier-1 evidence in sections 1-4.] Effort: same lockstep cost as Option A
  with a worse functional fit. Section-10 flag: yes.

### Recommendation

**Option A (merge into @researcher), executed via the section-2.5 chain; Option B if
the owner wants minimum churn this cycle.**

Because: a lane's right to exist is usage plus a scope no one else covers.
resource-manager has neither with weight - zero recorded dispatches in the
entire retained history (registry evidence), a scope overlap near-total with
researcher (same fetch tools, same tier, differing by one edit glob), its two
designed differentiators documented broken at runtime (lessons.md:220, 589-599),
and its one unique duty (sources.yaml curation) demonstrably performed by other
lanes (commits 20c2a03b, a0462440) while the lane itself accumulated a live
security finding (DIA-260827-ic3r) it never used its powers to deserve.

## OPEN QUESTIONS

1. Registry coverage gap 2026-08-03..08-06 (creation..archive start) - lessons.md
   implies the lane ran during the DIA-045/059 campaign, but no registry capture
   exists for that window; if the developer recalls a real dispatch that produced
   a merged curation, Option A's "never used" premise softens.
2. lessons.md:220 says a run was observed on 2026-08-12 (inside archive
   coverage) yet the archive contains no resource-manager spawn row - either the
   row predates `subagent_type` capture or the run came through a config the
   observer does not log (opencode-overnight.jsonc has no resource-manager
   entry, so the overnight path is unlikely). Worth one ai-specialist probe.
3. The DIA-007 ticket file is missing from the ledger entirely; provenance
   rests on CHANGELOG + learnings only.
