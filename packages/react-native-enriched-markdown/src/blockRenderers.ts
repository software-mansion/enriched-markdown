import { Fragment, isValidElement, useMemo } from 'react';
import type { ReactNode } from 'react';
import type { MarkdownBlock, MarkdownRenderers } from './types/markdownBlocks';

// What a renderer may return at runtime from plain JS, beyond its typed
// `ReactElement | undefined`.
type AnyRenderer = (block: MarkdownBlock) => ReactNode;

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
 * Runs the renderer for the block's kind and validates the result, the same
 * way on native and web. An element replaces the block; `undefined` keeps the
 * native block, and so do `null` and booleans from untyped callers. Strings and
 * numbers, alone or inside an array or fragment, are not valid children of a
 * native view, so they keep the native block too, with a dev warning; so does a
 * renderer that throws.
 */
export function renderBlock(
  renderers: MarkdownRenderers,
  block: MarkdownBlock
): ReactNode | undefined {
  const render = (renderers as Record<string, AnyRenderer | undefined>)[
    block.kind
  ];
  if (typeof render !== 'function') return undefined;
  let element: ReactNode;
  try {
    element = render(block);
  } catch (error) {
    if (__DEV__) {
      console.error(
        `[EnrichedMarkdownText] renderers.${block.kind} threw for ${block.id}; keeping the native block.`,
        error
      );
    }
    return undefined;
  }
  if (element == null || typeof element === 'boolean') return undefined;
  if (isRenderableChild(element)) return element;
  if (__DEV__) {
    console.warn(
      `[EnrichedMarkdownText] renderers.${block.kind} returned ${
        Array.isArray(element) ? 'an array with text' : `a ${typeof element}`
      } for ${block.id}; wrap text in <Text>. Keeping the native block.`
    );
  }
  return undefined;
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
    typeof renderers?.link === 'function'
  );
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
 * screen do not. New renderer functions render every block again.
 */
export function useRenderedBlocks(
  blocks: ReadonlyArray<MarkdownBlock>,
  renderers: MarkdownRenderers | undefined
): ReadonlyArray<RenderedBlock> {
  const enabled = hasRenderers(renderers);
  const image = enabled ? renderers?.image : undefined;
  const video = enabled ? renderers?.video : undefined;
  const link = enabled ? renderers?.link : undefined;
  const cache = useMemo(
    () => new Map<string, RenderedBlock>(),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- one cache per renderer set
    [image, video, link]
  );
  return useMemo(() => {
    if (!enabled) return NO_BLOCKS;
    const rendered: RenderedBlock[] = [];
    const seen = new Set<string>();
    for (const block of blocks) {
      let entry = cache.get(block.id);
      if (entry == null || !sameBlock(entry.block, block)) {
        entry = { block, element: renderBlock({ image, video, link }, block) };
        cache.set(block.id, entry);
      }
      seen.add(block.id);
      if (entry.element != null) rendered.push(entry);
    }
    for (const id of cache.keys()) {
      if (!seen.has(id)) cache.delete(id);
    }
    return rendered;
  }, [blocks, cache, enabled, image, video, link]);
}
