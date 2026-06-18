import { EditorView, ViewUpdate, lineNumbers, keymap } from '@codemirror/view';
import { EditorState } from '@codemirror/state';
import type { Extension } from '@codemirror/state';
import { defaultKeymap } from '@codemirror/commands';
import type { Orchestrator } from '../orchestrator/Orchestrator';
import { opusFormattingFilter } from './opusFormattingFilter';

const encyclopedicDarkTheme = EditorView.theme(
  {
    // Global background and text color
    '&': {
      color: '#e1e4e8',
      backgroundColor: '#1e1e24',
    },
    // Inner padding and font
    '.cm-content': {
      padding: '16px',
      minHeight: '400px',
      fontSize: '16px',
      lineHeight: '1.6',
    },
    //TODO: add styles for active line
    // '&.cm-focused': {
    //   outline: 'none',
    // },
    // Line number gutter styling
    '.cm-gutters': {
      backgroundColor: '#18181d',
      color: '#6b7280',
      borderRight: '1px solid #2d2d36',
      paddingRight: '8px',
    },
    // Active line gutter highlight
    '.cm-activeLineGutter': {
      backgroundColor: '#2a2a35',
      color: '#e1e4e8',
    },
  },
  { dark: true },
); // Inform CodeMirror this is a dark theme (for correct cursor contrast)

export class OpusEditorView {
  readonly view: EditorView;
  readonly orchestrator: Orchestrator;

  constructor(
    parent: HTMLElement | DocumentFragment,
    orchestrator: Orchestrator,
    extensions: Extension[] = [],
  ) {
    this.orchestrator = orchestrator;

    const state = EditorState.create({
      doc: '',
      extensions: [
        encyclopedicDarkTheme,
        lineNumbers(),
        opusFormattingFilter(),

        // Default key bindings (Enter → insertNewline, Backspace, arrows, etc.)
        // Without this, keyboard input like Enter does nothing in the browser
        // because CM6's key-handling pipeline has no matching command.
        keymap.of(defaultKeymap),

        //key press listener
        EditorView.updateListener.of((update: ViewUpdate) => {
          console.log('Document changed:', update.docChanged);
          if (update.docChanged) {
            this.orchestrator.handleDocumentUpdate(update);
          }
        }),
        ...extensions,
      ],
    });

    this.view = new EditorView({ state, parent });

    // Expose the view globally so Playwright e2e tests can read the actual
    // document content via view.state.doc.toString() — CM6's DOM renders
    // each line as a separate element, so textContent loses newlines.
    if (typeof window !== 'undefined') {
      (window as any).__edotorView = this.view;
    }
  }

  destroy(): void {
    this.view.destroy();
  }
}
