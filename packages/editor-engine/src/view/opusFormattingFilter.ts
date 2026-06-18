import { Extension, EditorState, EditorSelection } from '@codemirror/state';

// ---------------------------------------------------------------------------
// Compile-once regex constants
// ---------------------------------------------------------------------------
const HYPHEN_DASH_RE = /[-–—]/;
const CRLF_RE = /\r\n/g;
const BLANK_LINES_RE = /\n[ \t]*\n+/g;
const DOUBLE_SPACE_RE = / {2,}/g;
const TRAILING_WS_RE = /^(\s*\S.*?)[ \t]+$/gm;
const LEADING_WS_RE = /^[ \t]+/;

/** Characters whose consecutive repetition is cleaned on paste. */
const NEEDS_CLEAN_RE = /[ \t\n\r,:\-;'\u2019]/;

/** Collapse repeated punctuation: ,, :: ;; -- '' ’’. */
const DUP_PUNCT_RE = /([,:'\u2019;\-])\1+/g;

// Characters that trigger double-punctuation blocking on live typing.
const REPEATABLE_PUNCT = new Set([',', ':', ';', '-', "'", '’']);

// ---------------------------------------------------------------------------
// Helper: build a ChangeSpec from segment data
// ---------------------------------------------------------------------------
function change(from: number, to: number, insert: string) {
  return { from, to, insert };
}

// ---------------------------------------------------------------------------
// Helpers: neighbour lookup (encapsulates sliceString)
// ---------------------------------------------------------------------------
function charBefore(doc: EditorState['doc'], pos: number): string {
  return pos > 0 ? doc.sliceString(pos - 1, pos) : '';
}

function charAt(doc: EditorState['doc'], pos: number): string {
  return doc.sliceString(pos, pos + 1);
}

function twoCharsBefore(doc: EditorState['doc'], pos: number): string {
  return pos >= 2 ? doc.sliceString(pos - 2, pos) : '';
}

// ---------------------------------------------------------------------------
// normalizeLineEndings
//
// Normalise CRLF → LF so downstream regexes work correctly.  Returns the
// normalised text unchanged if no CRLF exists (zero allocs in that case).
// ---------------------------------------------------------------------------
function normalizeLineEndings(text: string): string {
  return text.indexOf('\r') >= 0 ? text.replace(CRLF_RE, '\n') : text;
}

// ---------------------------------------------------------------------------
// cleanPastedText
//
// Full regex-based cleanup for multi-character paste / bulk insert.
// Returns cleaned text or the original if nothing changed.
// ---------------------------------------------------------------------------
function cleanPastedText(text: string, insertAtDocStart: boolean): string {
  // Quick-exit: if the text contains none of the characters we need to
  // clean, skip the entire regex pipeline.
  if (!NEEDS_CLEAN_RE.test(text)) return text;

  let result = normalizeLineEndings(text);
  const baseline = result;

  result = result.replace(BLANK_LINES_RE, '\n');
  result = result.replace(DOUBLE_SPACE_RE, ' ');
  result = result.replace(DUP_PUNCT_RE, '$1');
  result = result.replace(TRAILING_WS_RE, '$1');

  if (insertAtDocStart) {
    result = result.replace(LEADING_WS_RE, '');
  }

  // String identity comparison: if nothing changed, result === baseline
  // because `.replace()` returns the original string when no match is found.
  return result !== baseline ? result : text;
}

// ---------------------------------------------------------------------------
// handleEnter
//
// Decides what happens when the user presses Enter at a given position.
// Returns a ChangeSpec to apply, or null to let the original transaction
// pass through unchanged.
// ---------------------------------------------------------------------------
function handleEnter(
  doc: EditorState['doc'],
  fromA: number,
  toA: number,
  before: string,
  after: string,
): { from: number; to: number; insert: string } | null {
  // Step 1: At document start — no space, just newline
  if (fromA === 0) return null;

  // Step 2: Enter after space(s) — preserve user's space
  if (before === ' ') {
    // Edge: cursor is between trailing spaces and an existing newline
    // ("   \n" + Enter).  Strip the spaces AND consume the existing \n
    // to avoid creating "   \n\n".
    if (after === '\n') {
      let wsStart = fromA;
      while (wsStart > 0 && doc.sliceString(wsStart - 1, wsStart) === ' ') {
        wsStart--;
      }
      return change(wsStart, toA + 1, '\n');
    }
    // Normal: user typed the space themselves, just let Enter through
    return null;
  }

  // Step 3: Triple newline check — block only \n\n\n (two blank lines)
  const twoBefore = twoCharsBefore(doc, fromA);
  const isBetweenTwoNewlines = before === '\n' && after === '\n';
  if (twoBefore === '\n\n' || isBetweenTwoNewlines) {
    return change(fromA, toA, '');
  }

  // Step 4: One newline before OR after — allow ONE blank line (\n\n)
  if (before === '\n' || after === '\n') return null;

  // Step 5: Hyphen / dash before cursor — no auto-space
  // (covers both дефіс and знак перенесення)
  if (before && HYPHEN_DASH_RE.test(before)) return null;

  // Step 6: Any other character — auto-add space before newline
  return change(fromA, toA, ' \n');
}

// ---------------------------------------------------------------------------
// handleSpace
//
// Decides what happens when the user types a space at a given position.
// Returns a ChangeSpec to apply, or null to let it pass through.
// ---------------------------------------------------------------------------
function handleSpace(
  doc: EditorState['doc'],
  fromA: number,
  toA: number,
): { from: number; to: number; insert: string } | null {
  const before = charBefore(doc, fromA);
  const after = charAt(doc, fromA);

  // Block if at document start, start of any line (after \n), adjacent
  // to an existing space, or at line start (redundant with auto-space).
  if (fromA === 0 || before === ' ' || before === '\n' || after === ' ') {
    return change(fromA, toA, '');
  }
  return null;
}

// ---------------------------------------------------------------------------
// handlePunctuation
//
// Blocks double consecutive punctuation marks (, : ; - ' ’).
// Returns a ChangeSpec to apply, or null to let it pass through.
// ---------------------------------------------------------------------------
function handlePunctuation(
  doc: EditorState['doc'],
  fromA: number,
  toA: number,
  text: string,
): { from: number; to: number; insert: string } | null {
  if (text.length !== 1 || fromA <= 0) return null;
  if (!REPEATABLE_PUNCT.has(text)) return null;

  const before = charBefore(doc, fromA);
  if (before === text) {
    return change(fromA, toA, '');
  }
  return null; // single punctuation mark is fine
}

// ---------------------------------------------------------------------------
// processSegment
//
// Entry point for processing a single change segment.  Routes to the
// appropriate handler based on the inserted text.
//
// Returns a ChangeSpec when the segment needs modification, or null to
// keep the original unchanged.
// ---------------------------------------------------------------------------
function processSegment(
  doc: EditorState['doc'],
  fromA: number,
  toA: number,
  text: string,
): { from: number; to: number; insert: string } | null {
  // Enter — rarest, checked first
  if (text === '\n') {
    return handleEnter(doc, fromA, toA, charBefore(doc, fromA), charAt(doc, fromA));
  }

  // Space — second rarest
  if (text === ' ') {
    return handleSpace(doc, fromA, toA);
  }

  // Punctuation — blocks doubles on live typing
  if (REPEATABLE_PUNCT.has(text) && fromA > 0) {
    const before = charBefore(doc, fromA);
    if (before === text) {
      return change(fromA, toA, '');
    }
    return null;
  }

  // HOT PATH: regular single character (letter, digit, symbol, etc.)
  // No sliceString calls, no allocations beyond the original toString().
  if (text.length <= 1) return null;

  // MULTI-CHARACTER PATH: paste / bulk insert
  const cleaned = cleanPastedText(text, fromA === 0);
  return cleaned !== text ? change(fromA, toA, cleaned) : null;
}

// ---------------------------------------------------------------------------
// computeNewCursor
//
// Given the replacement changes, compute where the cursor should land.
// Uses TrackAfter semantics — cursor goes PAST the inserted text.
// ---------------------------------------------------------------------------
function computeNewCursor(
  changes: { from: number; to: number; insert: string }[],
  originalCursor: number,
): number {
  if (changes.length === 1) {
    const seg = changes[0]!;
    if (seg.from <= originalCursor && originalCursor <= seg.to) {
      return seg.from + seg.insert.length;
    }
    return originalCursor;
  }

  for (let i = 0; i < changes.length; i++) {
    const seg = changes[i]!;
    if (seg.from <= originalCursor && originalCursor <= seg.to) {
      return seg.from + seg.insert.length;
    }
  }
  return originalCursor;
}

// ---------------------------------------------------------------------------
// opusFormattingFilter — CodeMirror 6 transaction filter
// ---------------------------------------------------------------------------
export function opusFormattingFilter(): Extension {
  return EditorState.transactionFilter.of((transaction) => {
    if (!transaction.docChanged) return transaction;

    const doc = transaction.startState.doc;

    // ── Inline segment storage ─────────────────────────────────────────
    //
    // The FIRST segment is stored in local variables (no heap allocation).
    // A dynamic array is allocated LAZILY ONLY when a second segment
    // appears — typically only during multi-cursor paste.  This eliminates
    // array + object allocation on the 99.9% of keystrokes (regular chars).

    let firstReplacement: { from: number; to: number; insert: string } | null = null;
    let firstFrom = 0, firstTo = 0, firstText = '';
    let anyModified = false;
    let segmentIndex = 0;

    // Lazy-allocated array for transactions with 2+ segments.
    let multiSegment: { from: number; to: number; insert: string }[] | null = null;

    transaction.changes.iterChanges((fromA, toA, _fromB, _toB, inserted) => {
      const text = inserted.toString();
      const replacement = processSegment(doc, fromA, toA, text);

      if (segmentIndex === 0) {
        // First segment — stored inline, no array
        firstFrom = fromA;
        firstTo = toA;
        firstText = text;
        if (replacement !== null) {
          firstReplacement = replacement;
          anyModified = true;
        }
      } else {
        // Second+ segment — allocate the array if not yet created,
        // backfill the first segment into it.
        if (!multiSegment) {
          multiSegment = [];
          multiSegment.push(
            firstReplacement ?? change(firstFrom, firstTo, firstText),
          );
        }
        if (replacement !== null) {
          multiSegment.push(replacement);
          anyModified = true;
        } else {
          multiSegment.push(change(fromA, toA, text));
        }
      }
      segmentIndex++;
    });

    // Fast bail-out: no segment needs modification — return original
    if (!anyModified) return transaction;

    // Combine inline first segment with (optional) multi-segment array
    const replacementChanges = multiSegment ?? [firstReplacement!];

    // Compute cursor position past the inserted text
    const cursorAt = transaction.startState.selection.main.anchor;
    const newCursor = computeNewCursor(replacementChanges, cursorAt);

    return {
      changes: replacementChanges,
      selection: EditorSelection.create([EditorSelection.cursor(newCursor)]),
    };
  });
}
