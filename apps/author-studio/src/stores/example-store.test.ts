// TODO(ponytail): template-store boilerplate coverage only - useCounterStore
// is scaffold, not domain logic. Do not mistake this for real business
// coverage; replace once real stores (with Orchestrator-backed state) exist.
import { beforeEach, describe, expect, it } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useCounterStore } from './example-store';

describe('useCounterStore', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('starts at zero; doubleCount doubles it', () => {
    const store = useCounterStore();
    expect(store.counter).toBe(0);
    expect(store.doubleCount).toBe(0);
  });

  it('increment bumps the counter and doubleCount tracks it', () => {
    const store = useCounterStore();
    store.increment();
    store.increment();
    expect(store.counter).toBe(2);
    expect(store.doubleCount).toBe(4);
  });
});
