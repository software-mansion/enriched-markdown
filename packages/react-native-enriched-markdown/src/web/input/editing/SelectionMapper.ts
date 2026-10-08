import type { RangeBounds } from '../model/rangeBounds';
import { firstIndexReachingTarget } from '../utils';

export interface DomPosition {
  node: Node;
  offset: number;
}

// The line offsets of the DOM as currently rendered. Supplied by the renderer
// rather than copied here: `render` is the only thing that maintains the
// correspondence between the lines and the nodes, so the copy that matches
// the nodes is the one to index against.
export interface LineOffsets {
  readonly lineCount: number;
  lineBounds(index: number): RangeBounds | undefined;
}

const LOG_PREFIX = '[EnrichedMarkdown - SelectionMapper]';

// Reports a DOM that the rendered line offsets do not describe. Every caller
// is a path reachable only once the two have diverged, so production keeps
// its best-effort answer - a wrong caret beats throwing inside a keystroke
// handler - and development gets told, because otherwise users find these
// instead of tests.
function reportDesync(message: string): void {
  if (__DEV__) {
    console.error(`${LOG_PREFIX} invariant violated: ${message}`);
  }
}

// Translates DOM positions to buffer offsets and back over the renderer's
// canonical DOM: one element child of the root per line, holding run spans or
// a single <br>.
//
// Only element children count, and every traversal here walks elements, which
// is the same index space `DomRenderer` patches through. A foreign node under
// the root therefore costs at most a wrong caret in its own vicinity instead
// of shifting every line after it.
// A run-boundary offset maps to the start of the following run.
export class SelectionMapper {
  private readonly root: HTMLElement;
  private readonly lines: LineOffsets;

  constructor(root: HTMLElement, lines: LineOffsets) {
    this.root = root;
    this.lines = lines;
  }

  // Returns null for positions outside the editor, and for DOM the rendered
  // line offsets do not describe.
  modelOffsetFromDom(node: Node, offset: number): number | null {
    if (node === this.root) {
      // The root addresses a position by child-node index; map it into the
      // element index space the lines live in. An index one past the last
      // line is the legitimate "after everything" position.
      const index = elementIndexOfChildNode(this.root, offset);
      if (index === this.lines.lineCount) {
        return this.documentLength();
      }
      const line = this.lines.lineBounds(index);
      if (line === undefined) {
        reportDesync(
          `the root has no line at element index ${index} of ${this.lines.lineCount}`
        );
        return null;
      }
      return line.start;
    }

    const paragraph = this.paragraphContaining(node);
    if (paragraph === null) {
      return null;
    }
    const index = elementIndex(paragraph);
    const line = this.lines.lineBounds(index);
    if (line === undefined) {
      reportDesync(
        `line ${index} is rendered but not projected (${this.lines.lineCount} lines)`
      );
      return null;
    }
    const within = offsetWithinParagraph(paragraph, node, offset);
    const lineLength = line.end - line.start;
    if (within > lineLength) {
      reportDesync(
        `line ${index} holds a position ${within} units in, projected length is ${lineLength}`
      );
    }
    return line.start + Math.min(within, lineLength);
  }

