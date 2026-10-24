import { atom } from 'signia';
import type { LineDecoration } from './decorations';

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
