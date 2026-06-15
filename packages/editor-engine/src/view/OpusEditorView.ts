import { EditorView, ViewUpdate, lineNumbers } from '@codemirror/view';
import { EditorState } from '@codemirror/state';
import type { Extension } from '@codemirror/state';
import type { Orchestrator } from '../orchestrator/Orchestrator';
import { opusFormattingFilter } from './opusFormattingFilter';

// Create an elegant dark theme
const encyclopedicDarkTheme = EditorView.theme(
  {
    // Global background and text color
    '&': {
      color: '#e1e4e8', // Soft off-white text
      backgroundColor: '#1e1e24', // Deep dark graphite
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
      backgroundColor: '#18181d', // Slightly darker than main background
      color: '#6b7280', // Muted number color
      borderRight: '1px solid #2d2d36', // Subtle separator line
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
  }

  destroy(): void {
    this.view.destroy();
  }
}
