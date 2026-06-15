import { Extension, EditorState } from '@codemirror/state';

const PUNCTUATION = '.,;:';
const SPACE_AFTER_NO_BEFORE_PUNCTUATION = ',.:;?!';

const RG_LIB = Object.freeze({
  // WHITESPACE_AFTER_NEW_LINE: /(?:\r?\n)\s+/g,
  TRAILING_WHITESPACE: /^\s+/gm,
  MULTIPLE_WHITESPACES: /\s{2,}/g,
  MULTIPLE_NEW_LINES: /\n{2,}/g,
  MULTIPLE_PUNCTUATION: new RegExp(`[${PUNCTUATION}]{2,}`, 'g'),
});

export function opusFormattingFilter(): Extension {
  return EditorState.transactionFilter.of((tr) => {
    if (!tr.docChanged) return tr;

    const changes: any[] = [];

    tr.changes.iterChanges((fromA, toA, fromB, toB, inserted) => {
      let text = inserted.toString();

      // 1. LIVE TYPING OPTIMIZATION (Step-by-step keyboard input)

      // A. If user types SPACE
      if (text === ' ' && fromA > 0) {
        const charBefore = tr.startState.doc.sliceString(fromA - 1, fromA);
        // Deny space ONLY if preceding char is also a space
        if (charBefore === ' ') {
          changes.push({ from: fromA, to: toA, insert: '' });
          return;
        }
      }

      // B. If user types ENTER (\n or \r\n)
      if ((text === '\n' || text === '\r\n') && fromA > 0) {
        const charBefore = tr.startState.doc.sliceString(fromA - 1, fromA);

        // Case: Enter pressed right after space -> strip trailing whitespace
        if (charBefore === ' ') {
          changes.push({ from: fromA - 1, to: toA, insert: '\n' });
          return;
        }

        // Case: Third consecutive Enter (check 2 chars back in the document)
        if (fromA >= 2) {
          const twoCharsBefore = tr.startState.doc.sliceString(fromA - 2, fromA);
          if (twoCharsBefore === '\n\n' || twoCharsBefore === '\r\n\r\n') {
            // Block third Enter; max one empty line allowed (\n\n)
            changes.push({ from: fromA, to: toA, insert: '' });
            return;
          }
        }
      }

      // 2. COMBINED DIRTY INPUT & COPY-PASTE PROTECTION (Large inserts)
      if (text.length > 1) {
        let cleanText = text;

        // Step A: Strip trailing spaces and tabs from every line within the insert
        cleanText = cleanText.replace(/[ \t]+$/gm, '');

        // Step B: Normalize Windows line endings to \n for regex consistency
        cleanText = cleanText.replace(/\r\n/g, '\n');

        // Step C: Collapse any sequence of blank lines (with whitespace between) to max ONE blank line
        cleanText = cleanText.replace(/\n([ \t]*\n){2,}/g, '\n\n');

        // Step D: Clean up double spaces within sentences
        cleanText = cleanText.replace(/ {2,}/g, ' ');

        // If cleaned text differs — register a replacement transaction
        if (cleanText !== text.replace(/\r\n/g, '\n')) {
          changes.push({ from: fromA, to: toA, insert: cleanText });
        }
      }
    });

    if (changes.length > 0) {
      return [tr, { changes }];
    }

    return tr;
  });
}
