import type { CSSProperties } from 'react';
import type { MarkdownStyleInternal } from '../types/MarkdownStyleInternal';
import { linkVariantForUrl } from './styles';
import type { ASTNode } from './types';

// Same rule as native: links holding these stay ordinary links.
const NON_PILL_CONTENT = new Set<ASTNode['type']>([
  'Image',
  'LatexMathInline',
  'LineBreak',
  'Spoiler',
]);

export function canBePill(node: ASTNode): boolean {
  return (node.children ?? []).every(
    (child) => !NON_PILL_CONTENT.has(child.type) && canBePill(child)
  );
}

/** The pill presentation for a link node, or undefined when it renders as an ordinary link. */
export function linkPillFor(style: MarkdownStyleInternal, node: ASTNode) {
  const url = node.attributes?.url;
  if (!url) return undefined;
  const variant = linkVariantForUrl(style, url);
  return variant?.pill.enabled && canBePill(node) ? variant : undefined;
}

/**
 * The largest `pill.lineHeight` among the pills inside `node`, or 0. Like
 * native, a block that holds a pill gets lines at least this tall.
 */
export function pillLineHeightIn(
  style: MarkdownStyleInternal,
  node: ASTNode
): number {
  if (style.linkVariants.length === 0) return 0;
  let max = 0;
  const visit = (child: ASTNode) => {
    if (child.type === 'Link') {
      max = Math.max(max, linkPillFor(style, child)?.pill.lineHeight ?? 0);
      return;
    }
    child.children?.forEach(visit);
  };
  node.children?.forEach(visit);
  return max;
}

/** `blockStyle` with its line height raised to the block's pill line height. */
export function withPillLineHeight(
  blockStyle: CSSProperties | undefined,
  style: MarkdownStyleInternal,
  node: ASTNode,
  blockLineHeight: number
): CSSProperties | undefined {
  const pillLineHeight = pillLineHeightIn(style, node);
  return pillLineHeight > blockLineHeight
    ? { ...blockStyle, lineHeight: `${pillLineHeight}px` }
    : blockStyle;
}

const ICON_RETRY_MS = 30_000;
const failedIcons = new Map<string, number>();

/** Like native, a source that failed is not requested again for 30 seconds. */
export function iconFailedRecently(iconUri: string): boolean {
  const failedAt = failedIcons.get(iconUri);
  if (failedAt === undefined) return false;
  if (Date.now() - failedAt < ICON_RETRY_MS) return true;
  failedIcons.delete(iconUri);
  return false;
}

export function markIconFailed(iconUri: string): void {
  failedIcons.set(iconUri, Date.now());
}
