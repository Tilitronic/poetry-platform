# WSL Cap Exhaustion vsock Relay Stall Analysis (DIA-207)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: docs/dev-infra-audit/tickets/DIA-207-wsl-memory-cap-vsock-relay-disconnects.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Scope

Campaign ticket DIA-207 'wsl-memory-cap-vsock-relay-disconnects' (status OPEN, area env, severity Major). Claim: WSL2 resource caps (memory=16GB / processors=6 on a 32GB / 16-core host) saturate under normal project load, causing swap thrash + CPU oversubscription, which stalls the WSL vsock relay (`UtilAcceptVsock:246 ... abnormally long accept(13)`) and surfaces as VSCode Remote-WSL "disconnect". Long-lived opencode sessions are the main growth driver (monotonic RSS from full history + subagent delegation + plugin logging).

This analysis tests that chain for gaps, ranks fix phases by leverage, and states what would falsify it. Domain is comprehensible: no cannot-comprehend condition. All reasoning is ASCII-only.

## Methods

1. 5-Whys (causal depth).
2. Forward causal chain (cap -> pressure -> scheduler/VM -> relay stall -> UX symptom).
3. Systems thinking (stocks, flows, feedback loops, leverage points).
4. Inversion (what else could produce the same dmesg + disconnect signature).
5. Fix-phase leverage review (ticket Phases 1-5).

## 5-Whys

1. Why does VSCode Remote disconnect? The vsock relay stops accepting connections in time; client times out.
2. Why does the relay stall? `UtilAcceptVsock` accept() blocks abnormally long. Accept latency spikes when the WSL2 VM cannot schedule the relay thread promptly or cannot fault pages in promptly.
3. Why can it not schedule / page in? 14 runnable threads contend for 6 vCPUs (load > 2x nproc) while anonymous memory exceeds the 16GB cap, forcing reclaim + swap to a 4GB swapfile on slow Windows-backed FS with swappiness=60.
4. Why does memory exceed the cap? Steady-state consumers (~2.5 + ~2.2 GB two opencode sessions, ~1.7 GB VSCode server, ~0.7 GB docker set, plus console-ninja MCPs) already approach the cap; session RSS then grows monotonically with age because full conversation history stays resident and each delegation cycle + plugin log append adds retained state.
5. Why does the cap stay at 16GB/6 while load grows? `.wslconfig` was sized for a lighter workflow (one session, smaller delegation fan-out). The project workflow (heavy subagent delegation, persistent dev + postgres containers, turbo) outgrew it, and `autoMemoryReclaim=dropcache` was a category error: it reclaims page cache, not process RSS, so it cannot arrest this growth mode.

Root cause statement: undersized static WSL2 caps + unbounded per-session RSS growth + eager swap on slow storage + CPU oversubscription = relay scheduling failure. The dmesg line is a downstream symptom, not a vsock bug.

## Causal Chain

```
.wslconfig cap (16G/6)  +  host capacity (32G/16)
        |
        v
resident set: opencode A 2.5G + opencode B 2.2G + vscode-server 1.7G
              + docker (dev+postgres+turbo) 0.7G + MCP servers
        |  (+ monotonic growth with session age / delegation depth)
        v
anonymous memory > cap  -->  kswapd + direct reclaim, swappiness=60
        |                     swap to 4G file on Windows FS (slow)
        v
major fault latency up, runnable 14 on 6 vCPU, scheduling delay up
        |
        v
vsock relay accept() delayed  -->  dmesg UtilAcceptVsock:246
        |
        v
VSCode Remote timeout  -->  user-visible "disconnect" + WSL unresponsive
```

Reinforcing loop (R1): pressure -> swap latency -> threads block longer -> more runnable accumulation -> more pressure. Balancing attempt that fails (B1): `dropcache` reclaim frees page cache only, RSS untouched, so the loop is unbroken. That mismatch is why Phase 2/3 of the ticket (raise caps, tame swap) outranks config cosmetic fixes.

## Systems View: Stocks, Flows, Leverage

- Stock: WSL2 anonymous pages (RSS). Inflow: session history retention, delegation fan-out, plugin logs, container footprints. Outflow: only session restart or process exit. No in-VM outflow under normal use, so the stock ratchets.
- Stock: runnable threads. Inflow: parallel sessions + turbo + language servers. Outflow: scheduling on 6 vCPUs. Saturated server, queue grows.
- Slow drain: 4GB swap on high-latency FS with swappiness 60 converts a capacity problem into a latency problem, which is exactly what kills an accept-loop relay first (latency-sensitive, low-CPU victim of a throughput problem).
- Highest leverage (in order): (a) cap the inflow (one session at a time, restart cadence 4-6h, bound delegation/log retention); (b) raise the container (24G/12 per ticket Phase 2, matches host headroom); (c) reduce swap eagerness (swappiness 10) and make reclaim mode gradual; (d) bound container RSS via mem_limit so postgres/dev cannot squeeze the relay; (e) verify with the ticket's read-only triad.

## Inversion: What Else Could Look Like This

