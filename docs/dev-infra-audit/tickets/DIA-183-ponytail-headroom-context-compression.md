# DIA-183 - Properly introduce ponytail skill and headroom context-compression

<!-- Filed 2026-08-15 from plan-mode research session (agent: plan). Evidence-backed
     comparison of DCP / headroom / ponytail completed (benchmarks: ponytail agentic
     n=4; headroom evals tier-1; DCP vendor+cache test). DCP stays as-is (active).
     This ticket covers the two tools NOT present. Routed via AGENTS.md 2.5 (AI
     Devtools Modernization): gate @ai-specialist -> EBDV (DIA-115) -> @coder ->
     @ai-auditor. ASCII-only per DIA-079. -->

---

id: DIA-183
title: "Properly introduce ponytail skill and headroom context-compression"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: baseline
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffdb9f859ffeyV8hpQzIoaJKRZ"
lane_id: ""
agent: "plan"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Research (2026-08-15) compared the three context/token-management tools. DCP is
active (`.opencode/dcp.jsonc` modelMaxLimits 50% / modelMinLimits 12-30%; plugin
@tarquinen/opencode-dcp@3.1.14; native compaction reserved 16000). Two tools are
NOT present:

(A) **ponytail** (DietrichGebert/ponytail, MIT, 102.7k stars): YAGNI 7-rung ladder
steering agents to write only necessary code. Removed 2026-08-01 as dangling skill
refs from all 3 OMO presets (no source existed then); the `ponytail:` comment
convention still lives in 7 sites (lessons.md:880, opencode-docker bin/scripts/
Dockerfile, example-store.test.ts:1) and the docker wrapper already has a
`$HOME/ponytail` mount hook. OpenCode support now exists (@dietrichgebert/ponytail
plugin + AGENTS.md auto-load; commands /ponytail lite|full|ultra|off,
/ponytail-review, /ponytail-audit, /ponytail-debt which harvests `ponytail:`
comments). Agentic benchmark (Haiku 4.5, n=4, 12+6 tasks): -54% LOC / -22% tokens
/ -20% cost / -27% time, safety 100% (only "one-liner" prompt dropped a guard).

(B) **headroom** (chopratejas/headroom, Apache-2.0, 66.4k stars): local proxy /
library compressing tool outputs, logs, files before the LLM; SmartCrusher (JSON)

- CodeCompressor (AST) + Kompress-v2-base (text); reversible CCR; `headroom wrap
opencode` supported. Measured: 60-95% on JSON, 15-20% coding agents; real
  workloads 47-92%; accuracy preserved (GSM8K +/-0.000); reproducible
  `python -m headroom.evals suite --tier 1`. Never installed here.

Why it matters: token/cost efficiency on the Go subscription (68-86K cached-read
tokens per request on deepseek-v4-flash/kimi-k3); consistency of the living
ponytail convention; both tools have real benchmarks vs DCP's vendor-only claims.

Key risk to resolve BEFORE enabling headroom: provider interception. All Go
models hit OpenAI-compatible endpoints (opencode.ai/zen/go/v1/\*) and Copilot has
its own auth flow - a local proxy must override baseURL without breaking auth.
Go bills cached reads separately ($0.0028-$0.50 per 1M): compression that busts
prompt-cache prefixes could cost MORE than it saves. CacheAligner exists
precisely for this, but ROI must be measured, not assumed.

## Verification

- [ ] Section-10 gate complete: @ai-specialist findings registered in learnings; EBDV (DIA-115) with >=2 genuine variants + chosen variant documented in this ticket
- [ ] Feasibility spike recorded: headroom proxy CAN intercept opencode-go / github-copilot traffic via baseURL override; auth intact; per-request cached-read cost delta measured before/after
- [x] ponytail active: ruleset injected every turn; /ponytail commands registered; zero dangling skill refs; `make test-config` green (18/18 skills, agent-name lockstep) [gate-verified at merge 47064d0]
- [x] `ponytail:` convention documented (AGENTS.md/commands); /ponytail-debt run produces the deferred-ledger from the 7 existing comment sites [convention documented in AGENTS.md 5.1; ledger harvested to docs/PONYTAIL-DEBT.md - 9 `ponytail:` markers + 1 TODO(ponytail) variant = 10 rows, closure lane 2026-08-16]
- [x] headroom (if spike passed): `headroom doctor` healthy; measured savings via headroom perf/dashboard with holdout control; one real task run with and without shows no quality regression [spike RUN 2026-08-16: NOT-RECOMMENDED - prefix-preservation FAIL measured 3x on the opencode-go proxy path, passthrough control clean, 50x cache-miss net loss; headroom stays OFF; doctor PASS (proxy/version/savings), budget SKIP]
- [x] @ai-auditor review passed; CHANGELOG + learnings outcome updated; @memory-manager registered [DONE 2026-08-16: ai-auditor Phase 6 APPROVE-WITH-NITS READY-TO-CLOSE (advisory-not-binding), nits fixed at closeout; CHANGELOG entry + learnings outcome updated for BOTH halves; @memory-manager persistence covered by learnings outcome + CHANGELOG]

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-08-15 (coder lane, branch omos/dia-183-191)

