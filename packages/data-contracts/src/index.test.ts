import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import { contract } from './index';

// Draft-07 is ajv 6's native dialect, matching the schema's $schema.
const validate = new Ajv().compile(contract);

describe('PoetryDataContract facade', () => {
  it('re-exports the JSON schema contract with the exact property shape', () => {
    expect(contract.$schema).toBe('http://json-schema.org/draft-07/schema#');
    expect(contract.type).toBe('object');
    // Exact key list from schemas/contract.json — fails if a property is
    // dropped or truncated (arrayContaining would not).
    expect(Object.keys(contract.properties ?? {})).toEqual([
      'id',
      'version',
      'contract_hash',
      'title',
      'authorId',
      'linesMap',
      'lineOrder',
      'metrics',
      'createdAt',
      'updatedAt',
    ]);
  });

  it('enforces the schema: accepts a valid contract, rejects a broken one', () => {
    expect(
      validate({
        id: '3f0c1b2a-9d4e-4f6a-8b7c-1a2b3c4d5e6f',
        version: 1,
        contract_hash: 'abc',
        linesMap: {},
        lineOrder: [],
      }),
    ).toBe(true);
    // Missing required `lineOrder`, otherwise valid — passes only if the
    // schema's `required` array is dropped or emptied.
    expect(
      validate({
        id: '3f0c1b2a-9d4e-4f6a-8b7c-1a2b3c4d5e6f',
        version: 1,
        contract_hash: 'abc',
        linesMap: {},
      }),
    ).toBe(false);
    // Wrong-typed `version`, all required fields present — passes only if a
    // property type is loosened to `any`.
    expect(
      validate({
        id: '3f0c1b2a-9d4e-4f6a-8b7c-1a2b3c4d5e6f',
        version: 'not-an-integer',
        contract_hash: 'abc',
        linesMap: {},
        lineOrder: [],
      }),
    ).toBe(false);
  });
});
