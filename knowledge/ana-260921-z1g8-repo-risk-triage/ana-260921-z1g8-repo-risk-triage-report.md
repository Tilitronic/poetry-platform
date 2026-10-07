# Repo Risk Triage (DIA-260821-bqy7) - 2026-09-21

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: docs/dev-infra-audit/tickets/DIA-260821-bqy7-audit-repository-risks-and-prioritize-unresolved-remediation.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Scope note

Ticket DIA-260821-bqy7 'audit repository risks and prioritize unresolved remediation'
ships with an empty template body (no Description, no Verification criteria).
There is no ticket-scoped definition of "risk", so this report triages at the
repository level: the OPEN ticket backlog as the risk register plus directly
observed repo-health signals. Domain is comprehensible; no cannot-comprehend
condition applies.

## Method

MECE partition of the OPEN backlog (file-level parse of
docs/dev-infra-audit/tickets/*.md on 2026-09-21) plus spot-checks of repo
state (CI presence, secrets ignore status, git worktree cleanliness).
Severity is taken from ticket front-matter; rank within a severity band is by
blast radius x exploitability x reversibility (security first, then delivery
integrity, then correctness, then ops, then hygiene).

## Backlog census (OPEN only, file-level parse)

- High: 12 OPEN | Major: 12 OPEN | Medium: 53 OPEN | Low: 7 OPEN
- CLOSED total per ledger: 237 (remediation throughput is healthy; the tail
  is concentrated in opencode-config: 169 tickets all-status, the dominant
  risk area by volume).
- NOTE: `scripts/tickets stats` reports "Blocker 8 / High 21 / Critical 21"
  but file-level front-matter parse finds zero OPEN `severity: Blocker` and
  zero OPEN `severity: Critical`. The stats rollup and front-matter disagree
  on severity vocabulary (HIGH vs Critical vs Blocker). Treat counts as
  approximate until DIA-234 human-readable-mention work normalizes the schema.
  The ranked table below uses front-matter values verbatim.

## Ranked risk table (High first, then Major; rank = remediation order)

| Rank | ID | Title (short) | Sev | Category | Why this rank |
| ---- | -- | ------------- | --- | -------- | ------------- |
| 1 | DIA-260827-ft3z | Shell permissions bypass write scopes via curl/wget redirection | High | Security | Active sandbox escape: write-scope policy unenforced for the most common exfil path. Exploitable today. |
| 2 | DIA-260827-gt8l | No enforced CI and pre-push gate fails open | High | Delivery | No .github/workflows exists (verified). All other gates are advisory until this closes. Fails open = silent regression. |
| 3 | DIA-260827-36ht | Plugin behavioral gate is red and missing from pre-push | High | Delivery | The one behavioral gate that would catch R1 is itself red AND unwired. Defense in depth is zero. |
| 4 | DIA-260826-ft3q | Audit prompt injection vectors and plugin trust boundaries | Major | Security | Open audit: injection surface across plugins unmapped. Pairs with R1/R5. |
| 5 | DIA-260826-uovr | Audit MCP server security permissions and usage | Major | Security | Open audit: MCP servers are third-party code with unclear perms. Pairs with R1/R4. |
| 6 | DIA-260827-txq2 | Inherited obsolete and duplicate plugins from base OMO config | High | Security/Config | Dead plugin surface = unreviewed attack surface + config drift source. Remove before auditing the rest. |
| 7 | DIA-260827-5blh | Handoff identity permits path traversal (MEDIUM tag, Major-sev family) | Medium* | Security | Path traversal in handoff identity. Listed here (promoted) because traversal is a write-primitive; verify actual severity tag. |
| 8 | DIA-260827-bry9 | OMO version and model-routing drift from baseline | High | Config | Silent model/routing drift changes behavior of every lane. Non-reproducible runs until pinned. |
| 9 | DIA-260827-4aqb | Agent routing bypasses tdd-craftsman RED-GREEN workflow | High | Workflow | Tests-after-code path is routable, so coverage numbers overstate protection. |
| 10 | DIA-260831-a1b2 | Test infra cold start cannot bootstrap prerequisites | High | Delivery | New-machine onboarding cannot verify anything; R2 (CI) cannot land on a broken bootstrap. Fix before CI. |
| 11 | DIA-260831-m3n4 | PoetryDataContract types schema not payload instance | High | Product | Schema validates the wrong thing: corrupt payloads pass type checks. Data-integrity hole in the product core. |
| 12 | DIA-260831-k1l2 | Editor orchestrator equal-revision overwrite breaks user priority | High | Product | User edits silently losable on equal-revision race. Data-loss class. |
| 13 | DIA-260827-6g6r | OpenSpec CLI commands unreachable from skills and agents | High | Workflow | Spec workflow tooling exists but is not callable where work happens; spec compliance degrades by default. |
| 14 | DIA-260827-jtvl | Reviewer and playwright-browser skill contracts broken | High | Workflow | Independent review lane + browser E2E lane both contract-broken; two quality gates down. |
| 15 | DIA-213 | Orchestrator scope limitation (delegation-only) | High | Workflow | Without scope fencing the orchestrator keeps making content decisions; root cause behind several workflow tickets. |
| 16 | DIA-260827-ic3r (Medium, promoted) | Resource-manager can delegate any lane (task allow unrestricted) | Medium* | Security | Unrestricted delegation = privilege-escalation primitive for a compromised lane. Promoted on exploitability. |
| 17 | DIA-260827-ld2l (Medium, promoted) | Memory-manager and designer over-granted permissions | Medium* | Security | Over-granted writers to persistent memory; poisoning path. Promoted; cheap fix (scope down). |
| 18 | DIA-206 | ai-specialist lane systemic empty-return failure | Major | Ops | Config-research lane returns empty; section-10 workflow stalls. 4 uncommitted knowledge/ana-* dirs observed (shelf-registration lag) are a symptom of lane friction. |
| 19 | DIA-207 | WSL memory/CPU cap exhaustion, vsock relay stalls | Major | Env | Dev-environment stability for WSL cohort; disconnects lose session state. |
| 20 | DIA-260824-iirx | Unified dev-container gap analysis + migration plan | Major | Env | Strategic fix for R19-class issues; analysis ticket, unblocks docker consolidation. |
| 21 | DIA-260822-medh | Session handoffs / context thresholds / auto-compaction audit | Major | Ops | Handoff reliability is the multi-session memory chain; mechanical-idle-rows (DIA-260827-ce63) and identity issues attach here. |
| 22 | DIA-260911-cz0y | Closure memory-disposition gate before ticket closure | Major | Hygiene | Tickets close without memory capture; lessons leak. Procedural, high leverage, low cost. |
| 23 | DIA-189 | Terminal session identity (names, attribution, Cyrillic) | Major | Ops | Misattributed notifications in parallel sessions; operational confusion, not data loss. |
| 24 | DIA-260921-6o4i | Console free-tier gate rejects -free models | Major | Config | Active friction on free-tier routing; narrow scope, recent (2026-09-21). Fix after security/delivery. |
| 25 | DIA-260821-cku1 | Minimal scripts/tickets update capability | Major | Tooling | Ticket mutation ergonomics; enabler, not a risk per se. Schedule with backlog hygiene. |
| 26 | DIA-234 | Datetime ticket IDs + human-readable mentions | Major | Tooling | Schema migration in flight; source of the stats-vs-front-matter severity mismatch noted above. Finish to unblock reliable triage. |

\* Three Mediums promoted into the ranked table on exploitability grounds
(5blh traversal, ic3r delegation, ld2l over-grant). All other Mediums (50)
stay in the backlog queue.

## MECE category summary

```
Security & trust boundary : R1, R4, R5, R6, R7*, R16*, R17*  (7 - do first)
Delivery integrity (CI/gates/tests): R2, R3, R10 (+7mtr coverage, gnrr, nza6, e5f6 in backlog)
Config & routing          : R8, R24, R26 (+8la4, bry9 family)
Workflow & orchestration  : R9, R13, R14, R15 (+l7m8, 211, 6g6r family)
Product correctness       : R11, R12 (+x3y4, v1w2, t9u0, r7s8 atlas cluster)
Environment & ops         : R18, R19, R20, R21, R23 (+x5nj, ifcf, wawy)
Hygiene & backlog         : R22, R25 (+4y5v shelf hygiene, 91qy commit sweep, 2ztf format gate)
```

## Directly observed repo-health signals (2026-09-21)

1. No CI: `.github/workflows/` does not exist. Husky pre-commit/pre-push
   hooks exist locally but enforcement is client-side only. Confirms R2.
2. Secrets hygiene OK: `secrets/*_api_key` and `.env` are gitignored
   (`git check-ignore` confirms); only `secrets/README.md` is tracked.
   No credential leak in git. The risk is local-exposure scope (R5 audit
   should confirm who reads secrets/).
3. Shelf-registration lag: 4 untracked `knowledge/ana-260921-*/` dirs
   (5ort, dwtc, yl7m, yq8u) pending commit. Matches R22: memory disposition
   is manual and lossy. Commit sweep ticket DIA-260901-91qy covers the pattern.
4. Throughput healthy: 237 CLOSED vs 84 OPEN; VERIFIED 27 awaiting closure
  needs attention - VERIFIED-to-CLOSED promotion (R22 gate) would shrink the
   apparent backlog fastest.

## Recommended remediation sequence (3 waves)

- Wave 1 (security + delivery spine, R1-R10): close sandbox bypass (R1),
  land minimal enforced CI (R2, needs R10 bootstrap fix first), wire the
  behavioral gate into pre-push (R3), finish the two security audits
  (R4, R5), delete obsolete plugins (R6), disposition the three promoted
  Mediums (R7, R16, R17), pin OMO version/routing (R8).
- Wave 2 (correctness + workflow, R11-R17): schema-vs-payload (R11),
  equal-revision overwrite (R12), unreachable OpenSpec CLI (R13), reviewer/
  playwright contracts (R14), orchestrator scope fence (R15).
- Wave 3 (ops + hygiene, R18-R26): empty-return lane (R18), WSL caps (R19)
  alongside unified-container plan (R20), handoff audit (R21), closure gate
  (R22), session identity (R23), free-tier gate (R24), tickets-update tool
  (R25), ticket-ID normalization (R26, unblocks future triage accuracy).

Smallest first step with the largest blast-radius reduction: R1 (shell
write-scope bypass) + R10 (cold-start bootstrap) in parallel - one closes
the live escape hatch, the other unblocks CI which makes every later fix
verifiable.

## Risks explicitly NOT prioritized (and why)

- Atlas/js-tooling cluster (r7s8, t9u0, v1w2, x3y4, z5a6, d9e0, f1g2):
  real tech debt but narrow blast radius, no security or delivery-gate
  impact. Wave 3 or later.
- Ponytail over-engineering audits (wprb, 15xv): style debt, reversible,
  no failure mode. Backlog.
- Promo/preset churn (ch3o, s95f, mm2u, rbqk, ubxv, vsq8, yug6, ok9m):
  high ticket count, low per-ticket severity, mostly config cosmetics.
  Batch after the spine is green.
- Low/Info (31+3): tracer bullets and cleanups; schedule opportunistically.

## Limitations

- Ticket bodies for most OPEN items were not deep-read; ranking uses
  title + severity + area + the small set of bodies sampled during triage.
  Wave-1 tickets deserve a pre-dispatch body read before implementation.
- Severity vocabulary drift (Blocker/Critical/HIGH/Major) means any
  severity-sorted view is approximate until DIA-234 normalizes the schema.
- No test execution or code inspection was performed; this is a
  backlog-and-posture triage, not a code audit.
