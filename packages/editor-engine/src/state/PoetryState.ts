import { atom } from 'signia';
import { LineAtom } from './atoms';

export class OpusState {
  readonly lines = new Map<string, LineAtom>();
  readonly order = atom<string[]>('order', []);

  get lineIds(): string[] {
    return this.order.value;
  }

  getLine(id: string): LineAtom | undefined {
    return this.lines.get(id);
  }

  getLineAt(index: number): LineAtom | undefined {
    const id = this.order.value[index];
    return id ? this.lines.get(id) : undefined;
  }

  addLine(id: string, text = '', index?: number): LineAtom {
    const atom_ = new LineAtom(id, text);
    this.lines.set(id, atom_);
    const order = [...this.order.value];
    if (index !== undefined) {
      order.splice(index, 0, id);
    } else {
      order.push(id);
    }
    this.order.set(order);
    return atom_;
  }

  removeLine(id: string): void {
    this.lines.delete(id);
    this.order.set(this.order.value.filter((lid) => lid !== id));
  }

  moveLine(id: string, toIndex: number): void {
    const order = this.order.value.filter((lid) => lid !== id);
    order.splice(toIndex, 0, id);
    this.order.set(order);
  }
}
