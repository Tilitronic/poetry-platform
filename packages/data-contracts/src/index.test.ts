import { describe, expect, it } from 'vitest';
import { contract } from './index';

describe('PoetryDataContract facade', () => {
  it('re-exports the JSON schema contract with the expected shape', () => {
    expect(contract.$schema).toBe('http://json-schema.org/draft-07/schema#');
    expect(contract.type).toBe('object');
    expect(Object.keys(contract.properties ?? {})).toEqual(
      expect.arrayContaining([
        'id',
        'version',
        'contract_hash',
        'title',
        'authorId',
        'linesMap',
        'lineOrder',
      ]),
    );
  });
});
