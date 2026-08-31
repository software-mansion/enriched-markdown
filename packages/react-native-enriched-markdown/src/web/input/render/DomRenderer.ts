import { LIST_ITEM_BLOCK_TYPES } from '../model/blocks';
import type { ParagraphProjection, StyleRun } from './InputProjection';

// Writes the projection into the contentEditable DOM. The caret and IME sit
// in these nodes, so existing nodes are mutated rather than replaced; nodes
// are added or removed only when the paragraph/run structure changes.
export class DomRenderer {
  private readonly root: HTMLElement;
  private renderedText = '';
  private renderedParagraphs: readonly ParagraphProjection[] = [];

  constructor(root: HTMLElement) {
    this.root = root;
    // A fresh renderer has rendered nothing; the root must reflect that.
    this.root.replaceChildren();
  }

  render(text: string, paragraphs: readonly ParagraphProjection[]): void {
    const document = this.root.ownerDocument;
    const { start, stalePairs, freshPairs } = changedWindow(
      this.renderedText,
      this.renderedParagraphs,
      text,
      paragraphs
    );
    const patched = Math.min(stalePairs, freshPairs);
    const removed = stalePairs - patched;
    const inserted = freshPairs - patched;

    for (let i = 0; i < patched; i++) {
      patchParagraph(
        document,
        this.root.childNodes[start + i] as HTMLElement,
        text,
        paragraphs[start + i]!
      );
    }
    for (let i = 0; i < removed; i++) {
      this.root.childNodes[start + patched]!.remove();
    }
    const suffixAnchor = this.root.childNodes[start + patched] ?? null;
    for (let i = 0; i < inserted; i++) {
      this.root.insertBefore(
        createParagraph(document, text, paragraphs[start + patched + i]!),
        suffixAnchor
      );
    }

    this.renderedText = text;
    this.renderedParagraphs = [...paragraphs];
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
    previous.ordinal === next.ordinal &&
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
    classNameFor(previous.styles) === classNameFor(next.styles) &&
    previous.url === next.url &&
    previousText.slice(previous.start, previous.end) ===
      text.slice(next.start, next.end)
  );
}

function classNameFor(styles: StyleRun['styles']): string {
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

  if (element.firstChild?.nodeName === 'BR') {
    element.firstChild.remove();
  }
  while (element.childNodes.length > paragraph.runs.length) {
    element.lastChild!.remove();
  }
  paragraph.runs.forEach((run, index) => {
    const existing = element.childNodes[index];
    if (existing === undefined) {
      element.appendChild(createRun(document, text, run));
    } else {
      patchRun(existing as HTMLElement, text, run);
    }
  });
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
  setData(
    element,
    'ordinal',
    paragraph.blockType === 'ordered-list-item'
      ? String(paragraph.ordinal)
      : undefined
  );
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
  if (textNode.nodeValue !== content) {
    textNode.nodeValue = content;
  }
}
