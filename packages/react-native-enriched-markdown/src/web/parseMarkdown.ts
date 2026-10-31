import type { ASTNode } from './types';
import type { Md4cFlags } from '../types/MarkdownStyle';

type ParseFn = (
  markdown: string,
  underline: number,
  latexMath: number,
  superscript: number,
  subscript: number,
  highlight: number,
  hardSoftBreaks: number,
  preserveBlankLines: number,
  admonitions: number,
  permissiveAutolinks: number
) => string;

/**
 * Parser options accepted by the web bridge: the public {@link Md4cFlags} plus
 * the flags the WASM parser understands but the component API does not expose.
 *
 * `permissiveAutolinks` has to stay settable because the two web call sites
 * want opposite values. The display component omits it and relies on the
 * `true` default, which is what renders bare URLs as links and matches the
 * native parsers, where the flag defaults on at every layer. The input editor
 * forces it off so its own autolink layer owns bare URLs. It is kept off
 * `Md4cFlags` rather than exposed because a public prop would be silently
 * ignored on iOS and Android, neither of which forwards it to its parser.
 */
export type WebMd4cFlags = Md4cFlags & {
  /**
   * Autolink bare URLs and e-mail addresses without angle brackets.
   * When disabled, only explicit `[text](url)` and `<url>` links are parsed.
   * @default true
   */
  permissiveAutolinks?: boolean;
};

// Caching the Promise (not the resolved value) means concurrent callers share
// a single WASM initialization — no duplicate loading.
let parserPromise: Promise<ParseFn> | null = null;
// Set once the WASM is up, so later parses can run synchronously in render.
let loadedParser: ParseFn | null = null;
const parserReadyListeners = new Set<() => void>();

// SINGLE_FILE=1 inlines the WASM binary as base64 inside md4c.js, so no
// network fetch is needed — only a one-time decode + compile on first call.
function initializeParser(): Promise<ParseFn> {
  if (!parserPromise) {
    parserPromise = import('./wasm/md4c')
      .then((module) => module.default())
      .then((wasmModule) =>
        wasmModule.cwrap('parseMarkdown', 'string', [
          'string',
          'number',
          'number',
          'number',
          'number',
          'number',
          'number',
          'number',
          'number',
          'number',
        ])
      )
      .then((wrapped) => {
        const parse = wrapped as ParseFn;
        loadedParser = parse;
        parserReadyListeners.forEach((listener) => listener());
        return parse;
      })
      .catch((error) => {
        parserPromise = null;
        throw error;
      }) as Promise<ParseFn>;
  }
  return parserPromise;
}

/** Starts the WASM load, or retries one that failed. */
export function loadParser(): Promise<void> {
  return initializeParser().then(() => {});
}

/** Whether {@link parseMarkdownSync} can run. */
export function isParserReady(): boolean {
  return loadedParser !== null;
}

/** Calls `listener` once the WASM load finishes. */
export function subscribeParserReady(listener: () => void): () => void {
  parserReadyListeners.add(listener);
  return () => {
    parserReadyListeners.delete(listener);
  };
}

// Starts the WASM load ahead of the first parse, so that parse settles in
// microtasks. Skipped without a `window` (SSR), where no editor will mount.
export function preloadParser(): Promise<void> {
  if (typeof window === 'undefined') {
    return Promise.resolve();
  }
  // A failure is left to the first real parse, which retries the load.
  return initializeParser().then(
    () => {},
    () => {}
  );
}

function isASTNode(value: unknown): value is ASTNode {
  return (
    typeof value === 'object' &&
    value !== null &&
    'type' in value &&
    typeof (value as ASTNode).type === 'string'
  );
}

export async function parseMarkdown(
  markdown: string,
  flags: WebMd4cFlags = {}
): Promise<ASTNode> {
  return runParser(await initializeParser(), markdown, flags);
}

/**
 * Parses without waiting, for callers that render the result in the same
 * pass. Throws when the WASM has not loaded yet: check {@link isParserReady}.
 */
export function parseMarkdownSync(
  markdown: string,
  flags: WebMd4cFlags = {}
): ASTNode {
  if (!loadedParser) {
    throw new Error('WASM parser is not loaded');
  }
  return runParser(loadedParser, markdown, flags);
}

function runParser(
  parse: ParseFn,
  markdown: string,
  {
    underline = false,
    latexMath = true,
    superscript = false,
    subscript = false,
    highlight = false,
    hardSoftBreaks = false,
    preserveBlankLines = false,
    admonitions = true,
    permissiveAutolinks = true,
  }: WebMd4cFlags
): ASTNode {
  const result: unknown = JSON.parse(
    parse(
      markdown,
      underline ? 1 : 0,
      latexMath ? 1 : 0,
      superscript ? 1 : 0,
      subscript ? 1 : 0,
      highlight ? 1 : 0,
      hardSoftBreaks ? 1 : 0,
      preserveBlankLines ? 1 : 0,
      admonitions ? 1 : 0,
      permissiveAutolinks ? 1 : 0
    )
  );

  if (!isASTNode(result)) {
    throw new Error('WASM parser returned invalid AST');
  }

  return result;
}
