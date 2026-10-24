# Terra routing gate findings - DIA-260909-18f4 (2026-09-09)

Gate: ai-specialist, section 2.5 step 1, session ses_f78af1609ffeHxLPTAAlbS8u95.
Scope: read-only verification. No preset/registry/config edits made.

## Active-preset qwen3.8-flash occurrences (5, all under muse-qwen-balanced)

File: .opencode/oh-my-opencode-slim.jsonc (preset block starts L687).

1. L730 - openspec-plan primary: "opencode-go/qwen3.8-flash" first of 2-entry list.
2. L766 - reviewer primary: "opencode-go/qwen3.8-flash" first of 2-entry list.
3. L779 - analyzer primary: "opencode-go/qwen3.8-flash" first of 2-entry list.
4. L827 - ai-specialist primary: "opencode-go/qwen3.8-flash" first of 3-entry list.
5. L933 - analyzer-escalated fallback: bare "opencode-go/qwen3.8-flash" second entry after deepseek-v4-pro max object.

## Essential locksteps for any Terra retarget

- .opencode/opencode.jsonc L607: inline "model": "opencode-go/qwen3.8-flash" on the
  ai-specialist agent MUST be REMOVED, not retargeted. Inline wins over preset
  file entries in the NPM runtime; leaving any inline value preserves the
  dual-runtime divergence the DIA-128 cleanup removed.
- knowledge/model-registry.yaml: needs a Terra entry per DIA-133. Verified
  2026-09-09: grep -i terra returns zero hits, so the registry step is still open.
- Council seat untouched: .opencode/oh-my-opencode-slim.jsonc L1169+ council block
  uses deepseek-v4-pro seat; no Terra or qwen entry there. Routing change must not
  touch council composition.

## Cost and quota context

- Cost delta approx 13x/25x (Terra vs qwen flash) with the 27K context cap removed.
  Terra is priced as a flagship reasoning model; do not route bulk lanes to it.
- 429 quota history: DIA-260827-qc59 records prior Terra/OpenAI quota exhaustion.
  Any rollout must keep qwen/flash fallbacks in the model lists so a 429 degrades
  to fallback instead of failing the lane.

## EBDV variants (A/B/C/D)

- A (gated recommendation): route ai-specialist primary to openai/gpt-5.6-terra
  behind the live-availability gate (key present + catalog listed + probe PASS).
- B: route reviewer/analyzer instead of ai-specialist (rejected: wider blast radius).
- C: dual-list Terra first with qwen fallback, no lockstep cleanup (rejected:
  leaves inline L607 divergence in place).
- D (status quo / abort): keep qwen3.8-flash everywhere (fallback if gate FAILs).

Recommendation: Variant A, gated on this file's live-gate PASS.

## Live-gate result 2026-09-09 (verification-only)

- secrets/openai_api_key: PRESENT non-empty (test -s PASS, mode 600).
- auth.json: openai entry PRESENT (keys: github-copilot, openai, opencode-go).
- Catalog: openai/gpt-5.6-terra LISTED (plus -fast sibling); opencode-go/gpt-5.6-terra
  count 0 (phantom check PASS).
- Preset: "preset": "muse-qwen-balanced" (slim L3 and L687); OH_MY_OPENCODE_SLIM_PRESET
  unset (no override).
- Probe: opencode run -m openai/gpt-5.6-terra --variant high returned non-empty
  "TERRA-PROBE-OK openai/gpt-5.6-terra", self-reported model match, no 429/401,
  no fallback events, stderr empty. GATE-PASS.

## Outcome (close-out 2026-09-09, DIA-260909-18f4 CLOSED)

- Variant A implemented as gated: 5 active-preset loci Terra-first with
  fallbacks kept; L607 inline removed; registry Terra entry added.
- Auditor GO-with-notes; notes closed (preset comment refreshed to Terra
  composition; routing_table Analyzer rows aligned, Rung2 divergence noted).
- Fresh close-out probe TERRA-SMOKE-OK (exit 0); test-config/drift/names 0;
  serve 200 host; changelog validated+rendered; full TUI restart deferred.
