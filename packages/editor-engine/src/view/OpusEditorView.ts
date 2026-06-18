import { EditorView, ViewUpdate, lineNumbers, keymap, highlightWhitespace, highlightActiveLineGutter } from '@codemirror/view';
import { EditorState } from '@codemirror/state';
import type { Extension } from '@codemirror/state';
import { defaultKeymap } from '@codemirror/commands';
import type { Orchestrator } from '../orchestrator/Orchestrator';
import { opusFormattingFilter } from './opusFormattingFilter';

const encyclopedicDarkTheme = EditorView.theme(
  {
    // ── Global ──────────────────────────────────────────────────────────
    '&': {
      color: '#e1e4e8',
      backgroundColor: '#1e1e24',
    },
    '.cm-content': {
      padding: '16px',
      minHeight: '400px',
      fontSize: '16px',
      lineHeight: '1.6',
    },
    '&.cm-focused': {
      outline: 'none',
    },

    // ── Active line gutter only (not the line itself) ────────────────────
    '.cm-activeLineGutter': {
      backgroundColor: '#2a2a35',
      color: '#e1e4e8',
    },

    // ── Line numbers ────────────────────────────────────────────────────
    '.cm-gutters': {
      backgroundColor: '#18181d',
      color: '#6b7280',
      borderRight: '1px solid #2d2d36',
      paddingRight: '8px',
    },

    // ── Invisible-space dot (·) ─────────────────────────────────────────
    // highlightWhitespace marks spaces with .cm-highlightSpace.
    // A small sharp radial gradient creates a crisp faint circle.
    '.cm-highlightSpace': {
      backgroundImage:
        'radial-gradient(circle at 50% 50%, #888 15%, transparent 16%)',
    },
  },
  { dark: true },
);

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

        // Visual aids for editing:
        //   • highlightWhitespace — spaces shown as faint · dots
        //   • highlightActiveLineGutter — highlight the current line number
        highlightWhitespace(),
        highlightActiveLineGutter(),

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

    // Expose the view globally for debugging and tests.
    // CM6's DOM renders each line as a separate element, so textContent
    // loses newlines — access the state directly when you need the real doc.
    if (typeof window !== 'undefined') {
      (window as any).__edotorView = this.view;
    }
  }

  destroy(): void {
    this.view.destroy();
  }
}
