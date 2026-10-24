# DIA-207 - WSL memory/CPU cap exhaustion causes vsock relay stalls and remote disconnects

<!-- Copy this template to a new file `DIA-<NNN>-<human-slug>.md` (bare
     `DIA-<NNN>.md` names are deprecated per DIA-110) and replace placeholders.
     Keep the YAML frontmatter block intact. Statuses VALIDATE and E2E (added
     2026-08-04, ticket-vocabulary drift fix) are audit-phase statuses - used
     while the gate-matrix validation / Docker+browser end-to-end runs are
     pending or in progress; they transition to fix-lane states via Fix ->
     Re-verify. -->
<!-- GRANDFATHERED: DIA-001 through DIA-049 use v1 schema (no session fields).
     Session-attribution fields are OPTIONAL for all tickets. New tickets SHOULD
     populate them; existing tickets are not retroactively updated. -->

---

id: DIA-207
title: "WSL memory/CPU cap exhaustion causes vsock relay stalls and remote disconnects"
area: env
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: baseline
source: baseline
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "ses_ff506d666ffeG3Byn4Thg8bfqw" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Long-running opencode sessions cause WSL to become unresponsive and VSCode
Remote-WSL to "disconnect". Root cause chain (diagnosed 2026-08-17):

1. `.wslconfig` caps WSL at memory=16GB / processors=6 while the host has
   32GB / 16 cores. Two parallel opencode sessions (RSS 2.5GB + 2.2GB),
   VS Code remote server (~1.7GB), Docker (poetry-dev + poetry-postgres +
   turbo, ~0.7GB) and console-ninja MCPs saturate the cap.
2. Long opencode sessions accumulate full conversation history in RAM
   (project workflow = heavy subagent delegation + plugin logging), so
   memory grows monotonically with session age.
3. Under pressure WSL swaps eagerly (swappiness=60, 4GB swap on slow
   Windows FS) and CPU is oversubscribed (14 runnable on 6 vCPUs).
4. The WSL vsock relay (carries VSCode Remote connections) stalls under
   load - dmesg shows repeated:
   `WSL (1617091 - Relay) ERROR: UtilAcceptVsock:246: Waiting for
abnormally long accept(13)` - this is the visible "disconnect".
5. `autoMemoryReclaim=dropcache` does not help: it only frees page cache,
   while the growth is process RSS.

## Verification

Observe the failure state (all read-only):

    free -h                          # swap in use, low available
    dmesg | grep -i "UtilAcceptVsock"  # relay stall errors
    ps aux --sort=-%mem | head -15   # 2+ opencode sessions, multi-GB RSS
    uptime                          # load > nproc (6)

After the fix, the same commands must show: swap near-zero under normal
load, no new UtilAcceptVsock errors during a long session, load < nproc.

## Fix

Phase 1 (habit, no config): one opencode session at a time; restart
sessions after heavy delegation cycles (~4-6h), per NEXT-RUN.md fresh-
session protocol.

Phase 2 (host config, requires wsl --shutdown):
[wsl2]
memory=24GB
processors=12
swap=8GB
[experimental]
autoMemoryReclaim=gradual

Phase 3 (optional, in-distro): vm.swappiness=10 via sysctl + /etc/sysctl.conf.

Phase 4 (optional): docker-compose mem_limit for postgres (1g) and dev (4g).

Phase 5: verify per Verification section; `make up` after WSL restart.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
