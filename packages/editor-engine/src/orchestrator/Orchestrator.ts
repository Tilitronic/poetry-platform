import { OpusState } from '../state/PoetryState';
import { CommandBus } from './command-bus';
import { ViewUpdate } from '@codemirror/view';
import { tokenize, type TextToken } from '../tokenizer/tokenizer';

export class Orchestrator {
  readonly state: OpusState;
  readonly commands: CommandBus;

  constructor() {
    this.state = new OpusState();
    this.commands = new CommandBus();
  }

  handleDocumentUpdate(update: ViewUpdate) {
    console.log('Handling document update in Orchestrator:', update);
    if (update.docChanged) {
      // const text = update.state.doc.toString();
      const tokens: TextToken[] = tokenize(update.state.doc.toString());
      console.log('Tokenized text:', tokens);
    }
  }

  acceptWorkerResult(
    lineId: string,
    data: { marks?: string; stress?: string; ipa?: string },
    workerRevisionId: number,
  ): void {
    const line = this.state.getLine(lineId);
    if (!line) return;
    if (workerRevisionId < line.value.revisionId) return;
    line.update({ ...data, revisionId: workerRevisionId });
  }

  insertLine(id: string, text: string, index?: number): void {
    this.state.addLine(id, text, index);
  }

  removeLine(id: string): void {
    this.state.removeLine(id);
  }
}
