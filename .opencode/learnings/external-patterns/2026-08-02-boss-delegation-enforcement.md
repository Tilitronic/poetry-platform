---
date: 2026-08-02
source: orchestrator audit + ai-specialist gate research (ses_03e5d3d07ffe0eZCd5dTKuuuFJ)
finding: |
  Symptom: boss agent performs engineering work itself instead of delegating → context overflow
  in seconds, session restarts. Root cause (verified against running plugin, not fork source):

  1. `default_agent: "boss"` (opencode.jsonc:15) resolves to a BARE config agent
     (`agent.boss` = model + color only, no prompt, no permission restrictions).
     The npm oh-my-opencode-slim@2.2.8 plugin registers its primary as `orchestrator`
     (`ALL_AGENT_NAMES = ["orchestrator", ...]`). The plugin's config hook only overrides
     `default_agent` when it is unset OR a subagent (dist/index.js:40216-40222). `boss` is a
     truthy primary → NOT overridden → sessions start in the bare boss.
  2. The strict delegation content is dead config:
     - `.opencode/oh-my-opencode-slim/boss_append.md` (HARD RULE + interview gate + context
       budgets) — 2.2.8 loads `${agentName}_append.md` = `orchestrator_append.md` (dist:
       readFirstPrompt at loadAgentPrompt), NOT `boss_append.md`. grep for `boss_append` in
       dist = 0 hits. Prior 2026-08-02 interview-gate enforcement assumed it was loaded.
     - Fork `.opencode/oh-my-opencode-slim/src/agents/boss.ts` (strict buildBossPrompt,
       `createBossAgent` → name `boss`) is NOT built (no dist/) and NOT referenced in the
       plugin array (npm 2.2.8 in both project and global config).
  3. The stock 2.2.8 orchestrator prompt (dist/index.js:19216-19319) explicitly permits direct
     work ("Handle work directly only when it is one isolated, clear, low-risk action...") and
     injects WRITABLE_FILE_OPERATIONS_RULES (edit/write/apply_patch guidance) into its own
     prompt. No permission enforcement on either boss or orchestrator.
  4. ai-specialist's first-pass report wrongly validated against the FORK source (index.ts:473
     default_agent='boss', index.ts:495 loadAgentPrompt('boss')) instead of the deployed npm
     2.2.8. Corrected by orchestrator: fork claims rejected, keep-alive logic verified.

  Correction to prior Option C decision: keeping npm 2.2.8 unchanged is fine, but the boss must
  be made to RUN the plugin's orchestrator (default_agent: "orchestrator") with (a) a loaded
  `orchestrator_append.md` strict-workflow prompt and (b) mechanical permission enforcement
  (edit/write/apply_patch deny; bash verification allowlist; orchestration tools allow).
  Prompt-only enforcement is insufficient (ana004 §5: model-level bypass of soft rules).

action: config change implemented + independent review + CHANGELOG registered (2026-08-02). Restart + smoke test pending user.
status: applied
evidence: |
  - dist/index.js:40216-40222 default_agent conditional override (verified)
  - dist/index.js:40237-40241 user agent config merges over plugin agent (`{...pluginAgent, ...existing}`)
  - dist/index.js:19102-19103 readFirstPrompt(`${agentName}_append.md`)
  - runtime log: [plugin] resolved model from array {"agent":"orchestrator",...} — no `boss` anywhere
---
