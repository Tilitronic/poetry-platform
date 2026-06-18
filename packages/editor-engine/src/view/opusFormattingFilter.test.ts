import { describe, it, expect } from 'vitest';
import { EditorState } from '@codemirror/state';
import { opusFormattingFilter } from './opusFormattingFilter';

// ---------------------------------------------------------------------------
// Helpers — AAA pattern: each test creates its own state for full isolation.
// ---------------------------------------------------------------------------

/** Create a pristine EditorState with the formatting filter installed. */
function createState(doc = ''): EditorState {
  return EditorState.create({
    doc,
    extensions: [opusFormattingFilter()],
  });
}

/** Create state with cursor at a given position. */
function stateWithCursor(doc: string, pos: number): EditorState {
  return EditorState.create({
    doc,
    selection: { anchor: pos },
    extensions: [opusFormattingFilter()],
  });
}

/**
 * Simulate inserting text at a given cursor position (live typing).
 *
 * WHY replaceSelection: CM6's default input handler (e.g. insertNewline)
 * uses `state.replaceSelection("\n")` which explicitly sets the selection
 * to `cursor(from + text.length)`.  Our earlier helper used a raw
 * `{ changes }` update without selection, which caused the cursor to stay
 * at the insertion point (TrackBefore).  Using replaceSelection correctly
 * simulates real editor behavior including cursor positioning.
 */
function insertAt(state: EditorState, pos: number, text: string) {
  // Move cursor to pos, then replace selection (via tr.state)
  const withCursor = state.update({ selection: { anchor: pos } }).state;
  return withCursor.update(withCursor.replaceSelection(text));
}

/**
 * Simulate replacing a selection range with text (e.g. paste over selection).
 */
function replaceRange(
  state: EditorState,
  from: number,
  to: number,
  text: string,
) {
  const withSelection = state.update({
    selection: { anchor: from, head: to },
  }).state;
  return withSelection.update(withSelection.replaceSelection(text));
}

/** Convenience: get the full document string from a state. */
function doc(state: EditorState): string {
  return state.doc.toString();
}

/** Convenience: get the cursor position. */
function cursor(state: EditorState): number {
  return state.selection.main.anchor;
}