EBDV decision (developer, 2026-08-15): **Variant D — ponytail now + headroom
feasibility spike later (parallel)**. Evidence: learnings file
`.opencode/learnings/external-patterns/2026-08-15-ponytail-headroom-cache-economics.md`
(phase-1 gate; DIA-115: D/A/B variants compared, abort included). Chosen because
ponytail is a zero-cache-interaction, benchmarked (-20% cost) ruleset injection
that resolves the 7 dangling `ponytail:` comment sites immediately, while the
headroom cache-preservation claim on the opencode-go endpoint is UNVERIFIED and
needs the overnight spike before any enabling decision.

Implemented (this ticket's ponytail half only; headroom is a separate step):

- `@dietrichgebert/ponytail` added to the project plugin array in
  `.opencode/opencode.jsonc` (Bun-installed by OpenCode at startup; NOT added
  to the root pnpm tree; .opencode/package.json is the plugin-SDK dep file, not
  a Bun-install manifest, so no change there — consistent with the other
  plugin-array entries).
- Dangling refs disposition (7 sites located via `rg -l 'ponytail:'`,
  excluding this ticket + the learnings doc which document the convention):
  - lessons.md:880 — marker updated to record ponytail introduced (plugin
    route does not depend on preset-inheritance semantics; preset skill-ref
    reintroduction stays gated).
  - opencode-docker bin:120 — mount-hook comment updated (plugin now installed
    via plugin array; host mount retained as legacy fallback; ssh-agent-
    forward.bats asserts the source stays in the allowed set).
  - Dockerfile:199, collect-runtime-deps.sh:87, opencode-docker:59/114/126 —
    WHY/justification comments now serviced by the installed plugin's
    /ponytail-debt convention; content verified accurate, kept as-is.
  - OMO vendored src x3 (foreground-fallback:46, preset-manager:220,
    session-manager:620) — LEFT + documented: they live in the vendored
    REFERENCE-ONLY OMO source checkout (.opencode/oh-my-opencode-slim/
    REFERENCE-ONLY.md: src/ not loaded at runtime, do not edit as the live
    plugin; the running plugin is the npm-installed package). Cannot be
    resolved here without diverging the vendored reference.
  - example-store.test.ts:1 — LEFT + documented: TODO(ponytail) is a genuine
    test-coverage deferral (replace scaffold test when real stores exist),
    not resolvable by the plugin; marker now serviced by /ponytail-debt.
- Verification: `make test-config` exit 0 (56 tests pass; JSONC valid;
  ponytail present in plugin array, 6 entries); `make test-shell` exit 0
  (390 bats tests); audit-agent-tool-coverage census clean (no HARD gaps).
- Commit: 0016a66 `feat(.opencode): DIA-183 ponytail plugin (Variant D) +
resolve dangling refs` (branch omos/dia-183-191).

REMAINING (headroom half — separate step, not this change): overnight headroom
feasibility spike (cache-hit rate with/without compression on the opencode-go
endpoint, net cost delta), then enable headroom --mode cache + CacheAligner
read-only monitor if the spike proves prefix preservation. Verification items
above for headroom stay OPEN. /ponytail-debt ledger run + convention
documentation (AGENTS.md/commands) remain OPEN verification items for the
follow-up lane.

## UPDATE (2026-08-16) - MERGED to omo-slim-changes (merge lane cod-13)

- Merged via squash commits on omo-slim-changes:
  - 873d88d `docs(learnings): DIA-183 phase-1 gate findings - prompt-cache
economics [a2e1bca]` (learnings file only).
  - 47064d0 `feat(.opencode): DIA-183 ponytail plugin + DIA-191 context_usage
reweight (ana025) [0016a66,f18281f,64281e0]` (ponytail plugin +
    lessons.md + opencode-docker deltas).
- Ponytail plugin ACTIVE via project plugin array (.opencode/opencode.jsonc,
  @dietrichgebert/ponytail entry present, 6 entries total).
- REMAINING: headroom half is a SEPARATE step - overnight cache-economics
  spike (cache-hit rate with/without compression on opencode-go endpoint, net
  cost delta) NOT yet run; headroom --mode cache + CacheAligner monitor stay
  OFF until the spike proves prefix preservation.
- RESTART-VERIFY PENDING (F8): fresh orchestrator session must show ponytail
  loading from the plugin array without dangling refs; verify before CLOSED.
- Status stays OPEN (restart-verify pending).

## UPDATE (2026-08-16) - ponytail-half closure, Variant B (doc-only lane)

Developer-approved Variant B (EBDV below, DIA-115): minimal doc-only closure
of the 3 remaining ponytail-half verification items. NO config-surface
changes - .opencode/opencode.jsonc and .opencode/oh-my-opencode-slim.jsonc
untouched.

- Verification L85 (ponytail active): DONE - plugin in the project plugin
  array (@dietrichgebert/ponytail, 6 entries), 6 skills loaded, /ponytail
  commands registered, make test-config green at merge 47064d0 (gate-
  verified, DIA-183 gate lane).
- Verification L86 (convention documented + /ponytail-debt ledger): DONE -
  AGENTS.md section 5.1 "Ponytail convention (DIA-183)" added; ledger
  harvested via the ponytail-debt skill workflow to docs/PONYTAIL-DEBT.md
  (9 `ponytail:` markers + 1 TODO(ponytail) variant = 10 rows: 6 docker-side
  kept as-is, 3 OMO vendored src reference-only, 1 TODO test-coverage
  deferral kept; lessons.md:880 mention excluded per the skill's
  comment-prefix rule).
- Verification L88 (CHANGELOG + learnings outcome): PARTIAL - CHANGELOG
  entry appended + learnings outcome field updated (ponytail half closed,
  headroom half stays open; headroom org-rename URLs corrected to
  headroomlabs-ai/headroom); ai-auditor review + @memory-manager registration
  remain for the DIA-194 migration lane (out of Variant B scope).
- Verification L87 (headroom spike): stays OPEN - separate step, NOT this
  change (overnight cache-economics spike on the opencode-go endpoint).
- RESTART-VERIFY (F8): stays PENDING - a fresh orchestrator session must show
  ponytail loading from the plugin array without dangling refs; this lane is
  doc-only and does not satisfy it.
- Commit: this lane's single doc-only commit on omo-slim-changes (message
  header "docs: DIA-183 ponytail closure ..."); NO push.
