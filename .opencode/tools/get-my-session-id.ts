/**
 * get-my-session-id — returns the current session ID.
 * The orchestrator calls this once at boot to populate parent_session_id
 * in registry.jsonl and ticket frontmatter. Uses the canonical custom-tool
 * shape (tool() helper from @opencode-ai/plugin/dist/tool — see tool.d.ts:
 * { description, args: ZodRawShape, execute(args, context) }); the tool name
 * is derived from the file name, not from a `name` field.
 * Tickets System 2.0 Phase 3 (ai--2 §5 — no native LLM-visible surface
 * for orchestrator session id; custom-tool context is the bridge).
 */
import { tool } from "@opencode-ai/plugin"

export default tool({
  description:
    "Returns the current OpenCode session ID and agent name (used for delegation attribution)",
  args: {},
  async execute(_args, context) {
    // Returned as a text result in the same `key: value` line convention the
    // delegation parser understands, so downstream consumers can grep it.
    return [
      `session_id: ${context.sessionID}`,
      `agent: ${context.agent}`,
    ].join("\n")
  },
})
