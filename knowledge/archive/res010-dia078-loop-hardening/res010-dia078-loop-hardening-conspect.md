res010 — DIA-078: Loop hardening, doom_loop permission, and snip-wrapper behavior
=================================================================================

Created: 2026-08-10

Purpose
-------
This conspect synthesizes locally-archived sources about agent loop detection and
hardening patterns, OpenCode's `doom_loop` permission semantics, and plugin-based
anti-loop strategies. It grounds recommended mitigations for DIA-078 (coder
snip-wrapper loop recurrence) in the captured literature and maps those findings
to a concrete remediation: broaden the anti-snip guardrail (prompt generalization)
and set `doom_loop: deny` for the project critical session class.

Executive summary
-----------------
- OpenCode exposes a native `doom_loop` permission that fires when the same tool
  call repeats 3× with identical input; its default disposition is `ask` (opencode
  docs). Changing this to `deny` enforces mechanical blocking of immediate
  repetition rather than advisory prompting (opencode.ai/docs/permissions).
- External plugin approaches (e.g., `opencode-anti-loop`) implement richer
  detectors (argument/hash comparison, command streaks, identical-output
  detection, semantic cycles, ring buffers + hash fingerprints) and a
  graduated response model (advisory → block → compact/rollback) that maps
  directly onto the DIA-078 incident taxonomy.
- Degenerate-output detection (ring-buffer + normalized-hash comparison)
  complements per-command loop detectors by catching near-duplicate outputs and
  enabling visible escalation (model-swap or explicit marker) before shipping
  the repeated response.
- Practical fix for DIA-078: (1) generalize the anti-snip guardrail to match the
  entire `snip` prefix class (not only `snip jq`), and (2) configure
  `doom_loop: deny` for the project's default agent/permission block. Optionally
  adopt an `opencode-anti-loop`-style plugin or equivalent in-process detectors
  for graduated responses and richer telemetry.

Key concepts and evidence
-------------------------

1) doom_loop permission (semantics & defaults)

- Semantics: `doom_loop` triggers when the same tool call repeats 3 times with
  identical input. It is a first-class permission key in OpenCode's permission
  system (OpenCode documentation, "Permissions" section). (OpenCode Docs)
- Defaults: Unless configured, `doom_loop` defaults to `ask`, meaning the UI
  prompts the operator and offers `once|always|reject` outcomes. `ask` is
  permissive and therefore does not mechanically stop repeated identical tool
  calls. (OpenCode Docs)
- Configuration options: permissions are configurable per-tool and support
  object-syntax rules with pattern matching and agent-level overrides; the last
  matching rule wins. Setting `doom_loop: deny` enforces immediate blocking of
  identical repeated calls without an interactive prompt. (OpenCode Docs)

Evidence: opencode.ai/docs/permissions — OpenCode permission keys and defaults.

2) Anti-loop detection patterns (catalog)

- Argument / input hashing: normalize command arguments and inputs (strip
  timestamps, variable names) then hash; identical hashes → candidate loop.
- Ring buffer + fingerprint: maintain a small ring of recent tool calls /
  outputs (e.g., last 8–16). Before a new emission, normalize and compare for
  exact or near-duplicate matches (Jaccard/overlap thresholds for near-duplicates).
- Identical-output detection: per-command and global streaks (e.g., 3 runs of
  the same command producing identical output; or a 5-streak global identical
  output rule). Block at configured thresholds. (opencode-anti-loop)
- Command-streak detection: normalized-command streaks within a mutation epoch
  (file-write epoch), with whitelist exemptions for legitimate setup commands
  (installers, package managers). (opencode-anti-loop)
- Semantic-cycle detection: cluster sequences of actions by conceptual similarity
  (e.g., many scripts that probe the same root cause) and detect repeated
  conceptual cycles via prompt-novelty heuristics or low novelty percentage.
- Identical reasoning/output doom-loop extension: extend the doom-loop concept
  beyond explicit tool calls to repeated reasoning or identical model outputs
  (PR #12623 and related upstream work). This guards against repeated model-only
  emissions that nevertheless produce no new progress.

Evidence: opencode-anti-loop plugin README and detector breakdown; agent
patterns (Degenerate-Output Detection) for ring-buffer/near-duplicate handling;
PR #12623 for doom-loop reasoning/output extension.

3) Graduated response model: inform → constrain → escalate

- Inform (advisory): at N-1 thresholds attach advisory notes that recommend
  strategy changes but do not block. Useful for gentle steering and preserving
  developer agency during borderline cases. (opencode-anti-loop)
- Constrain (block): at configured thresholds, block the offending action and
  return an explicit error instructing the agent to change approach. This is a
  mechanical enforcement that prevents immediate repeated waste. (opencode-anti-loop)
