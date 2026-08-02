/**
 * JS Lang Detector — W1 (Stress and Lang Worker), per architecture.md §W1.
 *
 * Contract: identifies an ISO-639-1 language code for a token so the WASM
 * Stress Orchestrator can pick the right stress index. Implementation is
 * pending (eld/tinyld); this module pins the seam's public surface so a
 * consumer can't drift from the shape the worker expects.
 */

export interface LangDetection {
  /** ISO-639-1 language code, lowercased (e.g. "en", "uk"). */
  lang: string;
  /** Detector confidence in [0, 1]; undefined when the model is unsure. */
  confidence?: number;
}

/**
 * Detect the language of a single token. Scaffold only — the real eld/tinyld
 * lookup lands here. Throws so a caller relying on it fails loudly instead of
 * silently getting an empty result.
 */
export function detectTokenLang(_token: string): LangDetection {
  throw new Error('detectTokenLang is not implemented yet');
}
