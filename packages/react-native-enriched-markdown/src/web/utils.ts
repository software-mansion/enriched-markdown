import type { ASTNode } from './types';

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

/**
 * Stamps Image nodes with `isInline` when they appear inside a paragraph
 * that also contains other content (text, links, etc.).
 * Matches native behavior: sole-child images are block-level, mixed are inline.
 * Mutates the AST in-place (safe: called once on the freshly-parsed result).
 */
export function markInlineImages(node: ASTNode): void {
  if (node.type === 'Paragraph' && node.children) {
    const hasNonImageChild = node.children.some(
      (child) => child.type !== 'Image'
    );
    if (hasNonImageChild) {
      for (const child of node.children) {
        if (child.type === 'Image') {
          child.attributes = { ...child.attributes, isInline: true };
        }
      }
    }
  }
  node.children?.forEach(markInlineImages);
}
