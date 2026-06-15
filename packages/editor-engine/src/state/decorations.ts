export type DecorationType =
  | 'stressed'
  | 'unstressed'
  | 'caesura'
  | 'enjambment'
  | 'rhyme-a'
  | 'rhyme-b'
  | 'phoneme-vowel'
  | 'phoneme-consonant';

export interface LineDecoration {
  from: number;
  to: number;
  type: DecorationType;
}
