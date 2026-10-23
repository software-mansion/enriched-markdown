import { Fragment, isValidElement, useMemo, useRef } from 'react';
import type { ReactNode } from 'react';
import { compilePattern } from './linkVariantUtils';
import type {
  MarkdownBlock,
  MarkdownCodeBlock,
  MarkdownRenderers,
} from './types/markdownBlocks';

// What a renderer may return at runtime from plain JS, beyond its typed
// `ReactElement | undefined`.
type AnyRenderer = (block: MarkdownBlock) => ReactNode;

/** A renderer and the name its warnings give it. */
interface PickedRenderer {
  render: AnyRenderer;
  name: string;
}

/** Picks the renderer for a code block, or undefined to keep the native one. */
export type CodeRendererResolver = (
  block: MarkdownCodeBlock
) => PickedRenderer | undefined;

/** `renderers` with `code` resolved to one renderer per block. */
export interface ResolvedRenderers {
  image?: MarkdownRenderers['image'];
  video?: MarkdownRenderers['video'];
  link?: MarkdownRenderers['link'];
  code?: CodeRendererResolver;
}

function pickRenderer(
  renderers: ResolvedRenderers,
  block: MarkdownBlock
): PickedRenderer | undefined {
  if (block.kind === 'code') return renderers.code?.(block);
  const render = (renderers as Record<string, unknown>)[block.kind];
  return typeof render === 'function'
    ? { render: render as AnyRenderer, name: `renderers.${block.kind}` }
    : undefined;
}

/**
 * Whether a renderer's result can be a child of a plain view: elements,
 * `null`, `undefined`, booleans, and arrays or fragments of those, at any
 * depth. Strings and numbers are not; a native view throws on them. Other
 * elements are opaque: `<Text>` renders its own text.
 */
function isRenderableChild(node: ReactNode): boolean {
  if (node == null || typeof node === 'boolean') return true;
  if (Array.isArray(node)) return node.every(isRenderableChild);
  if (!isValidElement<{ children?: ReactNode }>(node)) return false;
  return node.type !== Fragment || isRenderableChild(node.props.children);
}

/**
 * Runs the renderer for the block's kind (for a code block, the one its
 * language picks) and validates the result, the same way on native and web. An
 * element replaces the block; `undefined` keeps the native block, and so do
 * `null` and booleans from untyped callers. Strings and numbers, alone or
 * inside an array or fragment, are not valid children of a native view, so
 * they keep the native block too, with a dev warning; so does a renderer that
 * throws.
 */
export function renderBlock(
  renderers: ResolvedRenderers,
  block: MarkdownBlock
): ReactNode | undefined {
  const picked = pickRenderer(renderers, block);
  if (picked == null) return undefined;
  let element: ReactNode;
  try {
    element = picked.render(block);
  } catch (error) {
    if (__DEV__) {
      console.error(
        `[EnrichedMarkdownText] ${picked.name} threw for ${block.id}; keeping the native block.`,
        error
      );
    }
    return undefined;
  }
  if (element == null || typeof element === 'boolean') return undefined;
  if (isRenderableChild(element)) return element;
  if (__DEV__) {
    console.warn(
      `[EnrichedMarkdownText] ${picked.name} returned ${
        Array.isArray(element) ? 'an array with text' : `a ${typeof element}`
      } for ${block.id}; wrap text in <Text>. Keeping the native block.`
    );
  }
  return undefined;
}

function hasCodeRenderer(code: MarkdownRenderers['code']): boolean {
  if (typeof code === 'function') return true;
  if (code == null || typeof code !== 'object') return false;
  return (
    typeof code.default === 'function' ||
    Object.values(code.languages ?? {}).some(
      (entry) => typeof entry?.content === 'function'
    )
  );
}

/**
 * Whether any `renderers` entry is a function: `{}`, `undefined` entries and
 * unknown keys cost no parse. Shared by native, web and `useRenderedBlocks`.
 */
export function hasRenderers(
  renderers: MarkdownRenderers | undefined
): boolean {
  return (
    typeof renderers?.image === 'function' ||
    typeof renderers?.video === 'function' ||
    typeof renderers?.link === 'function' ||
    hasCodeRenderer(renderers?.code)
  );
}

// `renderers.code` as given, before any pattern compiles, so an inline object
// literal can be compared with the previous render's.
interface FlatCodeRenderers {
  fallback?: PickedRenderer;
  languages: Array<{ id: string; pattern: unknown; content: unknown }>;
}

function flattenCodeRenderers(
  code: MarkdownRenderers['code']
): FlatCodeRenderers {
  if (typeof code === 'function') {
    return {
      fallback: { render: code as AnyRenderer, name: 'renderers.code' },
      languages: [],
    };
  }
  if (code == null || typeof code !== 'object') return { languages: [] };
  return {
    fallback:
      typeof code.default === 'function'
        ? {
            render: code.default as AnyRenderer,
            name: 'renderers.code.default',
          }
        : undefined,
    languages: Object.entries(code.languages ?? {}).map(([id, entry]) => ({
      id,
      pattern: entry?.pattern,
      content: entry?.content,
    })),
  };
}

