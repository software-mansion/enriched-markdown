import type { RangeBounds } from '../model/rangeBounds';
import type { ParagraphProjection } from '../render/InputProjection';
import { firstIndexReachingTarget } from '../utils';

export interface DomPosition {
  node: Node;
  offset: number;
}

// Translates DOM positions to buffer offsets and back over the renderer's
// canonical DOM. Line offsets come from the projection the renderer last
// wrote.
// A run-boundary offset maps to the start of the following run.
export class SelectionMapper {
  private readonly root: HTMLElement;
  private readonly paragraphs: () => readonly ParagraphProjection[];

  constructor(
    root: HTMLElement,
    paragraphs: () => readonly ParagraphProjection[]
  ) {
    this.root = root;
    this.paragraphs = paragraphs;
  }

  // Returns null for positions outside the editor.
  modelOffsetFromDom(node: Node, offset: number): number | null {
    if (node === this.root) {
      const paragraph = this.paragraphs()[offset];
      return paragraph === undefined ? this.documentLength() : paragraph.start;
    }

    const paragraph = this.paragraphContaining(node);
    if (paragraph === null) {
      return null;
    }
    return (
      this.lineStart(paragraph) + offsetWithinParagraph(paragraph, node, offset)
    );
  }

  // Offsets past the end clamp to the end of the document.
  domPositionFromModelOffset(offset: number): DomPosition | null {
    const paragraphs = this.paragraphs();
    if (paragraphs.length === 0) {
      return null;
    }
    const clamped = Math.max(offset, 0);
    const index = Math.min(
      firstIndexReachingTarget(
        clamped,
        paragraphs.length,
        (i) => paragraphs[i]!.end
      ),
      paragraphs.length - 1
    );
    const element = this.root.children[index];
    if (element === undefined) {
      return null;
    }
    const { start, end } = paragraphs[index]!;
    return positionInParagraph(element, Math.min(clamped - start, end - start));
  }

  modelSelectionFromDom(selection: Selection): RangeBounds | null {
    const { anchorNode, anchorOffset, focusNode, focusOffset } = selection;
    if (anchorNode === null || focusNode === null) {
      return null;
    }
    const anchor = this.modelOffsetFromDom(anchorNode, anchorOffset);
    const focus = this.modelOffsetFromDom(focusNode, focusOffset);
    if (anchor === null || focus === null) {
      return null;
    }
    return { start: Math.min(anchor, focus), end: Math.max(anchor, focus) };
  }

  private paragraphContaining(node: Node): Node | null {
    let current: Node = node;
    while (current.parentNode !== this.root) {
      if (current.parentNode === null) {
        return null;
      }
      current = current.parentNode;
    }
    return current;
  }

  private lineStart(paragraph: Node): number {
    const index = paragraphIndex(paragraph);
    const line = this.paragraphs()[index];
    return line?.start ?? 0;
  }

  private documentLength(): number {
    return this.paragraphs().at(-1)?.end ?? 0;
  }
}

// --- Line level: a paragraph div per line, in projection order. ---

function paragraphIndex(paragraph: Node): number {
  let index = 0;
  for (let s = paragraph.previousSibling; s !== null; s = s.previousSibling) {
    index++;
  }
  return index;
}

// --- Run level: spans within one line, nothing between them. ---

function offsetWithinParagraph(
  paragraph: Node,
  node: Node,
  offset: number
): number {
  let position =
    node.nodeType === Node.TEXT_NODE ? offset : childLengthBefore(node, offset);
  for (
    let current = node;
    current !== paragraph;
    current = current.parentNode!
  ) {
    position += siblingLengthBefore(current);
  }
  return position;
}

function positionInParagraph(paragraph: Element, offset: number): DomPosition {
  let remaining = offset;
  for (const child of paragraph.children) {
    // An empty line holds a <br>, not run spans; fall through to the div.
    if (child.nodeName === 'BR') {
      break;
    }
    const length = textLength(child);
    const isLast = child.nextElementSibling === null;
    if (remaining < length || (isLast && remaining === length)) {
      const text = child.firstChild;
      return text === null
        ? { node: child, offset: 0 }
        : { node: text, offset: remaining };
    }
    remaining -= length;
  }
  // An empty line: the caret sits in the div itself, before the <br>.
  return { node: paragraph, offset: 0 };
}

// Total text length of the node's preceding siblings.
function siblingLengthBefore(node: Node): number {
  let length = 0;
  for (let s = node.previousSibling; s !== null; s = s.previousSibling) {
    length += textLength(s);
  }
  return length;
}

// Text length of the first `index` children, for element-addressed positions.
function childLengthBefore(parent: Node, index: number): number {
  let length = 0;
  const children = parent.childNodes;
  const count = Math.min(index, children.length);
  for (let i = 0; i < count; i++) {
    length += textLength(children[i]!);
  }
  return length;
}

function textLength(node: Node): number {
  return (node.textContent ?? '').length;
}
