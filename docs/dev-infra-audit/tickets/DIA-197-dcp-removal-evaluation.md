# DIA-197 - evaluate DCP removal: cache degradation (85% vs 90%) without noticeable benefit - research + conspect + EBDV decision

<!-- EVALUATION TICKET (developer-requested 2026-08-15). Do NOT implement here -
     this ticket records scope + routing + gate state. If the EBDV decision is
     GO on removal, a follow-up implementation lane executes the removal (see
     Scope (d)). Sibling of DIA-183 (ponytail + headroom) - DCP removal is a
     SEPARATE decision from the DIA-183 tool introductions. -->

---

id: DIA-197
title: "evaluate DCP removal: cache degradation (85% vs 90%) without noticeable benefit - research + conspect + EBDV decision"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "DIA-183" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "waived" # grilled | waived | bypassed | partial | skipped
gate_triggers: [cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [spike-poc] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: developer-requirement
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "ses_ff88675cbffe41st8Fn99mdGqq" # OpenCode session ID that owned this ticket
lane_id: "cod-docs" # e.g. cod-1, ai--3
agent: "coder" # agent name (coder, reviewer, etc.)
model: "deepseek-v4-flash" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: # list of file paths modified
[
'docs/dev-infra-audit/tickets/DIA-197-dcp-removal-evaluation.md',
'docs/dev-infra-audit/tickets/README.md',
]
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

EVALUATION ticket (developer-requested 2026-08-15): evaluate REMOVING DCP
(opencode-dynamic-context-pruning) because it degrades the prompt cache without
noticeable benefit. This ticket records scope + routing + gate state ONLY; no
implementation happens here (evaluation tickets spawn follow-up implementation
lanes on a GO decision).

Context (verified by ai-specialist gate ai--2, 2026-08-15, learnings file
`.opencode/learnings/external-patterns/2026-08-15-ponytail-headroom-cache-economics.md`):

- DCP's own README documents "cache hit rates approximately 85% with DCP vs 90%
  without" - a ~5% cache degradation eaten today with no measured upside.
- DeepSeek V4 Flash cache miss is 50x cache hit ($0.14 vs $0.0028/1M); typical
  Go request is 86% cached tokens. Cache preservation is the dominant cost
  driver.
- DCP author moved development to Sleev (a local proxy for Claude
  Code/Codex/OpenCode building on DCP's ideas).
- Project uses `@tarquinen/opencode-dcp@3.1.14` in the `.opencode/opencode.jsonc`
  plugin array (line 593) + `.opencode/dcp.jsonc` config exists (modelMaxLimits
  50% / modelMinLimits 12-30%).
- DIA-183 (ponytail + headroom) is the sibling cache-economics ticket - DCP
  removal is a SEPARATE decision.

Why it matters: on the Go subscription (68-86K cached-read tokens per request on
deepseek-v4-flash), a ~5% cache-hit degradation from DCP's prefix mutation is a
recurring cost with no measured benefit. Removing DCP (or disabling its pruning)
could restore the ~90% cache-hit baseline.

## Scope

(a) Research lane (@researcher, pre-allocated res029): what DCP actually does
(dynamic context pruning mechanics), its measured benefit evidence (token
savings vs cache-miss cost), the 85% vs 90% cache-hit claim, Sleev as the
successor/alternative, and whether DCP can be configured to not prune the
prefix (cache-preserving mode, if any).
(b) Conspect (@conspecter) after research - res029 conspect with MLA-cited
sources.
(c) EBDV decision (DIA-115): >=2 variants + abort: - V1 remove DCP entirely (uninstall from plugin array + dcp.jsonc, verify no
regression); - V2 keep DCP but disable/configure pruning; - V3 replace DCP with Sleev or headroom cache-mode; - V4 abort/status-quo.
Recommendation with because-justification.
(d) If GO on removal: coder implements (remove plugin-array entry + dcp.jsonc +
verify make test-config / test-shell), ai-auditor review, restart-verify,
registration.

## Verification

- [ ] Research lane complete: res029 findings registered (DCP mechanics, benefit
      evidence, 85% vs 90% claim, Sleev status, cache-preserving mode question)
- [ ] Conspect complete: res029 conspect with MLA-cited sources
- [ ] EBDV (DIA-115) decision recorded in this ticket: >=2 genuine variants +
      abort, each with evidence, recommendation with because-justification
- [ ] If GO on removal: `make test-config` exit 0; no DCP in plugin array;
      restart-verify shows no DCP load errors; token-economy comparison
      before/after (cache-hit rate / cached-read tokens per request)
- [ ] @ai-auditor review passed; CHANGELOG + learnings outcome updated;
      @memory-manager registered

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-08-16 (coder lane, branch omos/dia-197-v2)

EBDV decision (developer, binding 2026-08-16): **V2 - KEEP the DCP plugin but
DISABLE autonomous pruning via config**. Evidence: res029 research + conspect
(`knowledge/res029-dcp-removal-evaluation/`): DCP prunes by mutating outbound
request messages, which invalidates the provider prefix cache (README: "changes
messages, which invalidates cached prefixes"); there is NO cache-preserving
mode; closest to "off" is manualMode.enabled + compress.permission "deny" +
strategies off. Chosen because V2 preserves manual /dcp capability while
stopping the ~5% cache-hit degradation (85% vs 90%) at zero removal risk; V1
(full removal) stays available as a future option if V2 proves insufficient.

Implemented (`.opencode/dcp.jsonc` only; plugin-array entry, dcp.jsonc file,
and validate-opencode-config.sh untouched per decision):

- `manualMode.enabled: true` - sessions start in manual mode; pruning only via
  explicit /dcp commands.
- `manualMode.automaticStrategies: false` - dedup/purge do not run
  automatically even in manual mode.
- `compress.permission: "deny"` - model cannot invoke compress autonomously.
- `strategies.deduplication.enabled: false` + `strategies.purgeErrors.enabled:
false` - belt-and-suspenders: no automatic strategies.
- KEPT existing modelMaxLimits (50%) / modelMinLimits (12-30%) entries
  (harmless when pruning is disabled; config surface not deleted).
- WHY comment block added (JSONC) documenting the DIA-197 V2 rationale and the
  exact revert steps.

Verification evidence (2026-08-16):

- `make test-config` exit 0 (validate-opencode-config.sh passes; dcp.jsonc
  still exists and parses as valid JSONC: "ok: .../dcp.jsonc" +
  "ok: all OpenCode config files are valid JSONC").
- JSONC parse (node, comment-stripping tokenizer): exit 0.
- Diff scope: `.opencode/dcp.jsonc` 19 insertions / 0 deletions - only
  pruning-disable additions (comment block + manualMode + compress.permission
  - strategies), no existing keys removed.
- Docker gate (DIA-094): poetry-dev container Up (healthy) before commit.

Status: **PENDING restart-verify** - next OpenCode restart must show DCP
loading without autonomous pruning (no prefix-mutating prunes on normal
requests) and /dcp manual commands still functional. V1 (full removal) remains
a future option if V2 proves insufficient.