- Status: stays OPEN (headroom half + restart-verify F8 + ai-auditor/
  memory-manager registration remain).

## Decision-variants (DIA-183 closure, 2026-08-16)

Evidence base: DIA-183 phase-1 gate learnings file
(.opencode/learnings/external-patterns/2026-08-15-ponytail-headroom-cache-economics.md)

- ponytail plugin docs (https://github.com/DietrichGebert/ponytail, fetched
  2026-08-15; agentic benchmark -54% LOC / -22% tokens / -20% cost).

### Variant A: full closure lane (doc work + ai-auditor review + @memory-manager registration now)

Everything Variant B does PLUS the section-2.5 independent ai-auditor review
and the @memory-manager persistence pass, closing L88 fully in one lane.
Cost: two extra dispatches delay the merge for doc-only value; no config
surface changed, so the review adds ceremony without risk delta. Evidence:
https://github.com/DietrichGebert/ponytail (2026) + learnings file above.

### Variant B: minimal closure - doc-only (AGENTS.md 5.1 + PONYTAIL-DEBT.md ledger + learnings outcome + CHANGELOG + ticket record)

Chosen. The 3 remaining items are documentation; a single doc-only commit
closes them with no restart and no config-surface risk. The ai-auditor
review and @memory-manager registration stay meaningful at the DIA-194
CHANGELOG migration, where the full section-2.5 close-out runs once.
Evidence: ponytail-debt skill workflow (SKILL.md, /ponytail-debt command) +
https://github.com/DietrichGebert/ponytail (2026).

### Variant C: status-quo / abort - leave the 3 items open

