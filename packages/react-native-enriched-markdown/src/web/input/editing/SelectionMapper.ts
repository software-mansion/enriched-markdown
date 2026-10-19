import { firstIndexReachingTarget } from '../utils';
import { isDev } from '../../../utils/isDev';

export interface DomPosition {
  node: Node;
  offset: number;
}

// A DOM selection in model offsets, direction kept so a backward selection
// is not flipped on the next write.
export interface ModelSelectionPoints {
  anchor: number;
  focus: number;
}

// The lines as currently rendered. Supplied by the renderer, the only thing
// that keeps lines and nodes in step.
export interface RenderedLines {
  readonly lineCount: number;
  lineStart(index: number): number;
  lineEnd(index: number): number;
  lineElement(index: number): HTMLElement | undefined;
  // -1 for a node that is not a rendered line.
  indexOfLine(node: Node): number;
}

// Whether the DOM selection is a caret. Not `isCollapsed` alone: Cmd+A in an
// empty line selects its `<br>`, which Chrome paints as a range while
// exposing a collapsed one (`type` is 'Range').
export function isCaret(selection: Selection): boolean {
  return selection.isCollapsed && selection.type !== 'Range';
}

const LOG_PREFIX = '[EnrichedMarkdown - SelectionMapper]';

// Reports a DOM that the rendered line offsets do not describe. Every caller
// is a path reachable only once the two have diverged, so production keeps
// its best-effort answer - a wrong caret beats throwing inside a keystroke
// handler - and development gets told, because otherwise users find these
// instead of tests.
function reportDesync(message: string): void {
  if (isDev) {
    console.error(`${LOG_PREFIX} invariant violated: ${message}`);
  }
}

// Translates DOM positions to buffer offsets and back over the renderer's
// lines: one element per line, directly under the root.
//
// Within a line both directions count text, not nodes, so split text nodes,
// element-addressed points and foreign wrappers all map by what the line
// shows. A run-boundary offset maps to the start of the following run.
export class SelectionMapper {
  private readonly root: HTMLElement;
  private readonly lines: RenderedLines;

  constructor(root: HTMLElement, lines: RenderedLines) {
    this.root = root;
    this.lines = lines;
  }

  // Returns null for positions outside the editor, and for DOM the rendered
  // lines do not describe.
  modelOffsetFromDom(node: Node, offset: number): number | null {
    if (node === this.root) {
      return this.offsetOfRootPoint(offset);
    }

    const line = this.lineContaining(node);
    if (line === null) {
      return null;
    }
    const start = this.lines.lineStart(line.index);
    const lineLength = this.lines.lineEnd(line.index) - start;
    const within = textLengthBefore(line.element, node, offset);
    if (within > lineLength) {
      reportDesync(
        `line ${line.index} holds a position ${within} units in, projected length is ${lineLength}`
      );
    }
    return start + Math.min(within, lineLength);
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
    const index = this.lineIndexAt(clamped);
    const element = this.lines.lineElement(index);
    if (element === undefined) {
      reportDesync(`line ${index} of ${count} has no rendered element`);
      return null;
    }
    const start = this.lines.lineStart(index);
    if (clamped < start) {
      reportDesync(
        `offset ${clamped} resolved to line ${index}, which starts at ${start}`
      );
    }
    const within = Math.min(
      Math.max(clamped - start, 0),
      this.lines.lineEnd(index) - start
    );
    return positionInLine(element, within);
  }

  // The rendered line holding model `offset`; an offset at a line's end
  // belongs to that line, and one past the document to the last.
  lineIndexAt(offset: number): number {
    const count = this.lines.lineCount;
    return Math.max(
      Math.min(
        firstIndexReachingTarget(offset, count, (i) => this.lines.lineEnd(i)),
        count - 1
      ),
      0
    );
  }

