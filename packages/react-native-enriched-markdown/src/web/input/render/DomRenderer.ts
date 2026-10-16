import { LIST_ITEM_BLOCK_TYPES } from '../model/blocks';
import {
  sameRunStyle,
  type ParagraphProjection,
  type StyleRun,
} from './InputProjection';

const LOG_PREFIX = '[EnrichedMarkdown - DomRenderer]';

// Writes the projection into the contentEditable DOM. The caret and IME sit
// in these nodes, so existing nodes are mutated rather than replaced; nodes
// are added or removed only when the paragraph/run structure changes.
//
// Lines are patched by reference through `lines`, not by position under the
// root, which an IME or an extension can change. A root that no longer
// matches `lines` is rebuilt.
export class DomRenderer {
  private readonly root: HTMLElement;
  private renderedText = '';
  // The projection the DOM currently shows, and `changedWindow`'s diff
  // baseline. Safe to hold by reference: the projection layer is a value-copy
  // boundary over the stores (`projectParagraphs` allocates a fresh paragraph
  // per line and `computeStyleRuns` fresh runs, reading stored ranges only for
  // their numbers), so no later store mutation can reach it.
  private renderedParagraphs: readonly ParagraphProjection[] = [];
  private lines: HTMLElement[] = [];
  // Line element -> index into `lines`, so the mapper resolves a DOM point's
  // line in O(1) instead of counting siblings.
  private lineIndices = new WeakMap<Node, number>();
  // Lines something other than this renderer wrote into (an IME), patched on
  // the next render whether or not the model changed there.
  private readonly dirtyLines = new Set<HTMLElement>();

  constructor(root: HTMLElement) {
    this.root = root;
    // A fresh renderer has rendered nothing; the root must reflect that.
    this.root.replaceChildren();
  }

  // Whether some line awaits a rewrite the model alone would not trigger.
  get hasDirtyLines(): boolean {
    return this.dirtyLines.size > 0;
  }

  get lineCount(): number {
    return this.renderedParagraphs.length;
  }

  // Line offsets for the selection mapper, read straight off the baseline so
  // a binary search over them allocates nothing.
  lineStart(index: number): number {
    return this.renderedParagraphs[index]?.start ?? 0;
  }

  lineEnd(index: number): number {
    return this.renderedParagraphs[index]?.end ?? 0;
  }

  lineElement(index: number): HTMLElement | undefined {
    return this.lines[index];
  }

  // The index of `node` among the rendered lines, or -1 when it is not one -
  // including a line element that has since left the root.
  indexOfLine(node: Node): number {
    const index = this.lineIndices.get(node);
    return index !== undefined &&
      this.lines[index] === node &&
      node.parentNode === this.root
      ? index
      : -1;
  }

  // Lines [from, to] were written by someone else (an IME); the next render
  // rewrites them even where the model did not change.
  markLinesDirty(from: number, to: number): void {
    for (let i = Math.max(from, 0); i <= to && i < this.lines.length; i++) {
      this.dirtyLines.add(this.lines[i]!);
    }
  }

  // Drops the diff baseline, so the next `render` rebuilds every line from an
  // empty root. The baseline describes what this renderer wrote, so when
  // something else has written into those nodes - an IME committing into an
  // editor that went read-only mid-composition - the model is unchanged and an
  // ordinary render finds nothing to patch.
  invalidate(): void {
    this.renderedText = '';
    this.renderedParagraphs = [];
    this.lines = [];
    this.lineIndices = new WeakMap();
    this.dirtyLines.clear();
    this.root.replaceChildren();
  }

  render(text: string, paragraphs: readonly ParagraphProjection[]): void {
    try {
      this.patch(text, paragraphs);
    } catch (error) {
      // A half-patched DOM whose cache still claims the pre-edit state is
      // unrecoverable: `changedWindow` would find no difference and patch
      // nothing, ever. Drop the cache and rebuild from an empty root, which
      // takes the all-inserts path and cannot hit a stale node.
      if (__DEV__) {
        console.error(`${LOG_PREFIX} Patch failed; rebuilding the DOM`, error);
      }
      this.invalidate();
      this.patch(text, paragraphs);
    }
  }