- Escalate (compact / rollback / system override): after multiple consecutive
  blocks, escalate to session compaction, system-prompt injection, or session
  rollback to force a strategy pivot. Rollback is aggressive and should be
  opt-in (`allowRollback: false` by default). (opencode-anti-loop)

Evidence: opencode-anti-loop escalation behavior and agentpatterns recommendations.

4) Degenerate-output / model-output guards

- Maintain small ring buffer of recent outputs; normalize and compare (exact
  and near-duplicate thresholds). On hit: replace or mark the output and force
  escalation (model swap) or a prompt that forces a tool call. This prevents
  shallow generation loops that never call tools. (Agent Patterns Catalog)

Evidence: "Degenerate-Output Detection" pattern (agentpatternscatalog.org).

5) Snip wrapper behavior and project-specific risk (DIA-078 mapping)

- Problem in DIA-078: the anti-snip guardrail was narrowly scoped to `snip jq`
  rather than the whole `snip` prefix class, and the anti-loop prompt rule was
  only advisory (advice instead of mechanical enforcement). OpenCode's native
  `doom_loop` was left at default `ask`. The project also does not load the
  `opencode-snip` plugin (snip prefixing is model-learned), so environment-level
  rewrite protections are absent.
- Mapping to mitigations:
  - Generalize guard: broaden the input pattern to match the full `snip` prefix
    class (pattern-based permission rule in `opencode.jsonc`) so all snip-* tool
    invocations are covered.
  - Harden `doom_loop`: set `doom_loop: deny` for the project/global permission
    block (and/or per-agent override) to enforce mechanical blocking of rapid
    identical tool calls. This prevents repeated `snip make test-config` loops
    from proceeding without operator action.
  - Supplement with detectors: add either the `opencode-anti-loop` plugin or
    lightweight in-process detectors implementing argument-hash, command-streak,
    and identical-output detection to catch broader loop patterns and provide a
    graduated response.

Evidence: opencode docs (permission keys & defaults), opencode-anti-loop plugin,
anomaly issue #28596 (report of exact-argument tool-call looping), and PR #12623
(`doom_loop` reasoning/output extension).

Unarchived sources
------------------
- https://langsight.dev/blog/ai-agent-loop-detection/ [source not archived — excluded per DIA-072 policy]
- https://hidekazu-c.com/ [source not archived — excluded per DIA-072 policy]
- https://docs.openclaw.ai/tools/loop-detection [source not archived — excluded per DIA-072 policy]

These URLs were attempted but could not be archived with the project's fallback
chain; their claims are therefore excluded from the conspect body per DIA-072.

Recommendations (actionable)
---------------------------
1. Immediately set `doom_loop: "deny"` in the project's permission block for
   the default agent and for any agent used in CI-like runs. Example (opencode
   JSON/YAML permission snippet):

   - set global/agent permission rule such that the `doom_loop` key resolves to
     `deny` for the `snip` prefix class.

2. Broaden the anti-snip pattern: change guard rules from the specific
   `snip jq` pattern to a prefix pattern `snip*` (or the project's canonical
   `snip` prefix matcher) so all model-learned snip invocations are covered.

3. Add an anti-loop detector (plugin or in-process) with these minimal checks:
   - normalized command hash + per-command identical-output streak detection (3×)
   - global identical-output streak detection (5×)
   - command-streak detection with setup-command exemptions
   - ring buffer for recent outputs to detect degenerate outputs (near-duplicate)
   - advisory at N-1, block at N, escalate after consecutive blocks

4. Logging & telemetry: persist loop-detection counters to a short-lived store
   (file or light DB) so restarts do not wipe the loop state during a suspicious
   session. At minimum, emit structured diagnostics when a block occurs so owners
   can triage false positives.

5. Developer education: update contributor docs (dev/ops checklist) to explain
   `doom_loop` behavior and how to configure per-agent overrides for legitimate
   long-running verification flows (use AGENT_PHASE to exempt verification
   phases as appropriate).

Selected citations (MLA-style)
-----------------------------

- "Permissions." opencode.ai, 2026, https://opencode.ai/docs/permissions. Accessed 10 Aug. 2026.
- joeyism. "opencode-anti-loop." GitHub, 2026, https://github.com/joeyism/opencode-anti-loop. Accessed 10 Aug. 2026.
- "Degenerate-Output Detection." Agent Patterns Catalog, 2026, https://www.agentpatternscatalog.org/patterns/degenerate-output-detection/. Accessed 10 Aug. 2026.
- anomalyco. "Issue #28596." GitHub, 2026, https://github.com/anomalyco/opencode/issues/28596. Accessed 10 Aug. 2026.
- Heinrich-XIAO. "fix: Doom-loop guard for repeated reasoning/output - #12623." GitHub, 8 Feb. 2026, https://github.com/anomalyco/opencode/pull/12623. Accessed 10 Aug. 2026.

End of conspect