  modelSelectionFromDom(selection: Selection): ModelSelectionPoints | null {
    const { anchorNode, anchorOffset, focusNode, focusOffset } = selection;
    if (anchorNode === null || focusNode === null) {
      return null;
    }
    const anchor = this.modelOffsetFromDom(anchorNode, anchorOffset);
    if (anchor === null) {
      return null;
    }
    // A caret is the common case on every keystroke; map it once.
    if (anchorNode === focusNode && anchorOffset === focusOffset) {
      return { anchor, focus: anchor };
    }
    const focus = this.modelOffsetFromDom(focusNode, focusOffset);
    return focus === null ? null : { anchor, focus };
  }

  // A child-node index: past the last child is the document end, anything
  // else the start of the line at or after it.
  private offsetOfRootPoint(offset: number): number | null {
    const children = this.root.childNodes;
    if (offset >= children.length) {
      return this.documentLength();
    }
    for (let i = Math.max(offset, 0); i < children.length; i++) {
      const index = this.lines.indexOfLine(children[i]!);
      if (index !== -1) {
        return this.lines.lineStart(index);
      }
    }
    reportDesync(`no rendered line at or after root child ${offset}`);
    return this.documentLength();
  }

  private lineContaining(
    node: Node
  ): { element: Element; index: number } | null {
    let current: Node = node;
    while (current.parentNode !== this.root) {
      if (current.parentNode === null) {
        return null;
      }
      current = current.parentNode;
    }
    const index = this.lines.indexOfLine(current);
    if (index === -1) {
      reportDesync('a node that is not a line sits directly under the root');
      return null;
    }
    return { element: current as Element, index };
  }

  private documentLength(): number {
    return this.lines.lineEnd(this.lines.lineCount - 1);
  }
}

// The length of the text in `container` before the point (`node`, `offset`),
// which lies in it: what `Range.toString()` would count, without a `Range`.
// A live `Range` stays registered on its document until it is collected, and
// every DOM mutation updates each one, so a dropped `Range` per lookup slows
// down later renders. A `TreeWalker` is not live. A `<br>` holds no text, so
// an empty line is 0 throughout.
export function textLengthBefore(
  container: Node,
  node: Node,
  offset: number
): number {
  if (node.nodeType === Node.TEXT_NODE) {
    return (
      textLengthPreceding(container, node) +
      clampIndex(offset, (node as Text).length)
    );
  }
  if (node.nodeType !== Node.ELEMENT_NODE) {
    // A point inside a comment or other non-text character data.
    return textLengthPreceding(container, node);
  }
  const child = node.childNodes[Math.max(offset, 0)];
  return child === undefined
    ? textLengthPreceding(container, node) + (node.textContent ?? '').length
    : textLengthPreceding(container, child);
}

// The length of the text nodes in `container` before `node` in document
// order, not counting `node`'s own subtree.
function textLengthPreceding(container: Node, node: Node): number {
  if (node === container) {
    return 0;
  }
  const walker = container.ownerDocument!.createTreeWalker(
    container,
    NodeFilter.SHOW_TEXT
  );
  walker.currentNode = node;
  let length = 0;
  for (
    let text = walker.previousNode();
    text !== null;
    text = walker.previousNode()
  ) {
    length += (text as Text).length;
  }
  return length;
}

// The DOM position `offset` units into a line; null when the line holds less
// text than projected, rather than a plausible but wrong line start.
function positionInLine(line: Element, offset: number): DomPosition | null {
  const walker = line.ownerDocument.createTreeWalker(
    line,
    NodeFilter.SHOW_TEXT
  );
  let remaining = offset;
  let last: Text | null = null;
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    const text = node as Text;
    if (remaining < text.length) {
      return { node: text, offset: remaining };
    }
    remaining -= text.length;
    if (text.length > 0) {
      last = text;
    }
  }
  if (remaining === 0) {
    // The end of the line: after its last character, or - for an empty line,
    // which holds a <br> and no text - in the line element before the <br>.
    return last === null
      ? { node: line, offset: 0 }
      : { node: last, offset: last.length };
  }
  reportDesync(
    `a line ${offset - remaining} units long was asked for offset ${offset}`
  );
  return null;
}

function clampIndex(index: number, length: number): number {
  return Math.min(Math.max(index, 0), length);
}
