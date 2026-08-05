import type { ASTNode } from './types';
import type { Md4cFlags } from '../types/MarkdownStyle';

type ParseFn = (
  markdown: string,
  underline: number,
  latexMath: number,
  superscript: number,
  subscript: number,
  highlight: number,
  hardSoftBreaks: number
) => string;

// Caching the Promise (not the resolved value) means concurrent callers share
// a single WASM initialization — no duplicate loading.
let parserPromise: Promise<ParseFn> | null = null;

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
        ])
      )
      .catch((error) => {
        parserPromise = null;
        throw error;
      }) as Promise<ParseFn>;
  }
  return parserPromise;
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
  {
    underline = false,
    latexMath = true,
    superscript = false,
    subscript = false,
    highlight = false,
    hardSoftBreaks = false,
  }: Md4cFlags = {}
): Promise<ASTNode> {
  const parse = await initializeParser();

  const result: unknown = JSON.parse(
    parse(
      markdown,
      underline ? 1 : 0,
      latexMath ? 1 : 0,
      superscript ? 1 : 0,
      subscript ? 1 : 0,
      highlight ? 1 : 0,
      hardSoftBreaks ? 1 : 0
    )
  );

  if (!isASTNode(result)) {
    throw new Error('WASM parser returned invalid AST');
  }

  return result;
}
