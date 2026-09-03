import { describe, it, expect } from 'vitest';
import { Orchestrator } from './Orchestrator';

// ---------------------------------------------------------------------------
// DIA-170: contract test for Orchestrator.acceptWorkerResult.
//
// Enforces the revision-ordering and priority contract from architecture.md
// ("Orchestrator - single write point", ~lines 503-509):
//   - compares incoming revision_id against the current revision and
//     discards stale responses;
//   - priority order: user input > MarkPoetry command > worker result,
//     so a stale worker recomputation never clobbers a newer override.
//
// Zero mocks: the Orchestrator is instantiated directly and driven through
// its public API (plus one deliberate state bump to represent a user
// override, since the user-input write path is not yet wired in this
// Orchestrator).
// ---------------------------------------------------------------------------

/** Snapshot the worker-relevant fields of a line's current state. */
function lineState(o: Orchestrator, id: string) {
  const v = o.state.getLine(id)!.value;
  return { marks: v.marks, stress: v.stress, ipa: v.ipa, revisionId: v.revisionId };
}

describe('Orchestrator.acceptWorkerResult - revision ordering and priority contract', () => {
  it('discards a stale result (workerRevisionId older than current revision)', () => {
    const o = new Orchestrator();
    o.insertLine('L1', 'Весна', 0);

    // Current revision advances to 5 via a newer worker result.
    o.acceptWorkerResult('L1', { marks: 'stressful' }, 5);
    expect(lineState(o, 'L1').revisionId).toBe(5);

    // A result computed against revision 3 is stale: must not overwrite.
    o.acceptWorkerResult('L1', { marks: 'stale', stress: 'stale', ipa: 'stale' }, 3);

    expect(lineState(o, 'L1')).toEqual({
      marks: 'stressful',
      stress: '',
      ipa: '',
      revisionId: 5,
    });
  });

  it('applies a result computed against the current revision (equal is not stale)', () => {
    const o = new Orchestrator();
    o.insertLine('L1', 'Весна', 0);

    o.acceptWorkerResult('L1', { marks: 'stressful' }, 4);
    // Same revision arriving again (e.g. consolidated payload retry): applied.
    o.acceptWorkerResult('L1', { marks: 'stressful', stress: 'syllabic' }, 4);

    expect(lineState(o, 'L1')).toEqual({
      marks: 'stressful',
      stress: 'syllabic',
      ipa: '',
      revisionId: 4,
    });
  });

  it('applies a newer result and advances the revision', () => {
    const o = new Orchestrator();
    o.insertLine('L1', 'Весна', 0);

    o.acceptWorkerResult('L1', { marks: 'stressful' }, 2);
    o.acceptWorkerResult('L1', { ipa: 'vesˈna' }, 7);

    expect(lineState(o, 'L1')).toEqual({
      marks: 'stressful',
      stress: '',
      ipa: 'vesˈna',
      revisionId: 7,
    });
  });

  it('is a no-op for an unknown lineId (no crash, no state change)', () => {
    const o = new Orchestrator();
    o.insertLine('L1', 'Весна', 0);
    o.acceptWorkerResult('L1', { marks: 'stressful' }, 1);

    expect(() => o.acceptWorkerResult('nope', { marks: 'x' }, 9)).not.toThrow();
    // Existing line untouched by the unknown-line call.
    expect(lineState(o, 'L1').marks).toBe('stressful');
  });

  it('priority: a user override is never clobbered by a stale worker result', () => {
    const o = new Orchestrator();
    o.insertLine('L1', 'Весна', 0);

    // Worker result computed against revision 2.
    o.acceptWorkerResult('L1', { stress: 'worker-stress' }, 2);

    // User override bumps the line to revision 5.
    // (User-input write path is not wired into Orchestrator yet, so the
    //  override is represented by a direct state update - the real atom.)
    o.state.getLine('L1')!.update({ stress: 'user-override', revisionId: 5 });

    // Background recomputation that STARTED before the override (rev 2)
    // must not silently clobber the user's explicit choice.
    o.acceptWorkerResult('L1', { stress: 'stale-worker' }, 2);

    expect(lineState(o, 'L1').stress).toBe('user-override');
    expect(lineState(o, 'L1').revisionId).toBe(5);
  });
});
