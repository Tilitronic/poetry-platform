import { describe, it, expect } from 'vitest';
import { OpusState } from './PoetryState';

describe('OpusState - uniqueness invariant (DIA-260831-p5q6)', () => {
  it('adding a duplicate line id does not duplicate order and does not orphan atom', () => {
    const s = new OpusState();
    const first = s.addLine('L1', 'hello');
    const second = s.addLine('L1', 'world');

    // upsert without re-appending: same atom instance, order has single entry
    expect(second).toBe(first);
    expect(s.lineIds).toEqual(['L1']);
    expect(s.lineIds.filter((id) => id === 'L1')).toHaveLength(1);
    // map still has one entry, no orphan
    expect(s.lines.size).toBe(1);
    expect(s.getLine('L1')).toBe(first);
    // text was upserted
    expect(s.getLine('L1')!.value.text).toBe('world');
  });

  it('duplicate add with index does not change order position or duplicate', () => {
    const s = new OpusState();
    s.addLine('L1', 'a');
    s.addLine('L2', 'b');
    s.addLine('L1', 'dup', 0);

    expect(s.lineIds).toEqual(['L1', 'L2']);
    expect(s.lines.size).toBe(2);
    // order has no duplicates
    expect(new Set(s.lineIds).size).toBe(s.lineIds.length);
  });

  it('removeLine on a duplicated id removes exactly the intended entry', () => {
    const s = new OpusState();
    s.addLine('L1', 'a');
    s.addLine('L2', 'b');
    // duplicate insertion is idempotent, so order stays [L1, L2]
    s.addLine('L1', 'dup');

    expect(s.lineIds).toEqual(['L1', 'L2']);

    s.removeLine('L1');

    expect(s.lineIds).toEqual(['L2']);
    expect(s.lines.has('L1')).toBe(false);
    expect(s.lines.has('L2')).toBe(true);
    expect(s.lines.size).toBe(1);
    // no orphaned atoms: every id in order has a map entry
    for (const id of s.lineIds) {
      expect(s.getLine(id)).toBeDefined();
    }
  });

  it('removeLine of non-existent id is a no-op (no over-deletion)', () => {
    const s = new OpusState();
    s.addLine('L1', 'a');
    s.removeLine('nope');
    expect(s.lineIds).toEqual(['L1']);
    expect(s.lines.size).toBe(1);
  });

  it('order and map stay in sync: every order id has a map entry and vice versa', () => {
    const s = new OpusState();
    s.addLine('L1', 'a');
    s.addLine('L2', 'b');
    s.addLine('L1', 'dup');
    s.addLine('L3', 'c', 1);

    // L1 dup is ignored, L3 inserted at index 1 => [L1, L3, L2]
    expect(s.lineIds).toEqual(['L1', 'L3', 'L2']);
    expect(s.lines.size).toBe(s.lineIds.length);
    expect(new Set(s.lineIds).size).toBe(s.lineIds.length);
  });
});
