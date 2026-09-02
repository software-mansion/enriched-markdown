import type { RangeBounds } from '../model/rangeBounds';

export interface DomPosition {
  node: Node;
  offset: number;
}

// Paragraph divs map to buffer lines, so crossing one costs a newline;
// runs within a line have no separators.
const NEWLINE_LENGTH = '\n'.length;

// Translates DOM positions to buffer offsets and back over the renderer's
// canonical DOM.
// A run-boundary offset maps to the start of the following run.
export class SelectionMapper {
  private readonly root: HTMLElement;

  constructor(root: HTMLElement) {
    this.root = root;
  }

  // Returns null for positions outside the editor.
  modelOffsetFromDom(node: Node, offset: number): number | null {
    if (node === this.root) {
      const paragraph = this.root.childNodes[offset];
      return paragraph === undefined
        ? this.documentLength()
        : paragraphStart(paragraph);
    }

    const paragraph = this.paragraphContaining(node);
    if (paragraph === null) {
      return null;
    }
    return (
      paragraphStart(paragraph) + offsetWithinParagraph(paragraph, node, offset)
    );
  }

  // Offsets past the end clamp to the end of the document.
  domPositionFromModelOffset(offset: number): DomPosition | null {
    const paragraphs = this.root.children;
    if (paragraphs.length === 0) {
      return null;
    }

    let remaining = Math.max(offset, 0);
    for (let i = 0; i < paragraphs.length; i++) {
      const paragraph = paragraphs[i]!;
      const length = textLength(paragraph);
      if (remaining <= length || i === paragraphs.length - 1) {
        return positionInParagraph(paragraph, Math.min(remaining, length));
      }
      remaining -= length + NEWLINE_LENGTH;
    }
    return null;
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

  // n lines hold n - 1 newlines, hence the negative start.
  private documentLength(): number {
    let length = -NEWLINE_LENGTH;
    for (const paragraph of this.root.childNodes) {
      length += textLength(paragraph) + NEWLINE_LENGTH;
    }
    return Math.max(length, 0);
  }
}

// --- Line level: paragraph siblings, a newline per boundary. ---

// Buffer offset at which this paragraph's line starts.
function paragraphStart(paragraph: Node): number {
  let offset = 0;
  for (let s = paragraph.previousSibling; s !== null; s = s.previousSibling) {
    offset += textLength(s) + NEWLINE_LENGTH;
  }
  return offset;
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