  private patch(
    text: string,
    paragraphs: readonly ParagraphProjection[]
  ): void {
    const document = this.root.ownerDocument;
    const window = changedWindow(
      this.renderedText,
      this.renderedParagraphs,
      text,
      paragraphs
    );
    if (!this.linesIntact(window.start, window.stalePairs)) {
      this.invalidate();
      this.patch(text, paragraphs);
      return;
    }
    const { start, stalePairs, freshPairs } = window;
    const patched = Math.min(stalePairs, freshPairs);
    const removed = stalePairs - patched;
    const inserted = freshPairs - patched;

    for (let i = 0; i < patched; i++) {
      patchParagraph(
        document,
        this.lines[start + i]!,
        text,
        paragraphs[start + i]!
      );
    }

    const spliceAt = start + patched;
    if (removed > 0 || inserted > 0) {
      for (let i = 0; i < removed; i++) {
        this.lines[spliceAt + i]!.remove();
      }
      const suffixAnchor = this.lines[spliceAt + removed] ?? null;
      const fresh: HTMLElement[] = [];
      for (let i = 0; i < inserted; i++) {
        const line = createParagraph(document, text, paragraphs[spliceAt + i]!);
        this.root.insertBefore(line, suffixAnchor);
        fresh.push(line);
      }
      // Not `splice(..., ...fresh)`: an initial render inserts every line, and
      // spreading tens of thousands of arguments overflows the stack.
      this.lines = this.lines
        .slice(0, spliceAt)
        .concat(fresh, this.lines.slice(spliceAt + removed));
      // Equal counts shift nothing, so only the fresh lines need an index.
      const reindexTo =
        removed === inserted ? spliceAt + inserted : this.lines.length;
      for (let i = spliceAt; i < reindexTo; i++) {
        this.lineIndices.set(this.lines[i]!, i);
      }
    }

    this.renumberAfter(start + freshPairs, stalePairs - freshPairs, paragraphs);

    for (const line of this.dirtyLines) {
      const index = this.indexOfLine(line);
      if (index !== -1) {
        patchParagraph(document, line, text, paragraphs[index]!);
      }
    }
    this.dirtyLines.clear();

    this.renderedText = text;
    this.renderedParagraphs = [...paragraphs];
  }

  // The window match ignores ordinals (Enter in a list would otherwise
  // shift every later number and send the whole list through the patch), so
  // the matched items after the window may still need a new `data-ordinal`.
  // Walks the list run from `from` until an unchanged top-level item: the
  // store's counters are back in step there, so nothing later differs.
  private renumberAfter(
    from: number,
    shift: number,
    paragraphs: readonly ParagraphProjection[]
  ): void {
    for (
      let i = from;
      i < paragraphs.length &&
      LIST_ITEM_BLOCK_TYPES.has(paragraphs[i]!.blockType);
      i++
    ) {
      const ordinal = ordinalAttribute(paragraphs[i]!);
      if (ordinal !== ordinalAttribute(this.renderedParagraphs[i + shift]!)) {
        setData(this.lines[i]!, 'ordinal', ordinal);
      } else if (paragraphs[i]!.level === 0) {
        break;
      }
    }
  }

  // Whether the patch can trust `lines`: the child count catches additions
  // and removals, and the patched window is checked for swapped lines. Not
  // a full walk, which would cost O(lines) per keystroke.
  private linesIntact(start: number, stalePairs: number): boolean {
    if (this.root.childNodes.length !== this.lines.length) {
      return false;
    }
    const end = Math.min(start + stalePairs, this.lines.length - 1);
    for (let i = start; i <= end; i++) {
      if (this.lines[i]!.parentNode !== this.root) {
        return false;
      }
    }
    for (const line of this.dirtyLines) {
      if (line.parentNode !== this.root && this.lineIndices.has(line)) {
        return false;
      }
    }
    return true;
  }
}

// An edit changes one contiguous window of paragraphs. Pairs the shared
// prefix and suffix (by content, not offsets) and returns the window between
// them: where it starts and how many old/new paragraphs fall inside.
function changedWindow(
  previousText: string,
  previous: readonly ParagraphProjection[],
  text: string,
  next: readonly ParagraphProjection[]
): { start: number; stalePairs: number; freshPairs: number } {
  const maxShared = Math.min(previous.length, next.length);

  let prefix = 0;
  while (
    prefix < maxShared &&
    sameParagraph(previousText, previous[prefix]!, text, next[prefix]!)
  ) {
    prefix++;
  }

  let suffix = 0;
  while (
    suffix < maxShared - prefix &&
    sameParagraph(
      previousText,
      previous[previous.length - 1 - suffix]!,
      text,
      next[next.length - 1 - suffix]!
    )
  ) {
    suffix++;
  }

  return {
    start: prefix,
    stalePairs: previous.length - prefix - suffix,
    freshPairs: next.length - prefix - suffix,
  };
}

function sameParagraph(
  previousText: string,
  previous: ParagraphProjection,
  text: string,
  next: ParagraphProjection
): boolean {
  return (
    previous.blockType === next.blockType &&
    previous.level === next.level &&
    previous.runs.length === next.runs.length &&
    previous.runs.every((run, i) =>
      sameRun(previousText, run, text, next.runs[i]!)
    )
  );
}

