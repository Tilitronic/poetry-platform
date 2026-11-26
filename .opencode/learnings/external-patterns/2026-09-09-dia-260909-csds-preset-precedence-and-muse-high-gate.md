# DIA-260909-csds preset precedence and Muse high gate

Date: 2026-09-09
Status: pending runtime smoke and independent audit

- OMO 2.2.17 stores `/preset` best-effort in user config. On process startup,
  `loadPluginConfig()` merges user config first and project config second, so
  the project's root `preset` wins. `OH_MY_OPENCODE_SLIM_PRESET` is the sole
  higher-priority override.
- Therefore, a project-specific persistent default must change the root
  `preset` pointer in `.opencode/oh-my-opencode-slim.jsonc`; a slash-command
  selection alone is not durable against a project pointer.
- Live OpenCode Go catalog lists `opencode-go/muse-spark-1.3-contributor`.
  Its `high` variant must be proven in the connected runtime before commit.
- Muse Contributor is paid Go allowance and permits training on prompts and
  completions; it is not ZDR. Routing the orchestrator to it requires explicit
  developer privacy acceptance. Never put secrets in dispatch text.