| Alternative hypothesis | Expected signature | Verdict vs ticket evidence |
| ---------------------- | ------------------ | -------------------------- |
| vsock / WSL host bug independent of load | stalls at low load, no swap, load < nproc | Rejected as primary: ticket correlates stalls with saturation metrics |
| Windows host memory pressure (not WSL cap) | host commit high, WSL cap not reached, no in-VM swap | Possible co-factor; ticket Verification (in-VM free/ps/uptime) distinguishes it |
| Network / VPN drop of Remote-SSH path | no dmesg relay errors, reconnect fast, WSL responsive locally | Rejected: WSL locally unresponsive + relay errors present |
| Single leaky process (not systemic cap) | one RSS dominates, killing it restores health under same cap | Partial: two sessions + server jointly saturate, so per-process fix alone insufficient; restart cadence covers it |
| Slow disk only (Windows FS) without CPU/memory saturation | high iowait, normal load, normal free | Rejected as sole cause: 14-on-6 oversubscription documented |

Falsifier: reproduce `UtilAcceptVsock` stalls with `free` showing ample available, swap zero, and `uptime` load below nproc during a long session. That would move suspicion to relay/host bug.

## Fix-Phase Assessment

| Phase | Ticket content | Leverage | Cost / risk | Analyzer note |
| ----- | -------------- | -------- | ----------- | ------------- |
| P1 habit: one session, restart 4-6h | stop inflow growth | High, immediate | Low; discipline cost only | Do first; also bounds token/context cost. Codify in NEXT-RUN.md fresh-session protocol |
| P2 host: memory=24G, processors=12, swap=8G, reclaim=gradual | raise container, soften cliff | High, structural | Needs wsl --shutdown + make up; still leaves 8G host headroom | Correct sizing for 32G/16 host. Prefer gradual over dropcache (ticket is right) |
| P3 in-distro: swappiness=10 | reduce eager swap | Medium | Low; sysctl + conf persist | Sound; converts early-swap latency into later-but-sharper reclaim, acceptable with bigger cap |
| P4 docker mem_limit postgres 1g, dev 4g | bound neighbors | Medium | Low-Med; OOM-kill policy must be set or limits just move failure | Add restart policy + document who gets OOM-killed first; otherwise a limit can surprise |
| P5 verify: free, dmesg, ps, uptime, make up | close the loop | Required | Read-only + restart | Extend: sample over a full long session, assert no new relay errors, swap near-zero, load < nproc |

Order of operations: P1 now, P2+P3 at next maintenance window (single shutdown), P4 after observing headroom, P5 as gate. Do not skip P1 even after P2: bigger caps only delay the same monotonic growth.

## Terminal-Friendly Summary Table

```
+------------------+-------------------------------------------+------------------+
| NODE             | STATE / EVIDENCE                          | ACTION           |
+------------------+-------------------------------------------+------------------+
| WSL cap 16G/6    | undersized vs 32G/16 host + project load  | raise to 24G/12  |
| Session RSS      | 2.5G + 2.2G, grows with age/delegation    | one session;     |
|                  |                                           | restart every    |
|                  |                                           | 4-6h             |
| VSCode + Docker  | ~1.7G + ~0.7G + MCPs saturate remainder   | bound via limits |
|                  |                                           | (P4)             |
| Swap 4G/swap 60  | eager swap on slow FS -> fault latency    | swap 8G, swm 10, |
|                  |                                           | reclaim gradual  |
| CPU 14 on 6      | load > 2x nproc, relay starved            | fewer parallel   |
|                  |                                           | sessions + 12    |
|                  |                                           | vCPU             |
| vsock relay      | UtilAcceptVsock:246 stalls (symptom)      | fix upstream;    |
|                  |                                           | monitor dmesg    |
| dropcache        | frees page cache, not RSS (no effect)     | replace, do not  |
|                  |                                           | keep as fix      |
+------------------+-------------------------------------------+------------------+
```

Copy-paste verification triad (from ticket, unchanged):

```
free -h
dmesg | grep -i "UtilAcceptVsock"
ps aux --sort=-%mem | head -15
uptime
```

Pass criteria: swap near-zero under normal load, no new relay errors across a long session, load below nproc.

## Risks and Open Questions

1. Cap raise masks growth: without P1 discipline the same stall recurs at 24G, only later. Mitigation: session-age restart rule stays mandatory.
2. mem_limit without OOM policy trades a stall for a kill. Decide victim order (turbo workers before postgres before relay path) and set restart policies.
3. Current shell reports nproc=12, not the ticket's 6, so the cap may already differ on this host or across machines. Confirm `.wslconfig` on each affected host before attributing; heterogeneous hosts need per-host sizing, not one global value.
4. Plugin logging volume (delegation-observer) is an RSS inflow contributor worth measuring separately: if logs are retained in-process, bounding retention is cheaper than repeated restarts.
5. Long-term: session history compaction / summarization would convert unbounded inflow into bounded stock; until then restarts are the release valve.

## Verdict (Compact)

Ticket diagnosis is sound and actionable. Primary cause is static WSL2 caps saturated by monotonic session RSS plus parallel load, converted into relay accept latency by eager swap and 14-on-6 oversubscription. `dropcache` is correctly identified as ineffective. Execute P1 immediately, P2+P3 at next shutdown window, P4 with explicit OOM policy, P5 as quantified gate. No cannot-comprehend condition: domain fully comprehended from ticket body plus repo context (docker-compose dev+postgres shape, current nproc=12 observation).
