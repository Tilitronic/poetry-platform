/**
 * bash-write-gate - pure bash write-tripwire classifier (DIA-260827-ft3z,
 * design.md D5).
 *
 * Accident protection for the two implementation lanes that keep a shell
 * (`coder`, `coder-escalated`): a command whose literal write destination
 * resolves under a protected literal is denied with the matched target and
 * the rule that fired. Everything else - including every out-of-scope lane
 * and an unresolvable lane (fail-open) - passes with `{ blocked: false }`.
 *
 * NOT a boundary (D5): this reads a command string and cannot see interpreter
 * writes (`python3 -c`, `node -e`) or future tools. Never document it as
 * provable. The typed fetch tool (D1-D4) is the provable control.
 *
 * Shared by the tool.execute.before hook (task 4.2) and
 * scripts/__tests__/tripwire-classifier.test.mjs (node:test imports this file
 * directly - Node >=23 strips erasable TS by default, so keep this module to
 * erasable syntax only: no enums, namespaces, or parameter properties; the
 * plugin tsconfig also enforces `erasableSyntaxOnly`).
 */

import { basename } from "node:path"

// D5 scope: only the two lanes that keep a shell. Any other lane (or an
// unresolvable one) is returned untouched without inspecting the command.
const SCOPE_LANES = new Set(["coder", "coder-escalated"])

// D5 protected set - fixed, not configurable.
const PROTECTED_LITERALS = [".git/", ".opencode/session/", "docs/dev-infra-audit/tickets/"]

// Tokens that end the current command segment when collecting positionals.
const SEGMENT_SEPARATORS = new Set(["|", "||", "&&", ";", "&"])

export type BashWriteVerdict =
  | { blocked: false }
  | { blocked: true; target: string; rule: string }

/**
 * Classify one bash command against the protected-path tripwire.
 * `rule` names the extraction form that fired (redirection, tee, curl -o, ...).
 */
export function classifyBashWrite(
  command: string,
  lane: string | undefined
): BashWriteVerdict {
  if (!lane || !SCOPE_LANES.has(lane)) return { blocked: false }

  const tokens = tokenize(command)
  for (const write of collectWrites(tokens)) {
    if (matchProtected(write.target) !== null) {
      return { blocked: true, target: write.target, rule: write.rule }
    }
  }
  return { blocked: false }
}

/**
 * Quote-aware tokenizer that splits redirection operators into their own
 * tokens, so `echo x > file`, `x>>file` and `1>file` all yield the
 * destination as a plain token. Quotes are stripped (destinations rarely
 * need their content) and a stray `1`/`2`/`&` fd prefix becomes a harmless
 * separate token.
 */
function tokenize(command: string): string[] {
  const tokens: string[] = []
  let current = ""
  let quote: string | null = null
  const flush = (): void => {
    if (current) tokens.push(current)
    current = ""
  }
  for (let i = 0; i < command.length; i++) {
    const ch = command[i]
    if (quote !== null) {
      if (ch === quote) quote = null
      else current += ch
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      continue
    }
    if (ch === ">") {
      flush()
      if (command[i + 1] === ">") {
        tokens.push(">>")
        i++
      } else {
        tokens.push(">")
      }
      continue
    }
    if (/\s/.test(ch)) flush()
    else current += ch
  }
  flush()
  return tokens
}

type Write = { target: string; rule: string }

/**
 * Extract every write destination from the explicit D5 form set. Unknown
 * forms contribute nothing (they are simply not classified as safe-by-rule -
 * they pass because no protected destination was matched).
 */