function sameRun(
  previousText: string,
  previous: StyleRun,
  text: string,
  next: StyleRun
): boolean {
  return (
    sameRunStyle(previous, next.styles, next.url) &&
    previousText.slice(previous.start, previous.end) ===
      text.slice(next.start, next.end)
  );
}

export function classNameFor(styles: StyleRun['styles']): string {
  return styles.map((style) => `enrm-${style}`).join(' ');
}

function createParagraph(
  document: Document,
  text: string,
  paragraph: ParagraphProjection
): HTMLElement {
  const element = document.createElement('div');
  patchParagraph(document, element, text, paragraph);
  return element;
}

function patchParagraph(
  document: Document,
  element: HTMLElement,
  text: string,
  paragraph: ParagraphProjection
): void {
  patchBlockAttributes(element, paragraph);

  if (paragraph.runs.length === 0) {
    // The <br> gives an empty paragraph height and a caret spot.
    if (
      element.childNodes.length !== 1 ||
      element.firstChild!.nodeName !== 'BR'
    ) {
      element.replaceChildren(document.createElement('br'));
    }
    return;
  }

  // Drop every child that is not a reusable run span: the <br> a formerly
  // empty line carried, and anything an IME or a browser extension left
  // behind. The model is authoritative by the time a render runs, and keeping
  // a foreign node would both break the index correspondence the mapper reads
  // positions through and send `patchRun` at a node with no text child.
  for (const child of [...element.childNodes]) {
    if (!isReusableRun(child)) {
      child.remove();
    }
  }
  while (element.children.length > paragraph.runs.length) {
    element.lastElementChild!.remove();
  }
  paragraph.runs.forEach((run, index) => {
    const existing = element.children[index];
    if (existing === undefined) {
      element.appendChild(createRun(document, text, run));
    } else {
      patchRun(existing as HTMLElement, text, run);
    }
  });
}

// A run span as `createRun` builds them: one text node, and only the
// attributes `patchRun` manages - an IME can leave an inline `style` behind.
export function isReusableRun(node: Node): boolean {
  if (
    node.nodeName !== 'SPAN' ||
    node.childNodes.length !== 1 ||
    node.firstChild!.nodeType !== Node.TEXT_NODE
  ) {
    return false;
  }
  for (const { name } of (node as Element).attributes) {
    if (name !== 'class' && name !== 'data-url') {
      return false;
    }
  }
  return true;
}

function patchBlockAttributes(
  element: HTMLElement,
  paragraph: ParagraphProjection
): void {
  const isListItem = LIST_ITEM_BLOCK_TYPES.has(paragraph.blockType);
  setData(
    element,
    'block',
    paragraph.blockType === 'paragraph' ? undefined : paragraph.blockType
  );
  setData(element, 'depth', isListItem ? String(paragraph.level) : undefined);
  setData(element, 'ordinal', ordinalAttribute(paragraph));
}

// Only ordered items show their ordinal; the store numbers bullets too.
function ordinalAttribute(paragraph: ParagraphProjection): string | undefined {
  return paragraph.blockType === 'ordered-list-item'
    ? String(paragraph.ordinal)
    : undefined;
}

function setData(
  element: HTMLElement,
  key: string,
  value: string | undefined
): void {
  if (value === undefined) {
    if (element.dataset[key] !== undefined) delete element.dataset[key];
  } else if (element.dataset[key] !== value) {
    element.dataset[key] = value;
  }
}

function createRun(
  document: Document,
  text: string,
  run: StyleRun
): HTMLElement {
  const span = document.createElement('span');
  span.appendChild(document.createTextNode(''));
  patchRun(span, text, run);
  return span;
}

function patchRun(span: HTMLElement, text: string, run: StyleRun): void {
  const className = classNameFor(run.styles);
  if (span.className !== className) {
    span.className = className;
  }
  setData(span, 'url', run.url);

  const content = text.slice(run.start, run.end);
  const textNode = span.firstChild as Text;
  const current = textNode.data;
  if (current !== content) {
    replaceChangedData(textNode, current, content);
  }
}

// `replaceData` over the changed window, not a `nodeValue` assignment, which
// collapses a live caret to 0 and drops Blink's spellcheck markers.
function replaceChangedData(node: Text, current: string, next: string): void {
  const maxShared = Math.min(current.length, next.length);
  let prefix = 0;
  while (prefix < maxShared && current[prefix] === next[prefix]) {
    prefix++;
  }
  let suffix = 0;
  while (
    suffix < maxShared - prefix &&
    current[current.length - 1 - suffix] === next[next.length - 1 - suffix]
  ) {
    suffix++;
  }
  node.replaceData(
    prefix,
    current.length - prefix - suffix,
    next.slice(prefix, next.length - suffix)
  );
}
