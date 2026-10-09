import {
  buildInputState,
  sameInputState,
  type InputState,
} from '../InputState';
import { TypingAttributesController } from '../TypingAttributesController';
import { BlockStore } from '../../formatting/BlockStore';
import { FormattingStore } from '../../formatting/FormattingStore';
import { createBlockRange as block } from '../../model/blocks';
import { createFormattingRange as range } from '../../model/inlineStyles';

// "stack\nreview\nmerge": 0-5 | 6-12 | 13-18
const text = 'stack\nreview\nmerge';

function build(
  setup: {
    styles?: ReturnType<typeof range>[];
    blocks?: ReturnType<typeof block>[];
    toggle?: { type: 'strong'; wasActive: boolean };
  },
  selection: { start: number; end: number }
): InputState {
  const formatting = new FormattingStore();
  formatting.setRanges(setup.styles ?? []);
  const blocks = new BlockStore();
  blocks.setRanges(setup.blocks ?? []);
  const typing = new TypingAttributesController(formatting);
  if (setup.toggle) {
    typing.toggleStyle(setup.toggle.type, setup.toggle.wasActive, false);
  }
  return buildInputState(formatting, blocks, typing, selection, text);
}

describe('buildInputState', () => {
  it('reports an inline style covering the whole selection', () => {
    const state = build(
      { styles: [range('strong', 0, 5)] },
      { start: 1, end: 4 }
    );

    expect(state.bold.isActive).toBe(true);
  });

  // Matching the natives: a toolbar shows bold on only when every selected
  // character is bold, so a partial run reads as off.
  it('reports an inline style covering only part of the selection as off', () => {
    const state = build(
      { styles: [range('strong', 0, 3)] },
      { start: 1, end: 5 }
    );

    expect(state.bold.isActive).toBe(false);
  });

  it('reads a caret through the pending typing attributes', () => {
    const pendingOn = build(
      { toggle: { type: 'strong', wasActive: false } },
      { start: 2, end: 2 }
    );
    expect(pendingOn.bold.isActive).toBe(true);

    const pendingOff = build(
      {
        styles: [range('strong', 0, 5)],
        toggle: { type: 'strong', wasActive: true },
      },
      { start: 2, end: 2 }
    );
    expect(pendingOff.bold.isActive).toBe(false);
  });

  it('reads a selection from the store, ignoring pending attributes', () => {
    const state = build(
      { toggle: { type: 'strong', wasActive: false } },
      { start: 1, end: 4 }
    );

    expect(state.bold.isActive).toBe(false);
  });

  it('reports every inline style it carries', () => {
    const state = build(
      {
        styles: [
          range('em', 0, 5),
          range('underline', 0, 5),
          range('strikethrough', 0, 5),
          range('spoiler', 0, 5),
          range('link', 0, 5),
        ],
      },
      { start: 1, end: 4 }
    );

    expect([
      state.italic.isActive,
      state.underline.isActive,
      state.strikethrough.isActive,
      state.spoiler.isActive,
      state.link.isActive,
    ]).toEqual([true, true, true, true, true]);
  });

  it('reports the heading level on the line', () => {
    const state = build(
      { blocks: [block('h3', 0, 5, 3)] },
      { start: 2, end: 2 }
    );

    expect(state.heading).toEqual({ isActive: true, level: 3 });
  });

  it('reports no heading on a plain line', () => {
    const state = build({}, { start: 2, end: 2 });

    expect(state.heading).toEqual({ isActive: false, level: 0 });
  });

  it('reports the list type and depth on the line', () => {
    const unordered = build(
      { blocks: [block('unordered-list-item', 0, 5, 0)] },
      { start: 2, end: 2 }
    );
    expect(unordered.unorderedList).toEqual({ isActive: true, depth: 0 });
    expect(unordered.orderedList).toEqual({ isActive: false, depth: 0 });

    const ordered = build(
      {
        blocks: [
          block('ordered-list-item', 0, 5, 0),
          block('ordered-list-item', 6, 12, 1),
        ],
      },
      { start: 8, end: 8 }
    );
    expect(ordered.orderedList).toEqual({ isActive: true, depth: 1 });
    expect(ordered.unorderedList).toEqual({ isActive: false, depth: 0 });
  });

  // The block state follows the line the selection starts on, the same line
  // every block command decides from.
  it('takes the block from the line the selection starts on', () => {
    const state = build(
      { blocks: [block('h1', 0, 5, 1), block('h2', 6, 12, 2)] },
      { start: 2, end: 8 }
    );

    expect(state.heading.level).toBe(1);
  });
});

describe('sameInputState', () => {
  const base = build({}, { start: 0, end: 0 });

  it('holds for two states built the same way', () => {
    expect(sameInputState(base, build({}, { start: 0, end: 0 }))).toBe(true);
  });

  // `sameInputState` is a hand-written field-by-field comparison and it gates
  // `onChangeState`. A field added to `InputState` but left out of it would
  // make the event stop firing whenever only that field changes, silently.
  // This walks the state it is given, so a new field is covered on arrival.
  it('compares every field the state carries', () => {
    const groups = Object.entries(base) as [
      string,
      Record<string, boolean | number>,
    ][];
    for (const [group, values] of groups) {
      for (const [field, value] of Object.entries(values)) {
        const changed = {
          ...base,
          [group]: {
            ...values,
            [field]: typeof value === 'boolean' ? !value : value + 1,
          },
        };

        expect({
          group,
          field,
          same: sameInputState(base, changed as InputState),
        }).toEqual({ group, field, same: false });
      }
    }
  });
});
