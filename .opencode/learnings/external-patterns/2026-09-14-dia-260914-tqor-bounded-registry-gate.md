# Bounded registry and stall-sweep gate (DIA-260914-tqor)

## Verdict

GO-WITH-CHANGES. The runaway stall diagnosis is confirmed, but the OpenSpec
must cover both numeric journals and both plugin writers before RED/GREEN work.

## Confirmed findings

- `.opencode/plugins/lib/stall-sweep.ts` parses the complete active registry on
  every interval and permits the same dead lifecycle to be emitted again after
  the dead throttle expires.
- `.opencode/plugins/lib/registry.ts` scans all of `registry.jsonl` before each
  `seq` allocation and all of `messages.jsonl` plus `messages.md` before each
  `row_id` allocation.
- The live files already contain duplicate numeric identifiers, so a
  process-local counter is not an acceptable repair.
- `.opencode/plugins/needs-input-observer.ts` independently allocates and
  appends registry/message rows. It must use the same persistence adapter and
  lock as delegation-observer for rotation and allocation to be safe.
- Current append APIs can return an identifier even when the durable write
  failed. The canonical result must distinguish success, failure, and
  retryability; notification writes happen only after the durable stall row.

## Required design amendments

1. Define `lifecycle_generation` deterministically. The compatible anchor is
   the `seq` of the first authoritative non-terminal row in the generation.
   Restart, elapsed time, and `stall_detected` never advance it. A confirmed new
   dispatch or explicit recovery after closure advances it.
2. Centralize both delegation-observer and needs-input-observer writes behind
   the shared persistence adapter.
3. Allocate both registry `seq` and message `row_id` through durable independent
   high-water counters protected by the same short inter-process lock.
4. Return a discriminated durable-write result. A reserved but unwritten number
   is a valid gap and is never reused.
5. Use a process-local active projection for speed, but perform cross-process
   dead dedup through a locked compare-and-append against the bounded active
   registry.
6. Make explicit diagnostic/history readers archive-aware. Periodic sweep and
   hot hooks never read archives.

## Minimal lock and rotation rules

- Use Node standard-library atomic directory creation; add no dependency.
- Lock ownership records PID, nonce, acquisition time, lease, and process-start
  identity where available. Release verifies the nonce.
- Reclaim only after lease expiry and confirmation that the recorded owner is
  not live. PID reuse or unreadable ownership fails closed.
- Rotation is explicit, holds the common writer lock, verifies a copied archive
  and manifest before atomically replacing the active registry, and preserves
  the global high-water counters. This ticket adds no archive deletion.

## Evidence

- `registry.jsonl`: 44,854,516 bytes, 128,350 rows, 527 duplicate `seq` values.
- `messages.jsonl`: 53,193,220 bytes, 642 duplicate `row_id` values.
- Registry allocation: `.opencode/plugins/lib/registry.ts:169-277`.
- Stall reconstruction/dedup: `.opencode/plugins/lib/stall-sweep.ts:112-194`.
- Independent writer: `.opencode/plugins/needs-input-observer.ts:330-410`.
- Composition/emission: `.opencode/plugins/delegation-observer.ts:448-477`.

## Scope limiter

This finding governs DIA-260914-tqor only. It does not authorize implementation
before the developer accepts the amendments, does not change terminal lifecycle
semantics, and does not authorize deleting runtime archives.

## Outcome

Implemented and runtime-verified on 2026-09-16. The active registry was
rotated under the shared lock into a byte-identical immutable archive with a
verified manifest, then reduced from 44,861,601 bytes / 128,373 rows to 4,012
bytes / 13 rows. Archive-aware readers preserve legacy same-source duplicate
sequence values while deduplicating or rejecting cross-source overlap by
semantic identity. Focused plugin tests, 708 shell tests, 57 config tests, a
non-empty orchestrator smoke, and two unchanged sweep intervals passed.