  // Offsets past the end clamp to the end of the document; that is the
  // documented contract, since a caret parked at the end outlives the text it
  // was parked after.
  domPositionFromModelOffset(offset: number): DomPosition | null {
    const count = this.lines.lineCount;
    if (count === 0) {
      // `split('\n')` always yields a line, so an empty projection means
      // nothing has been rendered yet.
      reportDesync('the rendered projection has no lines');
      return null;
    }
    if (offset < 0) {
      reportDesync(`asked for a negative offset (${offset})`);
    }
    const clamped = Math.max(offset, 0);
    const index = Math.min(
      firstIndexReachingTarget(
        clamped,
        count,
        (i) => this.lines.lineBounds(i)?.end ?? 0
      ),
      count - 1
    );
    const element = this.root.children[index];
    const line = this.lines.lineBounds(index);
    if (element === undefined || line === undefined) {
      reportDesync(`line ${index} of ${count} has no rendered element`);
      return null;
    }
    if (clamped < line.start) {
      reportDesync(
        `offset ${clamped} resolved to line ${index}, which starts at ${line.start}`
      );
    }
    const within = Math.min(
      Math.max(clamped - line.start, 0),
      line.end - line.start
    );
    return positionInParagraph(element, within);
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

  private paragraphContaining(node: Node): Element | null {
    let current: Node = node;
    while (current.parentNode !== this.root) {
      if (current.parentNode === null) {
        return null;
      }
      current = current.parentNode;
    }
    if (!isElement(current)) {
      reportDesync('a node that is not a line sits directly under the root');
      return null;
    }
    return current;
  }

  private documentLength(): number {
    return this.lines.lineBounds(this.lines.lineCount - 1)?.end ?? 0;
  }
}

// --- Line level: one element child of the root per line, in projection
// order. ---

function elementIndex(element: Element): number {
  let index = 0;
  for (
    let sibling = element.previousElementSibling;
    sibling !== null;
    sibling = sibling.previousElementSibling
  ) {
    index++;
  }
  return index;
}

// A position inside an element is addressed by child-node index, while the
// lines correspond to element children only. Counting the elements among the
// preceding child nodes converts one to the other.
function elementIndexOfChildNode(
  parent: Element,
  childNodeIndex: number
): number {
  const children = parent.childNodes;
  const count = clampIndex(childNodeIndex, children.length);
  let index = 0;
  for (let i = 0; i < count; i++) {
    if (isElement(children[i]!)) {
      index++;
    }
  }
  return index;
}

// --- Run level: spans within one line, nothing else. ---

function offsetWithinParagraph(
  paragraph: Element,
  node: Node,
  offset: number
): number {
  let position = isTextNode(node)
    ? Math.min(Math.max(offset, 0), textLength(node))
    : runLengthBeforeChild(node, offset);
  for (let current: Node = node; current !== paragraph; ) {
    position += runLengthBeforeSibling(current);
    const parent = current.parentNode;
    if (parent === null) {
      // `paragraphContaining` already proved the ancestry.
      return position;
    }
    current = parent;
  }
  return position;
}

// Walks a line's run spans to the DOM position `offset` units in. Returns
// null when the line's DOM holds less text than the projection claims, rather
// than the plausible-looking line start: a line-start answer reads as a real
// position to every caller, and the caret belongs where the text is.
function positionInParagraph(
  paragraph: Element,
  offset: number
): DomPosition | null {
  const runs = runSpans(paragraph);
  if (runs.length === 0) {
    // An empty line holds a <br>, not run spans: the caret sits in the line
    // element itself, before the <br>. A line with no runs that is asked for
    // a position inside text is a line whose spans went missing.
    if (offset > 0) {
      reportDesync(`a line with no run spans was asked for offset ${offset}`);
      return null;
    }
    return { node: paragraph, offset: 0 };
  }
  let remaining = offset;
  for (let i = 0; i < runs.length; i++) {
    const run = runs[i]!;
    const length = textLength(run);
    const isLast = i === runs.length - 1;
    if (remaining < length || (isLast && remaining === length)) {
      const text = run.firstChild;
      return text === null
        ? { node: run, offset: 0 }
        : { node: text, offset: remaining };
    }
    remaining -= length;
  }
  reportDesync(
    `a line ${offset - remaining} units long was asked for offset ${offset}`
  );
  return null;
}

// The run spans of a rendered line: its element children except a <br>, which
// carries no projected text whether it belongs to an empty line or the
// browser left it behind.
function runSpans(paragraph: Element): Element[] {
  return [...paragraph.children].filter((child) => !isLineBreak(child));
}

// Total text length of the run spans before `node` among its siblings.
function runLengthBeforeSibling(node: Node): number {
  let length = 0;
  for (
    let sibling = node.previousSibling;
    sibling !== null;
    sibling = sibling.previousSibling
  ) {
    if (isRunSpan(sibling)) {
      length += textLength(sibling);
    }
  }
  return length;
}

// Total text length of the run spans among the first `index` child nodes, for
// an element-addressed position.
function runLengthBeforeChild(parent: Node, index: number): number {
  const children = parent.childNodes;
  const count = clampIndex(index, children.length);
  let length = 0;
  for (let i = 0; i < count; i++) {
    const child = children[i]!;
    if (isRunSpan(child)) {
      length += textLength(child);
    }
  }
  return length;
}

function isRunSpan(node: Node): boolean {
  return isElement(node) && !isLineBreak(node);
}

function isLineBreak(node: Node): boolean {
  return node.nodeName === 'BR';
}

function isElement(node: Node): node is Element {
  return node.nodeType === Node.ELEMENT_NODE;
}

function isTextNode(node: Node): boolean {
  return node.nodeType === Node.TEXT_NODE;
}

function clampIndex(index: number, length: number): number {
  return Math.min(Math.max(index, 0), length);
}

function textLength(node: Node): number {
  return (node.textContent ?? '').length;
}
