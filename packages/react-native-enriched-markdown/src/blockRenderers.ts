import { Fragment, isValidElement } from 'react';
import type { ReactNode } from 'react';
import type {
  MarkdownBlock,
  MarkdownRenderers,
} from './types/MarkdownTextProps';

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
 * way on native and web. Elements, fragments and arrays of elements replace
 * the block; `null`, `undefined` and booleans keep the native block, like a
 * React child would. Strings and numbers, alone or inside an array, are not
 * valid children of a native view, so they keep the native block too, with a
 * dev warning; so does a renderer that throws.
 */
export function renderBlock(
  renderers: MarkdownRenderers,
  block: MarkdownBlock
): ReactNode | null {
  const render = (renderers as Record<string, AnyRenderer | undefined>)[
    block.kind
  ];
  if (typeof render !== 'function') return null;
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
    return null;
  }
  if (element == null || typeof element === 'boolean') return null;
  if (isRenderableChild(element)) return element;
  if (__DEV__) {
    console.warn(
      `[EnrichedMarkdownText] renderers.${block.kind} returned ${
        Array.isArray(element) ? 'an array with text' : `a ${typeof element}`
      } for ${block.id}; wrap text in <Text>. Keeping the native block.`
    );
  }
  return null;
}