// ============================================================================
// Suite: Live Typing — Space
// ============================================================================
describe('opusFormattingFilter — live typing: space', () => {
  it('allows a single space at end of line', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, ' ');
    expect(doc(tr.state)).toBe('hello ');
  });

  it('allows a single space in middle of text', () => {
    const state = createState('hello');
    const tr = insertAt(state, 3, ' ');
    expect(doc(tr.state)).toBe('hel lo');
  });

  it('blocks first space at beginning of document (no leading space rule)', () => {
    const state = createState('');
    const tr = insertAt(state, 0, ' ');
    expect(doc(tr.state)).toBe('');
  });

  it('blocks second consecutive space when typing at end', () => {
    const state = createState('hello ');
    const tr = insertAt(state, 6, ' ');
    expect(doc(tr.state)).toBe('hello ');
  });

  it('blocks third consecutive space (key repeat)', () => {
    const state = createState('hello ');
    // Second space attempt – blocked
    const t1 = insertAt(state, 6, ' ');
    expect(doc(t1.state)).toBe('hello ');

    // Third space attempt – still blocked
    const t2 = insertAt(t1.state, 6, ' ');
    expect(doc(t2.state)).toBe('hello ');
  });

  it('blocks space when cursor sits right before an existing space', () => {
    // Doc: "hello world", cursor at position 5 (between 'o' and ' ')
    // Typing space here would create "hello  world"
    const state = createState('hello world');
    const tr = insertAt(state, 5, ' ');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('allows space when there is no space before or after cursor', () => {
    const state = createState('helloworld');
    const tr = insertAt(state, 5, ' ');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('blocks space at position 0 when document starts with space', () => {
    const state = createState(' hello');
    // Cursor at position 0, typing space would create "  hello"
    const tr = insertAt(state, 0, ' ');
    expect(doc(tr.state)).toBe(' hello');
  });
});

// ============================================================================
// Suite: No leading space at document start or line start
// ============================================================================
describe('opusFormattingFilter — no leading space at line start', () => {
  it('blocks space typed at position 0 in empty document', () => {
    const state = createState('');
    const tr = insertAt(state, 0, ' ');
    expect(doc(tr.state)).toBe('');
  });

  it('blocks space typed at position 0 in non-empty document', () => {
    const state = createState('hello');
    const tr = insertAt(state, 0, ' ');
    expect(doc(tr.state)).toBe('hello');
  });

  it('allows space typed after the first character', () => {
    const state = createState('hello');
    const tr = insertAt(state, 1, ' ');
    expect(doc(tr.state)).toBe('h ello');
  });

  it('blocks space at start of a new line (after \\n)', () => {
    // Doc: "hello \nworld", cursor at position 7 (between \n and w)
    // Typing space would create "hello \n world" — but auto-space already
    // added space at end of "hello ", so leading space on new line is redundant
    const state = createState('hello \nworld');
    const tr = insertAt(state, 7, ' ');
    expect(doc(tr.state)).toBe('hello \nworld');
  });

  it('blocks space at start of blank line (after \\n\\n)', () => {
    // Doc: "a\n\nb", cursor at position 3 (between second \n and b)
    const state = createState('a\n\nb');
    const tr = insertAt(state, 3, ' ');
    expect(doc(tr.state)).toBe('a\n\nb');
  });

  it('blocks space on empty line after Enter (auto-space already did its job)', () => {
    // Simulate: user types "hello" + Enter (→ "hello \n"), then tries
    // to type space on the new line before typing text
    let state = createState('');
    state = insertAt(state, 0, 'hello').state;     // → "hello"
    state = insertAt(state, 5, '\n').state;        // → "hello \n"
    state = insertAt(state, 7, ' ').state;         // → space BLOCKED
    expect(doc(state)).toBe('hello \n');
  });

  it('strips leading space from pasted text at position 0', () => {
    const state = createState('hello');
    const tr = insertAt(state, 0, ' world');
    expect(doc(tr.state)).toBe('worldhello');
  });

  it('strips multiple leading spaces from pasted text at position 0', () => {
    const state = createState('hello');
    const tr = insertAt(state, 0, '   world');
    expect(doc(tr.state)).toBe('worldhello');
  });

  it('strips leading spaces only from first line when pasting multiline at position 0', () => {
    const state = createState('hello');
    const tr = insertAt(state, 0, '  foo\n  bar');
    // First-line leading spaces stripped by step 5.
    // The existing space-collapsing step (step 3) already collapsed the
    // indentation on line 2 from double-space to single-space — this is
    // a pre-existing paste-path behavior that applies uniformly to all
    // double-space sequences regardless of position.
    expect(doc(tr.state)).toBe('foo\n barhello');
  });

  it('preserves leading single space when pasting NOT at position 0', () => {
    // Single leading space at non-zero position should be preserved
    // (only position-0 strips leading spaces; paste-path space-collapsing
    //  does not affect single spaces)
    const state = createState('hello');
    const tr = insertAt(state, 5, ' world');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('strips leading space from replacement at position 0 (select-all + paste)', () => {
    const state = createState('old');
    const tr = replaceRange(state, 0, 3, ' new');
    expect(doc(tr.state)).toBe('new');
  });

  it('allows leading space when pasting at a replacement that is not at doc start', () => {
    // Edge: replacement at non-zero position should still allow leading spaces
    const state = createState('abc');
    const tr = replaceRange(state, 1, 2, ' ');
    expect(doc(tr.state)).toBe('a c');
  });
});

// ============================================================================
// Suite: Live Typing — Newline / Enter
// ============================================================================
describe('opusFormattingFilter — live typing: newline (Enter)', () => {
  it('adds space before newline at end of text', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n');
    // Space is auto-added before \n so words don't glue when newlines removed
    expect(doc(tr.state)).toBe('hello \n');
    // Cursor must move to the new line (past "hello \n" = 7 chars)
    expect(cursor(tr.state)).toBe(7);
  });

  it('adds space before newline in middle of text', () => {
    const state = createState('hello world');
    const tr = insertAt(state, 5, '\n');
    expect(doc(tr.state)).toBe('hello \n world');
    // Cursor after the newline (pos 6 in 0-indexed "hello \n world")
    // = right at the start of the next line = position 7
    expect(cursor(tr.state)).toBe(7);
  });

  it('preserves single trailing space before newline (user typed it, keep it)', () => {
    const state = createState('hello ');
    const tr = insertAt(state, 6, '\n');
    // User typed the space themselves — it stays
    expect(doc(tr.state)).toBe('hello \n');
    // Cursor past "hello \n" = 7 chars
    expect(cursor(tr.state)).toBe(7);
  });

  it('preserves multiple trailing spaces before newline (user typed them, keep them)', () => {
    const state = createState('hello   ');
    const tr = insertAt(state, 8, '\n');
    expect(doc(tr.state)).toBe('hello   \n');
  });

  it('preserves trailing spaces before Enter in middle of text', () => {
    const state = createState('hello   world');
    // Cursor at position 8 (after the three spaces, before 'w')
    // User typed the spaces, so they stay — Enter splits at cursor
    const tr = insertAt(state, 8, '\n');
    expect(doc(tr.state)).toBe('hello   \nworld');
    expect(cursor(tr.state)).toBe(9);
  });

  it('allows one blank line (second newline, Enter after Enter)', () => {
    const state = createState('line1\n');
    const tr = insertAt(state, 6, '\n');
    // ONE blank line (\n\n) IS allowed — user can then start typing
    expect(doc(tr.state)).toBe('line1\n\n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does NOT auto-add space when creating blank line (charBefore=\\n)', () => {
    // Doc: "line1\n", cursor at 6 (after the \n, on the empty new line)
    // Pressing Enter creates \n\n without auto-space
    const state = createState('line1\n');
    const tr = insertAt(state, 6, '\n');
    expect(doc(tr.state)).toBe('line1\n\n');
    expect(doc(tr.state)).not.toContain(' \n');
  });

  it('blocks third consecutive newline (key repeat) — only triple blocked', () => {
    const state = createState('line1\n');
    // Second Enter → ONE blank line allowed
    const t1 = insertAt(state, 6, '\n');
    expect(doc(t1.state)).toBe('line1\n\n');
    expect(cursor(t1.state)).toBe(7);

    // Third Enter → BLOCKED (would create \n\n\n = two blank lines)
    const t2 = insertAt(t1.state, 7, '\n');
    expect(doc(t2.state)).toBe('line1\n\n');
    expect(cursor(t2.state)).toBe(7);
  });

  it('allows one blank line when cursor after newline in middle of doc', () => {
    // Doc: "a\nb", cursor at position 2 (between \n and b)
    // Pressing Enter creates "\n\n" = one blank line
    const state = createState('a\nb');
    const tr = insertAt(state, 2, '\n');
    expect(doc(tr.state)).toBe('a\n\nb');
  });

  it('allows one blank line when cursor before an existing newline', () => {
    // Doc: "a\nb", cursor at position 1 (between 'a' and \n)
    // Pressing Enter creates "\n\n" = one blank line
    const state = createState('a\nb');
    const tr = insertAt(state, 1, '\n');
    expect(doc(tr.state)).toBe('a\n\nb');
  });

  it('full flow: type word + Enter + Enter + word → blank line between', () => {
    // Simulate "hello \n\nworld" — the blank-line scenario
    let state = createState('');
    state = insertAt(state, 0, 'hello').state;
    state = insertAt(state, 5, '\n').state;  // → "hello \n"
    state = insertAt(state, 7, '\n').state;  // → "hello \n\n"
    state = insertAt(state, 8, 'world').state;// → "hello \n\nworld"
    expect(doc(state)).toBe('hello \n\nworld');
    const lines = doc(state).split('\n');
    expect(lines).toHaveLength(3);
    expect(lines[0]).toBe('hello ');
    expect(lines[1]).toBe('');
    expect(lines[2]).toBe('world');
  });

  it('full flow: word + Enter + Enter + Enter → triple blocked', () => {
    let state = createState('');
    state = insertAt(state, 0, 'a').state;     // → "a"
    state = insertAt(state, 1, '\n').state;    // → "a \n"
    state = insertAt(state, 3, '\n').state;    // → "a \n\n"
    state = insertAt(state, 4, '\n').state;    // → "a \n\n" (blocked!)
    state = insertAt(state, 4, '\n').state;    // → "a \n\n" (blocked!)
    expect(doc(state)).toBe('a \n\n');
    expect(doc(state).split('\n').length).toBeLessThanOrEqual(3);
  });

  it('full flow: word with trailing space + Enter → space preserved', () => {
    let state = createState('hello ');
    state = insertAt(state, 6, '\n').state;
    expect(doc(state)).toBe('hello \n');
  });

  it('adds space before newline after non-newline character', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n');
    expect(doc(tr.state)).toBe('hello \n');
  });

  it('consumes trailing spaces + existing newline when Enter pressed between them', () => {
    // Doc: "hello   \nworld", cursor at position 8 (after spaces, before \n)
    // Edge case: user pressed Enter between trailing spaces and an existing
    // newline.  We strip the spaces AND consume the existing \n so the
    // result is "hello\nworld" without creating "   \n\n".
    const state = createState('hello   \nworld');
    const tr = insertAt(state, 8, '\n');
    expect(doc(tr.state)).toBe('hello\nworld');
  });
});

// ============================================================================
// Suite: Auto-add space before newline, hyphen exception
// ============================================================================
describe('opusFormattingFilter — auto-space before newline', () => {
  it('adds space before newline when letter precedes', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n');
    expect(doc(tr.state)).toBe('hello \n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does not add extra space when user already typed a space before Enter', () => {
    const state = createState('hello ');
    const tr = insertAt(state, 6, '\n');
    // User's space is preserved; no auto-space is added on top
    expect(doc(tr.state)).toBe('hello \n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does not add space when hyphen-minus precedes', () => {
    const state = createState('hello-');
    const tr = insertAt(state, 6, '\n');
    expect(doc(tr.state)).toBe('hello-\n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does not add space when en-dash precedes', () => {
    const state = createState('hello–');
    const tr = insertAt(state, 6, '\n');
    expect(doc(tr.state)).toBe('hello–\n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does not add space when em-dash precedes', () => {
    const state = createState('hello—');
    const tr = insertAt(state, 6, '\n');
    expect(doc(tr.state)).toBe('hello—\n');
    expect(cursor(tr.state)).toBe(7);
  });

  it('does not add space at document start', () => {
    const state = createState('');
    const tr = insertAt(state, 0, '\n');
    expect(doc(tr.state)).toBe('\n');
    expect(cursor(tr.state)).toBe(1);
  });

  it('allows one blank line after hyphen (double newline OK, triple blocked)', () => {
    // Doc: "hello-\nworld", cursor at position 7 (after \n, before w)
    // ONE blank line IS allowed now
    const state = createState('hello-\nworld');
    const tr = insertAt(state, 7, '\n');
    expect(doc(tr.state)).toBe('hello-\n\nworld');
  });

  it('adds space before newline after punctuation', () => {
    const state = createState('hello.');
    const tr = insertAt(state, 6, '\n');
    expect(doc(tr.state)).toBe('hello. \n');
  });
});

// ============================================================================
// Suite: Paste / Multi-character Insert (text.length > 1)
// ============================================================================
describe('opusFormattingFilter — paste / multi-char insert', () => {
  it('collapses double spaces to single space', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '  world');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('collapses triple spaces to single space', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '   world');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('collapses double spaces in middle of existing text via paste', () => {
    const state = createState('hello world');
    // Replace the single space at position 5 with double space
    const tr = replaceRange(state, 5, 6, '  ');
    expect(doc(tr.state)).toBe('hello world');
  });

  it('collapses double spaces at beginning of pasted text', () => {
    const state = createState('start');
    const tr = insertAt(state, 5, '  end');
    expect(doc(tr.state)).toBe('start end');
  });

  it('collapses double newlines to single newline', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n\nworld');
    expect(doc(tr.state)).toBe('hello\nworld');
  });

  it('collapses triple newlines to single newline', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n\n\nworld');
    expect(doc(tr.state)).toBe('hello\nworld');
  });

  it('collapses double newlines pasted in middle of text', () => {
    const state = createState('hello\nworld');
    // Replace the single \n with double \n
    const tr = replaceRange(state, 5, 6, '\n\n');
    expect(doc(tr.state)).toBe('hello\nworld');
  });

  it('normalises Windows CRLF to LF', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\r\nworld');
    expect(doc(tr.state)).toBe('hello\nworld');
  });

  it('normalises mixed line endings to LF', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\r\n\n\nworld');
    // After \r\n → \n: "\n\n\nworld" → collapse to "\nworld"
    expect(doc(tr.state)).toBe('hello\nworld');
  });

  it('strips trailing whitespace from each pasted line', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '  foo  \n  bar  ');
    expect(doc(tr.state)).toBe('hello foo\n bar');
  });

  it('handles paste with mixed issues (spaces + newlines + trailing ws)', () => {
    const state = createState('start');
    const tr = insertAt(state, 5, '  line1  \n  \n  line2  ');
    // Step: strip trailing ws → "  line1\n  \n  line2"
    // Step: collapse newlines → "  line1\n  line2"
    // Step: collapse spaces → " line1\n line2"
    // Final: "start line1\n line2"
    expect(doc(tr.state)).toBe('start line1\n line2');
  });

  it('preserves valid single-space formatting during paste', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, ' foo bar baz');
    expect(doc(tr.state)).toBe('hello foo bar baz');
  });

  it('preserves valid single-newline formatting during paste', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\nfoo\nbar');
    expect(doc(tr.state)).toBe('hello\nfoo\nbar');
  });

  it('removes trailing spaces from the single line when pasting a single line with trailing spaces', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, 'world   ');
    // Trailing spaces are stripped; no space is added between 'hello' and 'world'
    expect(doc(tr.state)).toBe('helloworld');
  });

  it('handles paste with only spaces (nothing else)', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '   ');
    expect(doc(tr.state)).toBe('a ');
  });

  it('handles paste with only newlines (nothing else)', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '\n\n\n');
    expect(doc(tr.state)).toBe('a\n');
  });
});

