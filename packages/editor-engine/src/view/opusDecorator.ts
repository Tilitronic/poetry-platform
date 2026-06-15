import { syntaxTree } from '@codemirror/language';
import { RangeSetBuilder } from '@codemirror/state';
import {
  Decoration,
  type DecorationSet,
  ViewPlugin,
  type EditorView,
  type ViewUpdate,
} from '@codemirror/view';
import type { Orchestrator } from '../orchestrator/Orchestrator';

export function opusDecorations(view: EditorView): DecorationSet {
  const builder = new RangeSetBuilder<Decoration>();
  const tree = syntaxTree(view.state);
  tree.iterate({
    enter(node) {
      if (node.from === node.to) return;
      builder.add(node.from, node.to, Decoration.mark({ class: 'cm-poetry-line' }));
    },
  });
  return builder.finish();
}

export function poetryViewPlugin(orchestrator: Orchestrator) {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;

      constructor(view: EditorView) {
        this.decorations = opusDecorations(view);
      }

      update(update: ViewUpdate) {
        if (update.docChanged || update.viewportChanged) {
          this.decorations = opusDecorations(update.view);
          orchestrator.commands.push({
            id: 'reformat',
            priority: 'user',
            execute: () => {},
          });
        }
      }
    },
    { decorations: (v) => v.decorations },
  );
}
