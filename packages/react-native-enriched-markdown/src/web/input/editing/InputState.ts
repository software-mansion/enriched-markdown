import type { BlockStore } from '../formatting/BlockStore';
import type { FormattingStore } from '../formatting/FormattingStore';
import { isHeading } from '../model/blocks';
import type { FormattingRange } from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';
import type { TypingAttributesController } from './TypingAttributesController';

export interface InputState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean; destination: string };
  heading: { isActive: boolean; level: number };
  unorderedList: { isActive: boolean; depth: number };
  orderedList: { isActive: boolean; depth: number };
}

// The link the state describes: the one covering the selection's first
// character, or, for a caret, the one it sits inside or immediately after.
//
// `rangeOfType` is end-exclusive, so a caret at a link's tail - where it ends
// up after typing the link's last character, the most common place for a
// toolbar to ask - finds nothing there and has to look at the position
// before it. Both natives do that retry (`ENRMLinkCoordinator`'s
// `linkForSelection:` falls back to `location - 1`, and Android routes
// through the same call), and without it a shared link toolbar pre-fills on
// native and comes up empty on web.
function linkForSelection(
  formattingStore: FormattingStore,
  selection: RangeBounds
): FormattingRange | null {
  const atStart = formattingStore.rangeOfType('link', selection.start);
  if (atStart !== null || selection.start !== selection.end) {
    return atStart;
  }
  return selection.start === 0
    ? null
    : formattingStore.rangeOfType('link', selection.start - 1);
}

// A style is active over a selection when it covers the whole of it, and at a
// caret when it is effectively active there.
function inlineStates(
  formattingStore: FormattingStore,
  typing: TypingAttributesController,
  selection: RangeBounds
): Pick<
  InputState,
  'bold' | 'italic' | 'underline' | 'strikethrough' | 'spoiler' | 'link'
> {
  const active = (type: Parameters<FormattingStore['isStyleActive']>[0]) =>
    selection.start === selection.end
      ? typing.isEffectiveStyleActive(type, selection.start)
      : formattingStore.isStyleFullyActive(
          type,
          selection.start,
          selection.end
        );
  const link = linkForSelection(formattingStore, selection);
  return {
    bold: { isActive: active('strong') },
    italic: { isActive: active('em') },
    underline: { isActive: active('underline') },
    strikethrough: { isActive: active('strikethrough') },
    spoiler: { isActive: active('spoiler') },
    // A caret reads its link off the same lookup the destination comes from,
    // so the two agree. A selection keeps the whole-coverage rule every other
    // style follows. The destination stays `""` with no link there, which is
    // also what a link with an empty url reports.
    link: {
      isActive:
        selection.start === selection.end ? link !== null : active('link'),
      destination: link?.url ?? '',
    },
  };
}

export function buildInputState(
  formattingStore: FormattingStore,
  blockStore: BlockStore,
  typing: TypingAttributesController,
  selection: RangeBounds,
  text: string
): InputState {
  const block = blockStore.blockAt(selection.start, text);
  const headingLevel = isHeading(block) ? block.level : 0;
  const unordered = block?.type === 'unordered-list-item';
  const ordered = block?.type === 'ordered-list-item';
  return {
    ...inlineStates(formattingStore, typing, selection),
    heading: { isActive: headingLevel > 0, level: headingLevel },
    unorderedList: { isActive: unordered, depth: unordered ? block.level : 0 },
    orderedList: { isActive: ordered, depth: ordered ? block.level : 0 },
  };
}

export function sameInputState(a: InputState, b: InputState): boolean {
  return (
    a.bold.isActive === b.bold.isActive &&
    a.italic.isActive === b.italic.isActive &&
    a.underline.isActive === b.underline.isActive &&
    a.strikethrough.isActive === b.strikethrough.isActive &&
    a.spoiler.isActive === b.spoiler.isActive &&
    a.link.isActive === b.link.isActive &&
    a.link.destination === b.link.destination &&
    a.heading.isActive === b.heading.isActive &&
    a.heading.level === b.heading.level &&
    a.unorderedList.isActive === b.unorderedList.isActive &&
    a.unorderedList.depth === b.unorderedList.depth &&
    a.orderedList.isActive === b.orderedList.isActive &&
    a.orderedList.depth === b.orderedList.depth
  );
}
