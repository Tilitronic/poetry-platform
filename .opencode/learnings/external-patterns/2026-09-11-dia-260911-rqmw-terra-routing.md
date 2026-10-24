# DIA-260911-rqmw Terra routing findings (2026-09-11)

Source: ai-specialist lanes ses_f7030c4b4ffe5bfJCfmw1qc3oN (sjtk gate,
2026-09-11) and ses_f78af1609ffeHxLPTAAlbS8u95 (18f4 gate, 2026-09-09).
Section 2.5 step 1 registration for DIA-260911-rqmw. Docs-only, no config
edits made by this file.

## Finding 1: Terra High is a valid paid escalation for coder-escalated

- Model: openai/gpt-5.6-terra at high reasoning variant.
- Pricing (res013, Tier-1 cached): short-context <=272K $2.00/$12.00 per 1M;
  long-context >272K $4.00/$18.00 per 1M. Registry quota_notes previously
  labeled the short-tier price as the >272K tier price; corrected under rqmw.
- Reasoning: none/low/medium/high/xhigh/max ladder accepted; high is the
  approved escalation effort (developer decision 2026-09-11).
- Tools: Terra supports the full tool set (web_search, file_search,
  code_interpreter, hosted_shell, apply_patch, skills, computer_use, mcp,
  tool_search), structured outputs, and prompt caching (res016).
- Availability: live PASS 2026-09-09 probe TERRA-PROBE-OK
  (opencode run -m openai/gpt-5.6-terra --variant high, non-empty,
  self-reported model match, no 429/401). Direct OpenAI provider auth
  required; re-verify with a fresh smoke before landing.
- One-shot policy: RETAINED. Single dispatch per escalation, NEVER retry on
  the same task. On failure the orchestrator asks the developer via
  wait_for_user before another paid escalation is attempted. The old
  kimi-k3 490 req/mo cap language and the automatic
  deepseek-v4-pro/mimo-v2.5-pro fallback chain are retired with the kimi
  route; paid escalation is developer-gated, not fallback-chained.

## Finding 2: 5-surface atomic set (owned by rqmw, nothing else)

1. .opencode/opencode.jsonc - coder-escalated direct route
   opencode-go/kimi-k3 -> openai/gpt-5.6-terra (comment block updated,
   one-shot rule kept, developer direction after failure).
2. .opencode/agents/coder-escalated.md - agent contract (3 hunks:
   description, Role model line, ONE-SHOT rule rewrite to paid
   developer-gated wording).
3. AGENTS.md - agent-name table coder-escalated row Kimi K3 -> GPT-5.6
   Terra High. Table has prettier rewrap churn; stage the semantic row
   line precisely via targeted patch, never the full rewrap.
4. .opencode/oh-my-opencode-slim.jsonc - muse-qwen-balanced
   coder-escalated hunk (kimi-k3/max + deepseek-v4-pro/max -> terra/high,
   variant max -> high) PLUS the agents.coder-escalated orchestratorPrompt
   line ONLY.
5. knowledge/model-registry.yaml - routing_table Rung3 kimi-k3 ->
   openai/gpt-5.6-terra (one-shot comment kept), Terra quota_notes
   long-context price corrected to $4.00/$18.00, kimi-k3 entry retired,
   coder-escalated added to Terra lanes.

## Finding 3: preset churn excluded, with owner rule

- The muse-qwen-balanced orchestrator / coder / researcher /
  resource-manager / memory-manager / code-navigator hunks in the same
  slim jsonc diff (Muse Free / Luna Medium routing) are NOT rqmw scope.
  They belong to DIA-260909-csds and neighboring routing tickets.
- Owner rule: a ticket stages ONLY hunks whose owning lane matches its own
  scope. Shared-file coexistence is handled by selective hunk staging
  (git apply --cached with a filtered patch), never by landing another
  ticket's hunks as a side effect.
- Forbidden in the rqmw commit: csds ticket file, tickets README rollup,
  knowledge dir outside model-registry.yaml, .opencode/memory files,
  openspec dirt, and any preset-churn hunk. Verify with a staged grep
  before commit; all must show zero hits.

## Outcome

- Implementation order for rqmw: this file first, then registry Rung3 +
  price edit, then ticket Fix scope fill, then CHANGELOG.yaml entry +
  render + validate, then selective staging, then make test-config +
  git diff --check (both exit 0) + OpenCode restart with resolver check +
  fresh Terra High non-empty smoke, then isolated commit.
