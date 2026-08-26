import { BlockStore, paragraphBounds } from '../BlockStore';
import { createBlockRange as block } from '../../model/blocks';

// "The world\nis big\n\nend"
//  0-8 line 1 | 10-15 line 2 | 17 empty | 18-20 line 3
const text = 'The world\nis big\n\nend';

describe('paragraphBounds', () => {
  it('expands a position inside a line to the whole line', () => {
    expect(paragraphBounds(4, 4, text)).toEqual({ start: 0, end: 9 });
    expect(paragraphBounds(12, 14, text)).toEqual({ start: 10, end: 16 });
  });

  it('expands a selection spanning lines to both line bounds', () => {
    expect(paragraphBounds(4, 12, text)).toEqual({ start: 0, end: 16 });
  });

  it('keeps line terminators outside the bounds', () => {
    // A selection ending on the newline still resolves to line 1 only —
    // the terminator belongs to no line.
    expect(paragraphBounds(0, 9, text)).toEqual({ start: 0, end: 9 });
  });

  it('resolves an empty line to a zero-length range', () => {
    expect(paragraphBounds(17, 17, text)).toEqual({ start: 17, end: 17 });
  });

  it('clamps out-of-range positions and handles empty text', () => {
    expect(paragraphBounds(-5, 999, text)).toEqual({ start: 0, end: 21 });
    expect(paragraphBounds(3, 3, '')).toEqual({ start: 0, end: 0 });
  });
});