function samePattern(a: unknown, b: unknown): boolean {
  if (a instanceof RegExp && b instanceof RegExp) {
    return a.source === b.source && a.flags === b.flags;
  }
  return a === b;
}

function sameFlatCodeRenderers(
  a: FlatCodeRenderers,
  b: FlatCodeRenderers
): boolean {
  return (
    a.fallback?.render === b.fallback?.render &&
    a.fallback?.name === b.fallback?.name &&
    a.languages.length === b.languages.length &&
    a.languages.every((entry, index) => {
      const other = b.languages[index]!;
      return (
        entry.id === other.id &&
        entry.content === other.content &&
        samePattern(entry.pattern, other.pattern)
      );
    })
  );
}

// A global or sticky flag makes `test` keep state between blocks, so both are dropped.
function compileLanguagePattern(
  id: string,
  pattern: unknown
): RegExp | undefined {
  const name = `[EnrichedMarkdownText] renderers.code.languages.${id}`;
  if (pattern instanceof RegExp) {
    return new RegExp(pattern.source, pattern.flags.replace(/[gy]/g, ''));
  }
  if (typeof pattern === 'string') return compilePattern(pattern, name);
  if (__DEV__) {
    console.warn(
      `${name} needs a string or RegExp \`pattern\` and will be ignored.`
    );
  }
  return undefined;
}

function patternLength(pattern: unknown): number {
  if (pattern instanceof RegExp) return pattern.source.length;
  return typeof pattern === 'string' ? pattern.length : 0;
}

function codeResolver(
  flat: FlatCodeRenderers
): CodeRendererResolver | undefined {
  const languages: Array<{ regex: RegExp; renderer: PickedRenderer }> = [];
  // Longest pattern first, as for `linkVariants`; ties keep their order.
  const entries = [...flat.languages].sort(
    (a, b) => patternLength(b.pattern) - patternLength(a.pattern)
  );
  for (const { id, pattern, content } of entries) {
    if (typeof content !== 'function') continue;
    const regex = compileLanguagePattern(id, pattern);
    if (regex == null) continue;
    languages.push({
      regex,
      renderer: {
        render: content as AnyRenderer,
        name: `renderers.code.languages.${id}`,
      },
    });
  }
  const { fallback } = flat;
  if (languages.length === 0 && fallback == null) return undefined;
  return (block) =>
    languages.find(({ regex }) => regex.test(block.language))?.renderer ??
    fallback;
}

/**
 * Turns `renderers.code` into one resolver per distinct set of renderers. The
 * resolver keeps its identity while the functions and patterns stay the same,
 * so an inline `{ default, languages }` literal does not render every block
 * again on each render.
 */
export function useCodeRenderer(
  code: MarkdownRenderers['code']
): CodeRendererResolver | undefined {
  const last = useRef<
    | { flat: FlatCodeRenderers; resolve: CodeRendererResolver | undefined }
    | undefined
  >(undefined);
  return useMemo(() => {
    const flat = flattenCodeRenderers(code);
    if (
      last.current == null ||
      !sameFlatCodeRenderers(last.current.flat, flat)
    ) {
      last.current = { flat, resolve: codeResolver(flat) };
    }
    return last.current.resolve;
  }, [code]);
}

export interface RenderedBlock {
  block: MarkdownBlock;
  element: ReactNode;
}

const NO_BLOCKS: ReadonlyArray<RenderedBlock> = [];

function sameBlock(a: MarkdownBlock, b: MarkdownBlock): boolean {
  const keys = Object.keys(a) as Array<keyof MarkdownBlock>;
  return (
    keys.length === Object.keys(b).length &&
    keys.every((key) => a[key] === b[key])
  );
}

/**
 * `renderBlock` over the blocks that a renderer replaces, in document order.
 * An unchanged block keeps its previous element, so React skips its subtree:
 * while streaming, the markdown changes every tick but the blocks already on
 * screen do not. New renderer functions render every block again; for `code`,
 * new functions or patterns do (see `useCodeRenderer`).
 */
export function useRenderedBlocks(
  blocks: ReadonlyArray<MarkdownBlock>,
  renderers: MarkdownRenderers | undefined
): ReadonlyArray<RenderedBlock> {
  const enabled = hasRenderers(renderers);
  const image = enabled ? renderers?.image : undefined;
  const video = enabled ? renderers?.video : undefined;
  const link = enabled ? renderers?.link : undefined;
  const code = useCodeRenderer(enabled ? renderers?.code : undefined);
  const cache = useMemo(
    () => new Map<string, RenderedBlock>(),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- one cache per renderer set
    [image, video, link, code]
  );
  return useMemo(() => {
    if (!enabled) return NO_BLOCKS;
    const rendered: RenderedBlock[] = [];
    const seen = new Set<string>();
    for (const block of blocks) {
      let entry = cache.get(block.id);
      if (entry == null || !sameBlock(entry.block, block)) {
        entry = {
          block,
          element: renderBlock({ image, video, link, code }, block),
        };
        cache.set(block.id, entry);
      }
      seen.add(block.id);
      if (entry.element != null) rendered.push(entry);
    }
    for (const id of cache.keys()) {
      if (!seen.has(id)) cache.delete(id);
    }
    return rendered;
  }, [blocks, cache, enabled, image, video, link, code]);
}
