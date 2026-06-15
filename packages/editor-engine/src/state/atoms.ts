import { atom, computed } from 'signia';
import type { LineDecoration } from './decorations';

type Language = 'en' | 'ua' | 'pl' | 'by';

export interface LineAtomValue {
  id: string;
  text: string;
  marks: string;
  stress: string;
  ipa: string;
  decorations: LineDecoration[];
  revisionId: number;
}

export class LineAtom {
  readonly id: string;
  readonly atom;
  readonly revisionComputed;

  constructor(id: string, text = '') {
    this.id = id;
    this.atom = atom<LineAtomValue>(`line:${id}`, {
      id,
      text,
      marks: '',
      stress: '',
      ipa: '',
      decorations: [],
      revisionId: 0,
    });
    this.revisionComputed = computed(`line:${id}:rev`, () => this.atom.value.revisionId);
  }

  get value() {
    return this.atom.value;
  }

  set value(v: LineAtomValue) {
    this.atom.set(v);
  }

  update(partial: Partial<LineAtomValue>) {
    this.atom.set({ ...this.atom.value, ...partial });
  }
}