// ============================================================================
// Suite: Double punctuation blocking  (, : -  '  ’ )
// ============================================================================
describe('opusFormattingFilter — double punctuation', () => {
  // ── Live typing: single punctuation is allowed ──────────────────────

  it('allows single comma', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ',');
    expect(doc(tr.state)).toBe('a,');
  });

  it('allows single colon', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ':');
    expect(doc(tr.state)).toBe('a:');
  });

  it('allows single semicolon', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ';');
    expect(doc(tr.state)).toBe('a;');
  });

  it('allows single hyphen', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '-');
    expect(doc(tr.state)).toBe('a-');
  });

  it('allows single English apostrophe', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, "'");
    expect(doc(tr.state)).toBe("a'");
  });

  it('allows single Ukrainian apostrophe', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '’');
    expect(doc(tr.state)).toBe('a’');
  });

  // ── Live typing: double punctuation is blocked ──────────────────────

  it('blocks double comma', () => {
    const state = createState('a,');
    const tr = insertAt(state, 2, ',');
    expect(doc(tr.state)).toBe('a,');
  });

  it('blocks double colon', () => {
    const state = createState('a:');
    const tr = insertAt(state, 2, ':');
    expect(doc(tr.state)).toBe('a:');
  });

  it('blocks double semicolon', () => {
    const state = createState('a;');
    const tr = insertAt(state, 2, ';');
    expect(doc(tr.state)).toBe('a;');
  });

  it('blocks double hyphen', () => {
    const state = createState('a-');
    const tr = insertAt(state, 2, '-');
    expect(doc(tr.state)).toBe('a-');
  });

  it('blocks double English apostrophe', () => {
    const state = createState("a'");
    const tr = insertAt(state, 2, "'");
    expect(doc(tr.state)).toBe("a'");
  });

  it('blocks double Ukrainian apostrophe', () => {
    const state = createState('a’');
    const tr = insertAt(state, 2, '’');
    expect(doc(tr.state)).toBe('a’');
  });

  // ── Live typing: triple punctuation is blocked (key repeat) ─────────

  it('blocks triple comma', () => {
    const state = createState('a,');
    const t1 = insertAt(state, 2, ',');  // blocked → 'a,'
    expect(doc(t1.state)).toBe('a,');
    const t2 = insertAt(t1.state, 2, ',');  // still blocked
    expect(doc(t2.state)).toBe('a,');
  });

  it('blocks triple hyphen', () => {
    const state = createState('a-');
    const t1 = insertAt(state, 2, '-');
    expect(doc(t1.state)).toBe('a-');
    const t2 = insertAt(t1.state, 2, '-');
    expect(doc(t2.state)).toBe('a-');
  });

  // ── Paste: multi-punctuation collapsed to single ────────────────────

  it('collapses double comma on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ',,');
    expect(doc(tr.state)).toBe('a,');
  });

  it('collapses triple colon on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ':::');
    expect(doc(tr.state)).toBe('a:');
  });

  it('collapses double semicolon on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ';;');
    expect(doc(tr.state)).toBe('a;');
  });

  it('collapses double hyphen on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '--');
    expect(doc(tr.state)).toBe('a-');
  });

  it('collapses mixed punctuation on paste (each reduced separately)', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, ',,::--');
    expect(doc(tr.state)).toBe('a,:-');
  });

  it('collapses double English apostrophe on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, "''");
    expect(doc(tr.state)).toBe("a'");
  });

  it('collapses double Ukrainian apostrophe on paste', () => {
    const state = createState('a');
    const tr = insertAt(state, 1, '’’');
    expect(doc(tr.state)).toBe('a’');
  });

  // ── Edge: punctuation at document start is allowed ──────────────────

  it('allows single hyphen at document start', () => {
    const state = createState('');
    const tr = insertAt(state, 0, '-');
    expect(doc(tr.state)).toBe('-');
  });

  it('allows single comma at start of new line after Enter', () => {
    let state = createState('hello');
    state = insertAt(state, 5, '\n').state;  // → "hello \n"
    state = insertAt(state, 7, ',').state;   // → "hello \n,"
    expect(doc(state)).toBe('hello \n,');
  });
});

