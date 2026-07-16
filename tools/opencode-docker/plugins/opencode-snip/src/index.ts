import type { Hooks, Plugin } from "@opencode-ai/plugin"

const ENV_VAR_RE = /^([A-Za-z_][A-Za-z0-9_]*=[^\s]* +)*/
const OPERATOR_RE = /(\s*(?:&&|\|\||;)\s*|\s&(?![>])\s?|\r?\n)/
const OPERATOR_ONLY_RE = /(\s*(?:&&|\|\||;)\s*|\s&(?![>])\s?)/
const HEREDOC_RE = /<<-?\s*['"]?\w/
const HEREDOC_DELIM_RE = /<<-?\s*['"]?(\w[\w.-]*)/
const POWERSHELL_SKIP_RE = /^[$@&{]/
const POWERSHELL_CMDLET_RE = /^[A-Z][a-zA-Z]*-[A-Z]/i

// Commands snip has no filter for — skip wrapping entirely (no stderr noise)
const SNIP_UNPROXYABLE = new Set([
  "cat", "echo", "pwd", "whoami", "true", "false",
  "ls", "cp", "mv", "rm", "mkdir", "touch", "chmod", "chown",
  "cd", "source", ".", "export", "alias", "unset", "set",
  "head", "tail", "wc", "date", "dirname", "basename",
])

function stripSnipPrefixes(cmd: string): string {
  let s = cmd.trimStart()
  while (s.startsWith("snip ")) {
    s = s.slice(5).trimStart()
  }
  return s
}

async function snipCommand(
  command: string,
  shouldWrap: (cmd: string) => Promise<boolean>,
): Promise<string> {
  const envPrefix = (command.match(ENV_VAR_RE) ?? [""])[0]
  const bareCmd = stripSnipPrefixes(command.slice(envPrefix.length).trim())
  if (!bareCmd) return command
  if (bareCmd.startsWith("snip ") || bareCmd.startsWith("run -- ")) return command

  const firstWord = bareCmd.split(/\s+/)[0]
  if (process.platform === "win32" && POWERSHELL_SKIP_RE.test(bareCmd)) return command
  if (process.platform === "win32" && POWERSHELL_CMDLET_RE.test(firstWord)) return command
  if (SNIP_UNPROXYABLE.has(firstWord)) return command

  if (await shouldWrap(bareCmd)) {
    return `${envPrefix}snip run -- ${bareCmd}`
  }
  return command
}

interface PipeSplit {
  segments: string[]
  operators: string[]
}

function splitByPipe(command: string): PipeSplit {
  const segments: string[] = []
  const operators: string[] = []
  let current = ""
  let inSingleQuote = false
  let inDoubleQuote = false

  for (let i = 0; i < command.length; i++) {
    const char = command[i]
    if (char === "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote
      current += char
    } else if (char === '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote
      current += char
    } else if (char === "|" && !inSingleQuote && !inDoubleQuote) {
      if (command[i + 1] === "|") {
        i++
        continue
      }
      segments.push(current)
      current = ""
      if (command[i + 1] === "&") {
        operators.push("|&")
        i++
      } else {
        operators.push("|")
      }
    } else {
      current += char
    }
  }
  segments.push(current)
  return { segments, operators }
}

async function snipSegment(
  segment: string,
  shouldWrap: (cmd: string) => Promise<boolean>,
): Promise<string> {
  if (HEREDOC_RE.test(segment)) {
    return snipCommand(segment, shouldWrap)
  }

  const { segments, operators } = splitByPipe(segment)
  if (segments.length === 1) {
    return snipCommand(segment, shouldWrap)
  }

  let result = await snipCommand(segments[0].trim(), shouldWrap)
  for (let i = 1; i < segments.length; i++) {
    result += ` ${operators[i - 1]} `
    result += await snipCommand(segments[i].trim(), shouldWrap)
  }
  return result
}

export function createToolExecuteBefore(shouldWrap: (cmd: string) => Promise<boolean>) {
  return async (
    input: Parameters<NonNullable<Hooks["tool.execute.before"]>>[0],
    output: Parameters<NonNullable<Hooks["tool.execute.before"]>>[1],
  ) => {
    try {
      if (input.tool !== "bash") return

      const command = output.args.command
      if (!command || typeof command !== "string") return
      if (command.startsWith("snip run -- ")) return

      if (HEREDOC_RE.test(command)) {
        const heredocMatch = command.match(HEREDOC_DELIM_RE)
        if (heredocMatch) {
          const delimiter = heredocMatch[1]
          const bodyStart = heredocMatch.index! + heredocMatch[0].length
          const bodyEnd = command.indexOf(delimiter, bodyStart)
          if (bodyEnd !== -1) {
            const heredocPart = command.slice(0, bodyEnd + delimiter.length)
            const afterPart = command.slice(bodyEnd + delimiter.length)
            const afterSegments = afterPart.split(OPERATOR_RE)
            const results: string[] = [await snipSegment(heredocPart, shouldWrap)]
            for (const seg of afterSegments) {
              if (OPERATOR_RE.test(seg)) {
                results.push(seg)
              } else if (seg) {
                results.push(await snipSegment(seg, shouldWrap))
              }
            }
            output.args.command = results.join("")
            return
          }
        }
        output.args.command = await snipSegment(command, shouldWrap)
        return
      }

      const segments = command.split(OPERATOR_RE)

      if (segments.length === 1) {
        output.args.command = await snipSegment(command, shouldWrap)
        return
      }

      const results: string[] = []
      for (const segment of segments) {
        if (OPERATOR_RE.test(segment)) {
          results.push(segment)
        } else {
          results.push(await snipSegment(segment, shouldWrap))
        }
      }
      output.args.command = results.join("")
    } catch {
      // leave command unmodified on any unexpected error
    }
  }
}

export async function hasSnipSubcommands($: any): Promise<boolean> {
  try {
    await $`snip check -- ls`.nothrow().quiet()
    return true
  } catch {
    return false
  }
}

export const SnipPlugin: Plugin = async ({ $, client }) => {
  try {
    if (process.platform === "win32") {
      await $`where snip`.quiet()
    } else {
      await $`which snip`.quiet()
    }
  } catch {
    await client.app
      .log({ body: { service: "snip", level: "warn", message: "[snip] snip binary not found in PATH — plugin disabled" } })
      .catch(() => {})
    return {}
  }

  if (!(await hasSnipSubcommands($))) {
    await client.app
      .log({
        body: {
          service: "snip",
          level: "warn",
          message: "[snip] snip >= 0.16.0 required (snip check/run subcommands missing) — plugin disabled",
        },
      })
      .catch(() => {})
    return {}
  }

  const shouldWrap = async (cmd: string): Promise<boolean> => {
    try {
      const result = await $`snip check -- ${{ raw: cmd }}`.nothrow().quiet()
      return result.exitCode === 0
    } catch (err) {
      await client.app
        .log({
          body: {
            service: "snip",
            level: "warn",
            message: `[snip] snip check failed for ${cmd}`,
            extra: { error: String(err) },
          },
        })
        .catch(() => {})
      return false
    }
  }

  return {
    "tool.execute.before": createToolExecuteBefore(shouldWrap),
    "experimental.chat.system.transform": async (_input, output) => {
      output.system.push(
        "The snip plugin automatically prefixes eligible commands with `snip run --`. "
          + "Do NOT manually add `snip run --` to commands.",
      )
    },
  }
}

export default SnipPlugin
