/**
 * Typed facade over the single source of truth (schemas/contract.json).
 *
 * Consumers import `PoetryDataContract` for the compile-time shape and
 * `contract` for the runtime object; both derive from the JSON schema so the
 * contract never drifts from its source. JSON Schema itself stays authoritative
 * — this module only re-exports it with type-safety, it does not redefine it.
 */
import contract from '../schemas/contract.json';

export { contract };

export type PoetryDataContract = typeof contract;