// ============================================================================
// Suite: No-Op — transactions without doc changes
// ============================================================================
describe('opusFormattingFilter — no-op passthrough', () => {
  it('passes through selection-only transactions unchanged', () => {
    const state = createState('hello world');
    const tr = state.update({ selection: { anchor: 5 } });
    expect(doc(tr.state)).toBe('hello world');
    expect(tr.state.selection.main.anchor).toBe(5);
  });

  it('passes through scroll-only transactions unchanged', () => {
    const state = createState('hello');
    const tr = state.update({ scrollIntoView: true });
    expect(doc(tr.state)).toBe('hello');
  });
});

// ============================================================================
// Suite: Edge cases
// ============================================================================
describe('opusFormattingFilter — edge cases', () => {
  it('handles empty document correctly', () => {
    const state = createState('');
    expect(doc(state)).toBe('');
  });

  it('allows typing single character into empty document', () => {
    const state = createState('');
    const tr = insertAt(state, 0, 'a');
    expect(doc(tr.state)).toBe('a');
  });

  it('blocks typing space into empty document (no leading space rule)', () => {
    const state = createState('');
    const tr = insertAt(state, 0, ' ');
    expect(doc(tr.state)).toBe('');
  });

  it('allows typing newline into empty document', () => {
    const state = createState('');
    const tr = insertAt(state, 0, '\n');
    expect(doc(tr.state)).toBe('\n');
  });

  it('handles replacement of entire document content (select-all + paste)', () => {
    const state = createState('old content');
    const tr = replaceRange(state, 0, 11, 'new  content');
    expect(doc(tr.state)).toBe('new content');
  });

  it('handles pasted text with leading and trailing blank lines', () => {
    const state = createState('hello');
    const tr = insertAt(state, 5, '\n\n\nmiddle\n\n\n');
    // Collapse all to single newlines
    expect(doc(tr.state)).toBe('hello\nmiddle\n');
  });

  it('correctly handles document with only whitespace', () => {
    const state = createState('   \n   \n   ');
    // Collapse spaces, collapse newlines
    // After paste-style cleanup: ' \n \n ' ... wait, this is the INITIAL doc, not a paste
    // The filter only fires on changes, so the initial state is not filtered.
    // This test verifies that editing such a doc works.
    const tr = insertAt(state, 0, 'x');
    expect(doc(tr.state)).toBe('x   \n   \n   ');
  });
});