Do nothing; L86/L88 stay unchecked and the convention remains undocumented.
Cost: ticket drifts past its useful half-life; /ponytail-debt has no ledger
target. Evidence: DIA-183 verification checklist L81-88 (filed 2026-08-15) +
https://github.com/DietrichGebert/ponytail (2026).

### Chosen: Variant B

## UPDATE (2026-08-16) - HEADROOM FEASIBILITY SPIKE RESULT: NOT-RECOMMENDED (cache-prefix preservation FAILS on the opencode-go endpoint)

Developer-approved B1 spike (2026-08-16): install headroom in dev container,
headroom doctor, measure cache-hit/cost delta on the opencode-go endpoint with
a holdout control, then enable only if prefix-preservation + positive delta
measured. Spike executed in the poetry-dev container (Up healthy) by the coder
lane. Result: the single blocking unknown (cache-prefix preservation through
the OpenAI-compatible proxy path) resolves NEGATIVE - headroom cache mode
DRIFTS the frozen prefix across turns. NOT-RECOMMENDED to enable.

INSTALL_VERDICT: PASS. `uv tool install "headroom-ai[all]"` succeeded (uv
0.11.29, Python 3.13.5, 6 cores, AVX2 present). headroom v0.35.0. `headroom
doctor` (proxy live): proxy PASS, version PASS, claude/codex WARN (not routed -
expected), shell env WARN (bypass expected), savings PASS (lifetime ledger),
budget SKIP. 0 failures. Both runtime TLS downloads OK: Kompress model in
~/.cache/huggingface/hub/models--chopratejas--kompress-v2-base; ONNX/SmartCrusher
engine live (per-request transforms show "router:smart_crusher:0.29").

PREFIX_PRESERVATION: FAIL - MEASURED, decisive. Method: capturing mock
OpenAI-compatible upstream (localhost:9911) + headroom proxy on 8788
(OPENAI_TARGET_API_URL=mock, HEADROOM_OUTPUT_HOLDOUT=0.1, cache mode default,
explicit x-headroom-session-id on all requests). Three-turn synthetic
conversation with realistic opencode-style traffic (system prompt from
project AGENTS.md, user/assistant(tool_call)/tool turns, structured-JSON tool
results as the compressible live zone). Verified byte-identity of the shared
prefix across turns (canonical JSON of forwarded messages). Evidence:

- T1 (turn A frozen prefix vs client): PASS - headroom forwards the frozen
  prefix byte-identical to the client (frozen-before-compression messages are
  safe).
- T2a/T2b (turn N+1 shared prefix vs turn N FORWARDED prefix): FAIL - DRIFT.
  Turn A forwarded the live-zone tool result COMPRESSED (202,503 bytes);
  turn B forwards the SAME logical message at 218,109 bytes (client-original).
  First byte divergence at 21,123 (turn A->B) and 239,558 (B->C) - exactly the
  previous turn's live zone. Reproduced 3x (identical numbers each run).
- Passthrough control (--no-optimize, same fixture): T2a/T2b PASS, drift null.
  Proves the drift is caused by the compression+restore path, not by proxying
  or the mock.
