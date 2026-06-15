type TokenType = 'word' | 'punctuation' | 'newline' | 'typographical';

export interface TextToken {
  type: TokenType;
  value: string;
}

export const APOSTROPHE = {
  /** English contractions & possessives */
  eng: ["'", '\u2019'],
  /** Ukrainian hard-sign (U+02BC official, U+2019 & U+0027 are common fallbacks) */
  ukr: ["'", '\u2019', '\u02BC'],
} as const satisfies Record<string, readonly string[]>;

const APOSTROPHE_SET = [...new Set([...APOSTROPHE.eng, ...APOSTROPHE.ukr])];

const escClass = (s: string) => s.replace(/[\]\\^\-]/g, '\\$&');
const WORD_APOS = escClass(APOSTROPHE_SET.join(''));

const WORD = `[\\p{L}\\d]+(?:[${WORD_APOS}][\\p{L}\\d]+)*(?:-[\\p{L}\\d]+(?:[${WORD_APOS}][\\p{L}\\d]+)*)*`;

const TOKEN_RE = new RegExp(`(${WORD})|(\\r?\\n)|([^\\p{L}\\d\\s])|\\s+`, 'gu');

export const PUNCTUATION = {
  eng: [
    '.',
    ',',
    '?',
    '!',
    ';',
    ':',
    '"',
    "'",
    '\u2018',
    '\u2019',
    '\u201C',
    '\u201D',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '\u2013',
    '\u2014',
    '\u2026',
    '/',
    '\\',
  ],
  pol: [
    '.',
    ',',
    '?',
    '!',
    ';',
    ':',
    '"',
    "'",
    '\u201E',
    '\u201D',
    '\u201A',
    '\u2019',
    '\u00AB',
    '\u00BB',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '\u2013',
    '\u2014',
    '\u2026',
    '/',
  ],
  ukr: [
    '.',
    ',',
    '?',
    '!',
    ';',
    ':',
    '"',
    "'",
    '\u00AB',
    '\u00BB',
    '\u201E',
    '\u201D',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '\u2013',
    '\u2014',
    '\u2026',
    '/',
  ],
} as const satisfies Record<string, readonly string[]>;

export function tokenize(text: string): TextToken[] {
  const tokens: TextToken[] = [];
  TOKEN_RE.lastIndex = 0;

  let match: RegExpExecArray | null;
  while ((match = TOKEN_RE.exec(text)) !== null) {
    if (match[1] !== undefined) {
      tokens.push({ type: 'word', value: match[1] });
    } else if (match[2] !== undefined) {
      tokens.push({ type: 'newline', value: match[2] });
    } else if (match[3] !== undefined) {
      tokens.push({ type: 'punctuation', value: match[3] });
    }
  }

  return tokens;
}
