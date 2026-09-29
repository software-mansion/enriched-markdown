import type { BlockStore } from '../formatting/BlockStore';
import type { FormattingStore } from '../formatting/FormattingStore';
import { isHeading } from '../model/blocks';
import type { RangeBounds } from '../model/rangeBounds';
import type { TypingAttributesController } from './TypingAttributesController';

export interface InputState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean };
  heading: { isActive: boolean; level: number };
  unorderedList: { isActive: boolean; depth: number };
  orderedList: { isActive: boolean; depth: number };
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
  return {
    bold: { isActive: active('strong') },
    italic: { isActive: active('em') },
    underline: { isActive: active('underline') },
    strikethrough: { isActive: active('strikethrough') },
    spoiler: { isActive: active('spoiler') },
    link: { isActive: active('link') },
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
    a.heading.isActive === b.heading.isActive &&
    a.heading.level === b.heading.level &&
    a.unorderedList.isActive === b.unorderedList.isActive &&
    a.unorderedList.depth === b.unorderedList.depth &&
    a.orderedList.isActive === b.orderedList.isActive &&
    a.orderedList.depth === b.orderedList.depth
  );
}