function collectWrites(tokens: string[]): Write[] {
  const writes: Write[] = []
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]

    // Redirection: `>`, `>>` (fd prefixes `1>`/`2>`/`&>` already split off).
    if (token === ">" || token === ">>") {
      const dest = tokens[i + 1]
      if (dest !== undefined) writes.push({ target: dest, rule: "redirection" })
      continue
    }

    if (!isCommandPosition(tokens, i)) continue
    const command = basename(token)

    if (command === "tee") {
      // tee FILE... - every positional until the next command segment.
      for (const target of positionalsAfter(tokens, i + 1)) {
        writes.push({ target, rule: "tee" })
      }
      continue
    }
    if (command === "dd") {
      for (let j = i + 1; j < tokens.length; j++) {
        const t = tokens[j]
        if (SEGMENT_SEPARATORS.has(t)) break
        if (t.startsWith("of=")) writes.push({ target: t.slice(3), rule: "dd of=" })
      }
      continue
    }
    if (command === "sed" && hasFlag(tokens, i + 1, "-i")) {
      // In-place edit: positionals are the script plus the file operands;
      // the script only false-positives if it embeds a protected path,
      // which fail-closing on is the intended accident posture.
      for (const target of positionalsAfter(tokens, i + 1)) {
        writes.push({ target, rule: "sed -i" })
      }
      continue
    }
    if (command === "sort") {
      const out = optionValue(tokens, i + 1, ["-o"])
      if (out !== null) writes.push({ target: out, rule: "sort -o" })
      continue
    }
    if (command === "uniq") {
      // uniq [input [output]] - the second positional is the output file.
      // ponytail: value-taking uniq flags (`-f N`) shift the positional
      // index; revisit if a miss is ever observed in a denial registry row.
      const positionals = positionalsAfter(tokens, i + 1)
      if (positionals.length >= 2) writes.push({ target: positionals[1], rule: "uniq output" })
      continue
    }
    if (command === "curl") {
      const value = optionValue(tokens, i + 1, ["-o", "--output"])
      if (value !== null) writes.push({ target: value, rule: "curl -o" })
      // `-O` writes the remote file's basename into the cwd; the destination
      // is therefore the URL path basename (a bare name, but kept explicit so
      // the form set matches design.md D5 verbatim).
      if (hasFlag(tokens, i + 1, "-O")) {
        const url = tokens.slice(i + 1).find((t) => /^https?:\/\//.test(t))
        if (url !== undefined) writes.push({ target: remoteBasename(url), rule: "curl -O" })
      }
      continue
    }
    if (command === "wget") {
      const out = optionValue(tokens, i + 1, ["-O"])
      if (out !== null) writes.push({ target: out, rule: "wget -O" })
      const prefix = optionValue(tokens, i + 1, ["-P"])
      if (prefix !== null) writes.push({ target: prefix, rule: "wget -P" })
      continue
    }
    if (command === "trafilatura") {
      const out = optionValue(tokens, i + 1, ["-o", "--output"])
      if (out !== null) writes.push({ target: out, rule: "trafilatura -o" })
      continue
    }
    if (command === "crwl") {
      const out = optionValue(tokens, i + 1, ["-o", "--output"])
      if (out !== null) writes.push({ target: out, rule: "crwl -o" })
      continue
    }
  }
  return writes
}

/** Command position: start of the line or right after a chain separator. */
function isCommandPosition(tokens: string[], i: number): boolean {
  if (i === 0) return true
  return SEGMENT_SEPARATORS.has(tokens[i - 1])
}

/** Positional (non-flag) tokens from `from` until the next command segment. */
function positionalsAfter(tokens: string[], from: number): string[] {
  const positionals: string[] = []
  for (let i = from; i < tokens.length; i++) {
    const t = tokens[i]
    if (SEGMENT_SEPARATORS.has(t)) break
    if (t.startsWith("-")) continue
    positionals.push(t)
  }
  return positionals
}

/** True when `flag` appears (exact, attached-short, e.g. `-i.bak`). */
function hasFlag(tokens: string[], from: number, flag: string): boolean {
  for (let i = from; i < tokens.length; i++) {
    const t = tokens[i]
    if (t === flag) return true
    if (!flag.startsWith("--") && !t.startsWith("--") && t.startsWith(flag) && t.length > flag.length) {
      return true
    }
  }
  return false
}

/** Value of a short/long option: `-o X`, `-oX`, `--output X`, `--output=X`. */
function optionValue(tokens: string[], from: number, names: string[]): string | null {
  for (let i = from; i < tokens.length; i++) {
    const t = tokens[i]
    for (const name of names) {
      if (t === name) {
        const value = tokens[i + 1]
        if (value !== undefined && !SEGMENT_SEPARATORS.has(value)) return value
      } else if (name.startsWith("--") && t.startsWith(name + "=")) {
        return t.slice(name.length + 1)
      } else if (
        !name.startsWith("--") &&
        !t.startsWith("--") &&
        t.startsWith(name) &&
        t.length > name.length
      ) {
        return t.slice(name.length)
      }
    }
  }
  return null
}

/** Last path segment of an http(s) URL (curl -O destination). */
function remoteBasename(url: string): string {
  try {
    const segments = new URL(url).pathname.split("/")
    return segments[segments.length - 1] || url
  } catch {
    return url
  }
}

/**
 * Match a destination against the protected set. The literal must start at a
 * path-separator boundary (so `my.git/x` never matches `.git/`) and must be
 * followed by `/` or end the path (so `.git` as a directory itself matches
 * but `.github/x` does not). `..` is normalized away first so
 * `knowledge/../.git/x` still resolves under `.git/`.
 */
function matchProtected(target: string): string | null {
  const normalized = normalize(target)
  for (const literal of PROTECTED_LITERALS) {
    const segment = literal.slice(0, -1)
    let from = 0
    for (;;) {
      const idx = normalized.indexOf(segment, from)
      if (idx === -1) break
      const atBoundary = idx === 0 || normalized[idx - 1] === "/"
      const followed = idx + segment.length === normalized.length ||
        normalized[idx + segment.length] === "/"
      if (atBoundary && followed) return literal
      from = idx + 1
    }
  }
  return null
}

/** Lexical `..`/`.` cleanup without touching the filesystem. */
function normalize(p: string): string {
  const parts: string[] = []
  for (const part of p.split("/")) {
    if (part === "" || part === ".") continue
    if (part === "..") parts.pop()
    else parts.push(part)
  }
  return (p.startsWith("/") ? "/" : "") + parts.join("/")
}
