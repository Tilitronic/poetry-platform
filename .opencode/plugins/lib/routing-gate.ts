/**
 * routing-gate lib — SRP extraction from delegation-observer.ts (DIA-260827-uv).
 *
 * Single source of truth for the DIA-230 routing-order gate decision logic,
 * shared by BOTH the plugin gate and scripts/__tests__/routing-order-gate.test.mjs
 * (node:test imports this file directly — Node >=23 strips erasable TS by
 * default, so keep this module to erasable syntax only: no enums, namespaces,
 * or parameter properties).
 *
 * NOTE (DIA-260827-uv c): no dcp.jsonc token — that file was deleted long ago
 * (DIA-260821-8kpc); blocking on a ghost path is wrong.
 */

import {
  existsSync as fsExistsSync,
  readFileSync as fsReadFileSync,
} from "node:fs"

// Config-work path pattern: matches .opencode/ config directories, config
// files, and agent instruction files listed in AGENTS.md section 2.5.
// Deliberately excludes .opencode/session/* and .opencode/learnings/*
// (runtime artifacts, not config).
export const CONFIG_WORK_PATTERN =
  /(\.opencode\/plugins\/|\.opencode\/oh-my-opencode-slim|orchestrator_append\.md|\.opencode\/agents\/|\.opencode\/skills\/|\.opencode\/commands\/|\.opencode\/rules\/|opencode\.jsonc|AGENTS\.md|practice-protected\.md)/i

/** Detect if a dispatch text contains config-work path indicators. */
export function isConfigWorkDispatch(dispatchText: string): boolean {
  return CONFIG_WORK_PATTERN.test(dispatchText)
}

/** Check if a subagent type is a coder variant. */
export function isCoderAgent(subagentType: string): boolean {
  return subagentType === "coder" || subagentType === "coder-escalated"
}

type FsDeps = {
  existsSync: typeof fsExistsSync
  readFileSync: typeof fsReadFileSync
}

function resolveDeps(partial?: Partial<FsDeps>): FsDeps {
  return {
    existsSync: partial?.existsSync ?? fsExistsSync,
    readFileSync: partial?.readFileSync ?? fsReadFileSync,
  }
}

/**
 * Scan messages.jsonl for a prior @ai-specialist dispatch in a session.
 * Delegation rows (event_type "delegation") do not carry session_id in their
 * payload, so we match the paracrine dispatch.started signal (DIA-220) which
 * carries both session_id and the agent name.
 * Fail-closed: missing file -> false; unreadable/malformed -> false.
 */
export function hasPriorAiSpecialistDispatch(
  messagesPath: string,
  sessionId: string,
  depsOverride?: Partial<FsDeps>
): boolean {
  const deps = resolveDeps(depsOverride)
  if (!deps.existsSync(messagesPath)) return false
  let lines: string[]
  try {
    lines = (deps.readFileSync(messagesPath, "utf-8") as unknown as string)
      .split("\n")
      .filter(Boolean)
  } catch {
    return false
  }
  return lines.some((line) => {
    try {
      const row = JSON.parse(line) as Record<string, unknown>
      return (
        row.session_id === sessionId &&
        row.agent === "ai-specialist" &&
        row.event_type === "paracrine" &&
        row.signal_type === "dispatch.started"
      )
    } catch {
      return false
    }
  })
}

export type RoutingGateInput = {
  subagentType: string
  dispatchText: string
  messagesPath: string
  sessionId: string
}

export type RoutingGateResult = {
  violation: boolean
  reason: string
}

/**
 * Full routing-order gate decision: coder variant + config-work paths +
 * no prior @ai-specialist dispatch in this session => violation.
 * Mirrors the tool.execute.before control flow in delegation-observer.ts
 * (fires BEFORE any ticket-gate early return).
 */
export function evaluateRoutingGate(
  input: RoutingGateInput,
  depsOverride?: Partial<FsDeps>
): RoutingGateResult {
  if (!isCoderAgent(input.subagentType)) {
    return { violation: false, reason: "not a coder agent" }
  }
  if (!isConfigWorkDispatch(input.dispatchText)) {
    return { violation: false, reason: "no config-work paths detected" }
  }
  if (
    hasPriorAiSpecialistDispatch(input.messagesPath, input.sessionId, depsOverride)
  ) {
    return { violation: false, reason: "prior @ai-specialist dispatch found" }
  }
  return { violation: true, reason: "no prior @ai-specialist dispatch" }
}

/** Prefix the catch-block re-throw condition matches on (alongside TICKET GATE:). */
export const ROUTING_GATE_PREFIX = "ROUTING GATE:"

/** Blocking error thrown when the routing-order gate fires. */
export function buildRoutingGateError(): Error {
  return new Error(
    "ROUTING GATE: @coder dispatched on config-work without prior @ai-specialist gate review.\n" +
      "AGENTS.md section 2.5 requires:\n" +
      "  1. @ai-specialist gate research -> findings registered in .opencode/learnings/external-patterns/\n" +
      "  2. User reviews & approves findings\n" +
      "  3. THEN @coder implementation can proceed\n" +
      "Action: dispatch @ai-specialist first."
  )
}