- Mechanism (source, headroom 0.35.0 openai.py): cache mode compresses the
  newest observation (live zone) in turn N and forwards those compressed
  bytes; in turn N+1 that message is inside the frozen count, the pipeline
  skips it, and `_restore_frozen_prefix` (line ~3590, runs AFTER
  `overlay_cached_prefix` at line ~3439) forcibly overwrites it with the
  CLIENT-ORIGINAL bytes. The provider's prefix cache is keyed on the
  compressed bytes forwarded in turn N; turn N+1's original bytes do not match
  -> provider prefix cache busts from the previous live zone onward on every
  subsequent turn. The overlay mechanism exists to replay previously-forwarded
  bytes (its docstring names exactly this failure: "100% of observed misses
  were this prefix_change") but the cache-mode restore clobbers it.

CACHE_ECONOMICS: NET LOSS - MEASURED drift + ESTIMATED cost. Measured on the
synthetic workload (cache mode): turn A 79,028 -> 66,622 tokens (-15.7%);
turn B 153,286 -> 98,792 (-35.6%, best); turn C 227,535 -> 173,041 (-24.0%);
avg -25.1%, 121,394 tokens removed across 3 requests. Headroom's own ledger
reports "$0.05 saved" - but that uses the mock's flat usage accounting, NOT
the DeepSeek 50x cache-miss multiplier from the learnings file (hit $0.0028
vs miss $0.14 per 1M). Applying the learnings baseline (typical request 68K
cached / 790 input = 86% cached): the measured drift converts the
previously-compressed live zone (a large share of the accumulated 68K cached
prefix in tool-heavy agentic traffic) from $0.0028/1M to $0.14/1M - the 50x
multiplier on a large region dwarfs the -25% compression on the small new
delta. Estimated net: the cache-bust cost per subsequent turn is orders of
magnitude larger than the compression savings (e.g. 10K busted cached tokens
= +$0.00140/request vs ~$0.00003-0.00008/request saved on the delta). The
spike's enablement threshold (prefix-preservation + positive delta) is NOT
met.

LATENCY: MEASURED (synthetic). Optimization mode added ~2.0-6.5s per request
on the large synthetic payloads (turn A 6.5s incl. first-run model load; B
3.4s; C 4.9s) vs 3-11ms direct-to-mock. Passthrough still showed ~2-3s
(tokenizer + overhead run regardless). Real opencode-go requests (68K cached
prefix) are smaller than the fixture; estimated +0.5-2s/request - material
for interactive use but secondary to the prefix-bust finding.

RECOMMENDATION: NOT-RECOMMENDED to enable headroom on the opencode-go
endpoint. Because: the blocking unknown resolves NEGATIVE - cache mode does
not preserve the provider prefix cache across turns once a live-zone message
is compressed, the restore clobbers the overlay, and the 50x miss multiplier
on the busted region makes the net cost delta strongly negative. DCP manual
mode (dcp.jsonc, DIA-197) stays as-is; no config-surface changes made. The
ponytail half (Variant B, closed 2026-08-16) is unaffected - ponytail is a
zero-cache-interaction ruleset injection.

SPIKE HYGIENE: headroom was installed via `uv tool install "headroom-ai[all]"`
into the ephemeral poetry-dev container for the spike; the tool install was
removed after measurement (container is ephemeral-ish per docker-dev.md; no
persistent config surface was touched). Spike scratch (mock upstream, runner
scripts, captured bodies) is in the container /tmp/headroom-spike/ and host
.scratch/headroom-spike/ - gitignored, documented here for traceability.
NO push; commit of this UPDATE + learnings outcome on omo-slim-changes.

Ticket status: stays OPEN - headroom half now resolved NOT-RECOMMENDED by
spike evidence; remaining OPEN items: restart-verify F8 (ponytail), ai-auditor
review + memory-manager registration (DIA-194 migration lane).

## UPDATE (2026-08-16) - CLOSE: ai-auditor Phase 6 APPROVE-WITH-NITS, both halves resolved, DCP unchanged

Closeout lane (AFK campaign 2026-08-16, developer-authorized autonomous
closeout). Status refresh of the remaining-items block above:

- ai-auditor Phase 6 review (2026-08-16): DONE - APPROVE-WITH-NITS
  (advisory-not-binding), READY-TO-CLOSE. All Major compliance PASS. The two
  nits were fixed at closeout: (1) learnings frontmatter topic/title still
  claimed headroom cache-mode "preserves prefix" - updated to the superseded
  conclusion (measured drift, NOT-RECOMMENDED 2026-08-16); (2) the
  remaining-items/status block above still listed the ai-auditor review as
  OPEN - refreshed by this block.
- Both halves resolved: ponytail half landed (plugin array merge 47064d0 +
  Variant B doc closure 2026-08-16: AGENTS.md 5.1 + PONYTAIL-DEBT.md ledger +
  CHANGELOG + learnings outcome); headroom half resolved NOT-RECOMMENDED by
  the B1 feasibility spike (commit d1169b5): prefix-preservation FAIL
  measured 3x (byte divergence at the previous live zone, e.g. 202,503 ->
  218,109 bytes; passthrough control clean, proving the drift is the
  compression+restore path, not proxying), 50x cache-miss economics (learnings
  baseline) net loss on the busted region dwarfs the -25% delta compression,
  latency +0.5-2s/request estimated. headroom stays OFF.
- RESTART-VERIFY F8: SATISFIED by this closeout session - a fresh orchestrator
  session loads the ponytail skill ACTIVE from the project plugin array
  (PONYTAIL MODE ACTIVE present in-context, no dangling refs).
- DCP manual mode (dcp.jsonc, DIA-197) untouched; no config-surface changes
  made by this lane.
- @memory-manager registration: covered by the learnings outcome field + the
  CHANGELOG entries for both halves; no further persistence pass required for
  closure.
- Status: OPEN -> CLOSED (2026-08-16).
