import type { ASTNode } from './types';
import type { Md4cFlags } from '../types/MarkdownStyle';
import createMd4cModule, { type Md4cModuleArg } from './wasm/md4c';
import { isDev } from '../utils/isDev';

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

// Set by the first parse: later ones reuse the instance.
let loadedParser: ParseFn | null = null;
// Set when that load failed. It fails the same way again (no WebAssembly, or a
// CSP without 'wasm-unsafe-eval'), so later parses throw this instead of
// decoding the binary again, on every render of a streamed document too.
let loadFailure: Error | null = null;

// SINGLE_FILE=1 inlines the WASM binary in md4c.js and
// WASM_ASYNC_COMPILATION=0 compiles it inside the factory call, so the first
// parse loads it in place: no render waits for it, on the server, while
// hydrating, or in the browser.
function getParser(): ParseFn {
  if (loadedParser) return loadedParser;
  if (loadFailure) throw loadFailure;

  let initialized = false;
  const wasmModule: Md4cModuleArg = {
    onRuntimeInitialized: () => {
      initialized = true;
    },
  };
  // Emscripten still declares the factory `async`, though it has run by the
  // time it returns. A failure only rejects its promise, after this function
  // has returned: here it shows as `initialized` staying false.
  createMd4cModule(wasmModule).catch((error: unknown) => {
    if (isDev) {
      console.error(
        '[react-native-enriched-markdown] WASM parser failed to load:',
        error
      );
    }
  });
  if (!initialized || !wasmModule.cwrap) {
    loadFailure = new Error('WASM parser failed to load');
    throw loadFailure;
  }

  loadedParser = wasmModule.cwrap('parseMarkdown', 'string', [
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
  ]) as ParseFn;
  return loadedParser;
}

function isASTNode(value: unknown): value is ASTNode {
  return (
    typeof value === 'object' &&
    value !== null &&
    'type' in value &&
    typeof (value as ASTNode).type === 'string'
  );
}

/**
 * Parses in place, loading the WASM on the first call. Throws when the parse
 * fails or the WASM cannot load.
 */
export function parseMarkdownSync(
  markdown: string,
  flags: WebMd4cFlags = {}
): ASTNode {
  return runParser(getParser(), markdown, flags);
}

/** {@link parseMarkdownSync}, as a promise for the input's import pipeline. */
export async function parseMarkdown(
  markdown: string,
  flags: WebMd4cFlags = {}
): Promise<ASTNode> {
  return parseMarkdownSync(markdown, flags);
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
