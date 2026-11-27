import type { ASTNode, NodeType } from './types';

/**
 * Whether `text` has a letter to resolve `dir="auto"` from. Chromium resolves
 * an element with none (digits, punctuation, empty) to LTR instead of
 * inheriting, so such elements must not get `dir="auto"`.
 */
export function hasStrongChar(text: string): boolean {
  return /\p{L}/u.test(text);
}

/**
 * `hasStrongChar` over the text a parent's `dir="auto"` reads: code blocks
 * carry their own `dir="ltr"` and an image's alt text is not content.
 */
export function hasStrongText(node: ASTNode): boolean {
  if (node.type === 'CodeBlock' || node.type === 'Image') return false;
  if (node.content !== undefined) return hasStrongChar(node.content);
  return node.children?.some(hasStrongText) ?? false;
}

/** Recursively collects plain text content from an AST node's subtree. */
export function extractNodeText(node: ASTNode): string {
  if (node.type === 'SoftBreak' || node.type === 'LineBreak') return ' ';
  if (node.content !== undefined) return node.content;
  return node.children?.map(extractNodeText).join('') ?? '';
}

/** Extracts the filename from a URL path, without extension. */
export function filenameFromUrl(url: string): string {
  try {
    const pathname = new URL(url, 'https://placeholder').pathname;
    const filename = pathname.split('/').pop() ?? '';
    return filename.replace(/\.[^.]+$/, '');
  } catch {
    return '';
  }
}

/**
 * Stamps each task ListItem with a sequential `taskIndex` matching the order
 * native C++ assigns — so onTaskListItemPress.index is correct on web too.
 * Mutates the AST in-place (safe: called once on the freshly-parsed result).
 */
export function indexTaskItems(node: ASTNode, counter = { value: 0 }): void {
  if (node.type === 'ListItem' && node.attributes?.isTask === 'true') {
    node.attributes.taskIndex = counter.value++;
  }
  node.children?.forEach((child) => indexTaskItems(child, counter));
}

/** Whether a node holds anything besides images, at any depth (even a space). */
export function hasNonImageContent(node: ASTNode): boolean {
  if (node.type === 'Image') return false;
  if (!node.children?.length) return true;
  return node.children.some(hasNonImageContent);
}

const TEXT_BLOCKS = new Set<NodeType>([
  'Paragraph',
  'Heading',
  'TableCell',
  'TableHeaderCell',
]);

function stampImagesInline(node: ASTNode): void {
  if (node.type === 'Image') {
    node.attributes = { ...node.attributes, isInline: true };
    return;
  }
  node.children?.forEach(stampImagesInline);
}

/**
 * Stamps Image nodes with `isInline` when their paragraph, heading or table
 * cell holds anything besides images, at any depth - so an image inside a
 * link, emphasis or spoiler next to text is inline too. An image alone in its
 * block (or only wrapped in a link) stays block-level, as on native.
 * Mutates the AST in-place (safe: called once on the freshly-parsed result).
 */
export function markInlineImages(node: ASTNode): void {
  if (TEXT_BLOCKS.has(node.type)) {
    if (hasNonImageContent(node)) stampImagesInline(node);
    return;
  }
  node.children?.forEach(markInlineImages);
}
