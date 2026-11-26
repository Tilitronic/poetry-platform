# DIA-260910-sjtk model routing findings (2026-09-11)

Source: ai-specialist lane ses_f7030c4b4ffe5bfJCfmw1qc3oN (completed). AGENTS.md 2.5 step 1 registration. Docs-only, no config edits.

Active preset: muse-qwen-balanced.

Baseline note (corrected 2026-09-11, GO-WITH-CHANGES scope): the
"Baseline snapshot" column below is the PRE-CHANGE routing observed before
this ticket. It is context only, not the post-change state. The final
effective state for THIS ticket (DIA-260910-sjtk) is architector =
openai/gpt-5.6-sol high primary + opencode/big-pickle fallback, and nothing
else. All other proposed routings in the table are out of scope here; Terra
4-surface changes belong to DIA-260911-rqmw.

## Findings table

| Agent | Baseline snapshot (pre-change routing) | Proposed routing |
| --- | --- | --- |
| architector | github-copilot/gemini-3.1-pro-preview primary, opencode/big-pickle fallback | openai/gpt-5.6-sol high primary + big-pickle fallback |
| coder | opencode-go/muse-spark-1.3-contributor primary, opencode-go/deepseek-v4-flash fallback | opencode/muse-spark-1.3-contributor-free primary, openai/gpt-5.6-luna medium secondary, no Go fallback |
| researcher | same pattern as coder | same pattern as coder (Free primary, Luna medium secondary, no Go fallback) |
| resource-manager | opencode/mimo-v2.5-free medium | openai/gpt-5.6-luna medium single-model, no Go fallback |
| code-navigator | Luna low pattern (same family) | openai/gpt-5.6-luna medium single-model (developer decision 2026-09-11 supersedes low) |
| memory-manager | Free primary + Go fallback | opencode/mimo-v2.5-free primary + openai/gpt-5.6-luna medium, no Go fallback |
| coder-escalated | opencode-go/kimi-k3 direct override | openai/gpt-5.6-terra high (developer decision 2026-09-11; one-shot rule retained) |
| ai-auditor | secondary fallback references unavailable gemini | residual risk, out of approved scope, left unchanged |

## Validity

- openai/gpt-5.6-sol high: supported.
- openai/gpt-5.6-luna low / medium / high / xhigh / max: supported.
- opencode/muse-spark-1.3-contributor-free (Zen): valid.
- opencode/big-pickle (Zen): valid.
- Sources: OpenAI model docs for sol / luna; opencode.ai zen / go docs.

## Auth

- Direct openai routing needs OpenAI auth in ~/.local/share/opencode/auth.json.
- Smoke check required: /models smoke for sol + luna with non-empty output.
- Historical DIA-260909-uv53 smoke dated 2026-09-09 is NOT proof of current creds; re-verify before applying routing.

## Edit-targets (.opencode/oh-my-opencode-slim.jsonc)

- architector: lines 707-727.
- coder: lines 747-763.
- researcher: lines 886-902.
- resource-manager: lines 854-863.
- code-navigator: lines 877-884.
- memory-manager: lines 865-875.
- ai-auditor gemini fallback: out of approved scope, do not touch in this lane.

Note: targets recorded for a future implement lane. This file makes no config edits.

## Risks

- Auth failure skips Luna / Sol entries; chain falls through to remaining fallbacks.
- Fallback arrays react to provider errors, not to silent empty output; empty output is not a fallback trigger.
- Muse Free caution: training-on-prompts concern, keep sensitive prompts off Free routing.
- Sol pricing: 4 / 20 per 1M tokens.
- Luna caveat: subagent-weak, keep it on low-tier background lanes (resource-manager, code-navigator, memory-manager, researcher secondary), not on primary reasoning lanes.

## Sources

- OpenAI model docs (sol / luna variants and supported variants).
- opencode.ai zen / go docs (Muse Free Zen validity, big-pickle Zen validity).
- Prior smoke: DIA-260909-uv53 (2026-09-09, stale, re-verify).

## Outcome (final, 2026-09-11, corrected GO-WITH-CHANGES scope)

- Final effective state for DIA-260910-sjtk: architector openai/gpt-5.6-sol
  high primary + opencode/big-pickle fallback ONLY. No other lane is changed
  by this ticket.
- The remaining table rows (orchestrator / coder / researcher / memory-manager
  / code-navigator / resource-manager / coder-escalated proposals) are
  baseline-plus-proposal context, NOT landed state for this ticket. Terra
  4-surface changes (opencode.jsonc direct route, OMO coder-escalated hunk,
  coder-escalated.md, AGENTS.md table row) belong to DIA-260911-rqmw and are
  left uncommitted there.
- Luna Medium only: the earlier Luna Low target for code-navigator / resource-manager is superseded by developer decision 2026-09-11 (tracked outside this ticket).

## Confidence

- Routing table: High (verbatim from ai-specialist lane output).
- Model validity: Medium-High (docs-backed, secondhand via lane, not independently re-fetched here).
- Auth state: Low until fresh /models smoke passes (stale 2026-09-09 smoke only).
- Line numbers: Medium (config file drifts; re-confirm at implement time).
