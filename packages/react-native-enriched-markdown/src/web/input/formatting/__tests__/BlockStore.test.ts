import { BlockStore, paragraphBounds } from '../BlockStore';
import { createBlockRange as block, MAX_LIST_DEPTH } from '../../model/blocks';

// "The world\nis big\n\nend"
//  0-8 line 1 | 10-15 line 2 | 17 line 3 (empty) | 18-20 line 4
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

    expect(store.allRanges).toEqual([block('h2', 0, 9, 2)]);
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
    expect(store.allRanges).toEqual([block('h1', 17, 17, 1)]);

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

  it('adjustForEdit clips a block whose tail the delete eats into', () => {
    store.setRanges([block('h1', 0, 4), block('h2', 5, 9)]);

    store.adjustForEdit(2, 2, 0);

    expect(store.allRanges).toEqual([block('h1', 0, 2), block('h2', 3, 7)]);
  });

  it('a char typed at the line start joins the block once normalized', () => {
    // The insert shifts the range off the line start; normalizeToLineBounds
    // snaps it back over the typed char.
    store.setRanges([block('h2', 0, 5)]); // "Title" on line 1

    store.adjustForEdit(0, 0, 1);
    expect(store.allRanges).toEqual([block('h2', 1, 6)]);

    store.normalizeToLineBounds('XTitle\nbody');
    expect(store.allRanges).toEqual([block('h2', 0, 6)]);
  });

  it('Enter typed at the line start carries the block down with its text', () => {
    // The heading must follow "Title" to line 2 rather than stay behind as an
    // empty anchor on the new line 1 - the reason an insert at the start
    // shifts instead of growing the range.
    store.setRanges([block('h2', 0, 5)]);

    store.adjustForEdit(0, 0, 1);
    store.normalizeToLineBounds('\nTitle\nbody');

    expect(store.allRanges).toEqual([block('h2', 1, 6)]);
  });

  it('adjustForEdit holds an anchor still so typing fills its line', () => {
    // "aaaa\n\nbbbb": a paragraph on line 1, an empty heading anchor on line 2.
    store.setRanges([block('paragraph', 0, 4), block('h2', 5, 5)]);

    store.adjustForEdit(5, 0, 1);
    expect(store.allRanges).toEqual([
      block('paragraph', 0, 4),
      block('h2', 5, 5),
    ]);

    store.normalizeToLineBounds('aaaa\nX\nbbbb');
    expect(store.allRanges).toEqual([
      block('paragraph', 0, 4),
      block('h2', 5, 6),
    ]);
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

  it('normalizeToLineBounds snaps ranges to their full lines', () => {
    // Math left the heading covering only part of line 1 and leaking a char.
    store.setRanges([block('h2', 1, 5, 2)]);

    store.normalizeToLineBounds(text);

    expect(store.allRanges).toEqual([block('h2', 0, 9, 2)]);
  });

  it('normalizeToLineBounds clips a block split by a newline to its first line', () => {
    // An Enter typed inside the heading stretched its range across two lines.
    store.setRanges([block('h1', 0, 14)]);

    store.normalizeToLineBounds(text);

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('normalizeToLineBounds drops the duplicate after a line join', () => {
    // Backspace joined two heading lines: both ranges resolve to line 1.
    store.setRanges([block('h1', 0, 4), block('h2', 5, 9)]);

    store.normalizeToLineBounds(text);

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('normalizeToLineBounds resolves a shared start in favour of the earlier range', () => {
    // Forward-delete on an empty heading line pulls the next line up, so the
    // anchor and the paragraph briefly share a start. The anchor is spliced
    // after the paragraph, so the paragraph wins the dedup and the emptied
    // heading goes away rather than claiming the text it absorbed.
    store.setRanges([block('h2', 0, 0), block('paragraph', 1, 5)]);

    store.adjustForEdit(0, 1, 0);
    expect(store.allRanges).toEqual([
      block('paragraph', 0, 4),
      block('h2', 0, 0),
    ]);

    store.normalizeToLineBounds('bbbb');
    expect(store.allRanges).toEqual([block('paragraph', 0, 4)]);
  });

  it('normalizeToLineBounds keeps anchored empties and drops the rest', () => {
    store.setRanges([block('h1', 17, 17), block('paragraph', 17, 17)]);

    store.normalizeToLineBounds(text);

    expect(store.allRanges).toEqual([block('h1', 17, 17)]);
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
      block('ordered-list-item', 0, 5, 3),
      block('ordered-list-item', 6, 11, 2),
      block('ordered-list-item', 12, 17, 1),
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
      block('ordered-list-item', 0, 5, 0),
      block('ordered-list-item', 6, 11, 1),
      block('ordered-list-item', 12, 17, 0),
      block('ordered-list-item', 18, 23, 1),
    ]);

    // The second depth-1 run starts over at 1.
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 1, 2, 1]);
  });

  it('caps nesting at MAX_LIST_DEPTH however deep the levels ask to go', () => {
    const count = MAX_LIST_DEPTH + 2;
    store.setRanges(
      Array.from({ length: count }, (_, i) =>
        block('unordered-list-item', i * 5, i * 5 + 4, i)
      )
    );

    expect(store.allRanges.map((r) => r.level)).toEqual(
      Array.from({ length: count }, (_, i) => Math.min(i, MAX_LIST_DEPTH))
    );
  });

  it('setBlock renumbers the ordered run it joins', () => {
    store.setRanges([block('ordered-list-item', 0, 9)]);

    store.setBlock('ordered-list-item', 0, 10, 10, text);

    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 2]);
  });

  it('removeBlock renumbers the ordered items left behind', () => {
    // "one\ntwo\nsix": three adjacent lines, one ordered item each.
    const lines = 'one\ntwo\nsix';
    store.setRanges([
      block('ordered-list-item', 0, 3),
      block('ordered-list-item', 4, 7),
      block('ordered-list-item', 8, 11),
    ]);
    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 2, 3]);

    store.removeBlock(1, 1, lines);

    expect(store.allRanges.map((r) => [r.start, r.ordinal])).toEqual([
      [4, 1],
      [8, 2],
    ]);
  });

  it('setRanges sorts incoming blocks by start', () => {
    store.setRanges([block('paragraph', 6, 11), block('h1', 0, 5)]);

    expect(store.allRanges.map((r) => r.start)).toEqual([0, 6]);
  });
});
