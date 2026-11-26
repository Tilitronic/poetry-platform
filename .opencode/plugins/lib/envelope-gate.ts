/**
 * envelope-gate lib - authored-envelope duplication check (DIA-261023-d6b9).
 *
 * Pure helper in the routing-gate.ts style (DIA-260827-uv precedent): shared
 * by the delegation-observer reviewer block and the node/bun unit suite, so
 * the counting rule lives in exactly one place.
 *
 * Erasable TypeScript only (no enums, no parameter properties): Node >=23
 * strips erasable TS for the test suites and the plugin loads via
 * --experimental-strip-types as individual files (no bundler).
 */

// Line-anchored fence opener: three backticks at COLUMN 0 immediately followed
// by the envelope token. Column-0 semantics are deliberate: an indented fence
// (leading spaces/tabs) is quoted/nested markdown in prose, not a payload copy
// of the injected block, so it does not count. The bare token never matches -
// prose that quotes IMMUTABLE_GIT_ENVELOPE (learnings records, cards, this
// file's own comments once the diff rides inside a future envelope) must not
// trip the guard.
const ENVELOPE_FENCE_OPENER = /^```IMMUTABLE_GIT_ENVELOPE/gm

/**
 * Count hand-written envelope fence openers in AUTHORED dispatch text.
 *
 * The authored dispatch text carries zero envelope text: the pre-spawn hook
 * injects the single legitimate block into the child prompt AFTER this check,
 * so any line-anchored fence opener found here is hand-written by the dispatch
 * author. violation = count >= 1 (the injected block is counted never, because
 * this runs pre-injection).
 */
export function evaluateEnvelopeDuplication(dispatchText: string): {
  violation: boolean
  count: number
} {
  const count = [...dispatchText.matchAll(ENVELOPE_FENCE_OPENER)].length
  return { violation: count >= 1, count }
}