describe('BlockStore', () => {
  let store: BlockStore;

  beforeEach(() => {
    store = new BlockStore();
  });

  it('blockStartingAt finds the block by its exact line start', () => {
    store.setRanges([
      block('h1', 0, 5),
      block('paragraph', 6, 11),
      block('unordered-list-item', 12, 17),
    ]);

    expect(store.blockStartingAt(6)).toEqual(block('paragraph', 6, 11));
    expect(store.blockStartingAt(12)).toEqual(
      block('unordered-list-item', 12, 17)
    );
    // Positions inside a line do not match — only exact starts do.
    expect(store.blockStartingAt(7)).toBeNull();
    expect(store.blockStartingAt(99)).toBeNull();
  });

  it('setBlock claims the whole line from a caret position', () => {
    store.setBlock('h2', 2, 4, 4, text);

    expect(store.allRanges).toEqual([{ ...block('h2', 0, 9), level: 2 }]);
  });

  it('setBlock replaces whatever block covered those lines', () => {
    store.setRanges([block('h1', 0, 9), block('unordered-list-item', 10, 16)]);

    store.setBlock('ordered-list-item', 0, 12, 12, text);

    expect(store.allRanges).toEqual([
      block('h1', 0, 9),
      block('ordered-list-item', 10, 16),
    ]);
  });

  it('setBlock on an empty line creates an anchor only for anchored types', () => {
    store.setBlock('h1', 1, 17, 17, text);
    expect(store.allRanges).toEqual([{ ...block('h1', 17, 17), level: 1 }]);

    store.clearAll();
    store.setBlock('paragraph', 0, 17, 17, text);
    expect(store.allRanges).toEqual([]);
  });

  it('removeBlock clears blocks on every touched line, leaving neighbors', () => {
    store.setRanges([
      block('h1', 0, 9),
      block('unordered-list-item', 10, 16),
      block('h2', 18, 21),
    ]);

    // Caret in the middle of line 1 represents the whole line.
    store.removeBlock(4, 4, text);

    expect(store.allRanges).toEqual([
      block('unordered-list-item', 10, 16),
      block('h2', 18, 21),
    ]);
  });

  it('removeBlock clears a zero-length anchor on an empty line', () => {
    // Toggle-off on an empty heading: only the anchor exists there.
    store.setRanges([block('h1', 0, 9), block('h2', 17, 17)]);

    store.removeBlock(17, 17, text);

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('adjustForEdit grows the edited block and shifts the following ones', () => {
    store.setRanges([block('h2', 0, 6), block('ordered-list-item', 7, 12)]);

    // Two chars typed inside the heading.
    store.adjustForEdit(3, 0, 2);

    expect(store.allRanges).toEqual([
      block('h2', 0, 8),
      block('ordered-list-item', 9, 14),
    ]);
  });

  it('adjustForEdit absorbs a char typed at the line start into its block', () => {
    store.setRanges([block('h2', 0, 6)]);

    store.adjustForEdit(0, 0, 1);

    expect(store.allRanges).toEqual([block('h2', 0, 7)]);
  });

  it('adjustForEdit keeps the block through a replacement of its content', () => {
    // Autocorrect swaps the whole heading text for a same-length word.
    store.setRanges([block('h2', 0, 6)]);

    store.adjustForEdit(0, 6, 6);

    expect(store.allRanges).toEqual([block('h2', 0, 6)]);
  });

  it('adjustForEdit collapses a block emptied exactly to its end into an anchor', () => {
    store.setRanges([block('h2', 0, 6), block('ordered-list-item', 7, 12)]);

    // The whole list item content deleted; its line (the newline) survives.
    store.adjustForEdit(7, 5, 0);

    expect(store.allRanges).toEqual([
      block('h2', 0, 6),
      block('ordered-list-item', 7, 7),
    ]);
  });

  it('adjustForEdit keeps, shifts or drops anchors around the edit', () => {
    store.setRanges([
      block('h1', 0, 0),
      block('unordered-list-item', 10, 10),
      block('ordered-list-item', 20, 20),
    ]);

    // Replace chars 8-15 with two chars (delta -5).
    store.adjustForEdit(8, 7, 2);

    expect(store.allRanges).toEqual([
      block('h1', 0, 0),
      block('ordered-list-item', 15, 15),
    ]);
  });

  it('numbers adjacent ordered items and restarts after a gap', () => {
    // Lines are adjacent when the next start is prevEnd + 1 (the newline).
    store.setRanges([
      block('ordered-list-item', 0, 5),
      block('ordered-list-item', 6, 11),
      block('ordered-list-item', 13, 18), // gap: not adjacent
    ]);

    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 2, 1]);
  });

  it('clamps depths to one level below the previous adjacent item', () => {
    store.setRanges([
      { ...block('ordered-list-item', 0, 5), level: 3 },
      { ...block('ordered-list-item', 6, 11), level: 2 },
      { ...block('ordered-list-item', 12, 17), level: 1 },
    ]);

    expect(store.allRanges.map((r) => r.level)).toEqual([0, 1, 1]);
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 1, 2]);
  });

  it('restarts numbering on list-type change and after a non-list block', () => {
    store.setRanges([
      block('ordered-list-item', 0, 5),
      block('unordered-list-item', 6, 11),
      block('unordered-list-item', 12, 17),
      block('ordered-list-item', 18, 23),
    ]);
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 1, 2, 1]);

    store.setRanges([
      block('ordered-list-item', 0, 5),
      block('h1', 6, 11),
      block('ordered-list-item', 12, 17),
    ]);
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 1, 1]);
  });

  it('resets deeper counters when the list returns to a shallower depth', () => {
    store.setRanges([
      { ...block('ordered-list-item', 0, 5), level: 0 },
      { ...block('ordered-list-item', 6, 11), level: 1 },
      { ...block('ordered-list-item', 12, 17), level: 0 },
      { ...block('ordered-list-item', 18, 23), level: 1 },
    ]);

    // The second depth-1 run starts over at 1.
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 1, 2, 1]);
  });

  it('setRanges sorts incoming blocks by start', () => {
    store.setRanges([block('paragraph', 6, 11), block('h1', 0, 5)]);

    expect(store.allRanges.map((r) => r.start)).toEqual([0, 6]);
  });
});
