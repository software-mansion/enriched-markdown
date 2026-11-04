export interface KaTeXInstance {
  renderToString(
    expression: string,
    options?: {
      displayMode?: boolean;
      throwOnError?: boolean;
      trust?: boolean;
      output?: 'html' | 'mathml' | 'htmlAndMathml';
    }
  ): string;
}

// `undefined` until the first lookup; `null` when KaTeX is not installed.
let katexInstance: KaTeXInstance | null | undefined;

/** Lazily loads KaTeX. Returns null if not installed. */
export function loadKaTeX(): KaTeXInstance | null {
  if (katexInstance === undefined) {
    katexInstance = null;
    try {
      const mod = require('katex');
      const candidate = (mod?.default ?? mod) as KaTeXInstance | null;
      if (typeof candidate?.renderToString === 'function') {
        katexInstance = candidate;
      }
    } catch {
      // katex not installed — math rendering will be skipped
    }
  }
  return katexInstance;
}
