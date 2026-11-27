import {
  BlockStore,
  lineAtPosition,
  type LineBlock,
  linesTouching,
  paragraphBounds,
} from '../BlockStore';
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

  it('does not treat a leading newline as the end of a line before position 0', () => {
    expect(paragraphBounds(0, 0, '\nab')).toEqual({ start: 0, end: 0 });
    expect(paragraphBounds(1, 1, '\nab')).toEqual({ start: 1, end: 3 });
  });

  it('resolves positions between consecutive newlines to their empty lines', () => {
    // 'a\n\n\nb': position 1 ends line "a"; 2 and 3 are the empty lines.
    expect(paragraphBounds(1, 1, 'a\n\n\nb')).toEqual({ start: 0, end: 1 });
    expect(paragraphBounds(2, 2, 'a\n\n\nb')).toEqual({ start: 2, end: 2 });
    expect(paragraphBounds(3, 3, 'a\n\n\nb')).toEqual({ start: 3, end: 3 });
  });

  it('resolves the end of text after a trailing newline to the empty last line', () => {
    expect(paragraphBounds(3, 3, 'ab\n')).toEqual({ start: 3, end: 3 });
  });
});

describe('lineAtPosition', () => {
  it('resolves a position to the line holding it', () => {
    expect(lineAtPosition(4, text)).toEqual({ start: 0, end: 9 });
    expect(lineAtPosition(12, text)).toEqual({ start: 10, end: 16 });
  });

  it('resolves a line start and a line end to the same line', () => {
    expect(lineAtPosition(10, text)).toEqual({ start: 10, end: 16 });
    expect(lineAtPosition(16, text)).toEqual({ start: 10, end: 16 });
  });
});

describe('linesTouching', () => {
  it('returns the one line a caret sits on', () => {
    expect(linesTouching({ start: 4, end: 4 }, text)).toEqual([
      { start: 0, end: 9 },
    ]);
  });

  it('returns every line a selection spans, including an empty one', () => {
    expect(linesTouching({ start: 4, end: 19 }, text)).toEqual([
      { start: 0, end: 9 },
      { start: 10, end: 16 },
      { start: 17, end: 17 },
      { start: 18, end: 21 },
    ]);
  });

  // The terminator belongs to no line, so a selection stopping on it must not
  // drag in the line it separates - otherwise every command run from the end
  // of a line would also hit the next one.
  it('stops at a selection ending on a newline', () => {
    expect(linesTouching({ start: 0, end: 9 }, text)).toEqual([
      { start: 0, end: 9 },
    ]);
  });

  // Chrome's triple-click on a line selects through the next line's start;
  // nothing of that line is selected, so a block command must not reach it.
  it('leaves out the line a selection ends at the start of', () => {
    expect(linesTouching({ start: 0, end: 10 }, text)).toEqual([
      { start: 0, end: 9 },
    ]);
    expect(linesTouching({ start: 4, end: 17 }, text)).toEqual([
      { start: 0, end: 9 },
      { start: 10, end: 16 },
    ]);
  });

  it('keeps the line of a selection holding only a line break', () => {
    expect(linesTouching({ start: 9, end: 10 }, text)).toEqual([
      { start: 0, end: 9 },
    ]);
  });

  it('walks on from a selection starting on a newline', () => {
    expect(linesTouching({ start: 9, end: 12 }, text)).toEqual([
      { start: 0, end: 9 },
      { start: 10, end: 16 },
    ]);
  });

  it('returns the single empty line a caret sits on', () => {
    expect(linesTouching({ start: 17, end: 17 }, text)).toEqual([
      { start: 17, end: 17 },
    ]);
  });

  it('terminates on a trailing newline rather than running past the text', () => {
    expect(linesTouching({ start: 0, end: 4 }, 'ab\n')).toEqual([
      { start: 0, end: 2 },
      { start: 3, end: 3 },
    ]);
  });

  it('returns one line for empty text', () => {
    expect(linesTouching({ start: 0, end: 0 }, '')).toEqual([
      { start: 0, end: 0 },
    ]);
  });
});

describe('BlockStore', () => {
  let store: BlockStore;

  beforeEach(() => {
    store = new BlockStore();
  });

  // The empty-editor check: a zero-length anchor on an empty line still
  // counts, so the placeholder does not cover its marker.
  it('isEmpty is false while any block, even an anchor, remains', () => {
    expect(store.isEmpty).toBe(true);

    store.setRanges([block('unordered-list-item', 0, 0)]);
    expect(store.isEmpty).toBe(false);

    store.clearAll();
    expect(store.isEmpty).toBe(true);
  });

  it('blockAt finds the block from any position on its line', () => {
    store.setRanges([block('h1', 0, 9), block('unordered-list-item', 10, 16)]);

    expect(store.blockAt(4, text)?.type).toBe('h1');
    expect(store.blockAt(9, text)?.type).toBe('h1');
    expect(store.blockAt(14, text)?.type).toBe('unordered-list-item');
  });

  it('blockAt returns null on a line no block covers', () => {
    store.setRanges([block('h1', 0, 9)]);

    expect(store.blockAt(19, text)).toBeNull();
  });

  it('blockAt finds an anchor on an empty line and the block at the end of text', () => {
    store.setRanges([
      block('unordered-list-item', 17, 17),
      block('h2', 18, 21),
    ]);

    expect(store.blockAt(17, text)?.type).toBe('unordered-list-item');
    expect(store.blockAt(21, text)?.type).toBe('h2');
    expect(store.blockAt(999, text)?.type).toBe('h2');
  });

  it('blockAt at position 0 ignores a leading newline', () => {
    store.setRanges([block('h1', 0, 0), block('h2', 1, 3)]);

    expect(store.blockAt(0, '\nab')?.type).toBe('h1');
    expect(store.blockAt(-3, '\nab')?.type).toBe('h1');
    expect(store.blockAt(1, '\nab')?.type).toBe('h2');
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
    store.edit(text, (w) => w.setBlock('h2', 2, 4, 4));

    expect(store.allRanges).toEqual([block('h2', 0, 9, 2)]);
  });

  it('setBlock replaces whatever block covered those lines', () => {
    store.setRanges([block('h1', 0, 9), block('unordered-list-item', 10, 16)]);

    store.edit(text, (w) => w.setBlock('ordered-list-item', 0, 12, 12));

    expect(store.allRanges).toEqual([
      block('h1', 0, 9),
      block('ordered-list-item', 10, 16),
    ]);
  });

  it('setBlock on an empty line creates an anchor only for anchored types', () => {
    store.edit(text, (w) => w.setBlock('h1', 1, 17, 17));
    expect(store.allRanges).toEqual([block('h1', 17, 17, 1)]);

    store.clearAll();
    store.edit(text, (w) => w.setBlock('paragraph', 0, 17, 17));
    expect(store.allRanges).toEqual([]);
  });

  it('removeBlock clears blocks on every touched line, leaving neighbors', () => {
    store.setRanges([
      block('h1', 0, 9),
      block('unordered-list-item', 10, 16),
      block('h2', 18, 21),
    ]);

    // Caret in the middle of line 1 represents the whole line.
    store.edit(text, (w) => w.removeBlock(4, 4));

    expect(store.allRanges).toEqual([
      block('unordered-list-item', 10, 16),
      block('h2', 18, 21),
    ]);
  });

  it('removeBlock clears a zero-length anchor on an empty line', () => {
    // Toggle-off on an empty heading: only the anchor exists there.
    store.setRanges([block('h1', 0, 9), block('h2', 17, 17)]);

    store.edit(text, (w) => w.removeBlock(17, 17));

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('removeBlock leaves the anchors on the empty lines around its line', () => {
    // "a\n\nb\n\nc": 0-1 | 2 (empty) | 3-4 | 5 (empty) | 6-7
    const lines = 'a\n\nb\n\nc';
    store.setRanges([
      block('h1', 0, 1, 1),
      block('h2', 2, 2, 2),
      block('h1', 3, 4, 1),
      block('h2', 5, 5, 2),
      block('h1', 6, 7, 1),
    ]);

    store.edit(lines, (w) => w.removeBlock(3, 3));
    expect(store.allRanges).toEqual([
      block('h1', 0, 1, 1),
      block('h2', 2, 2, 2),
      block('h2', 5, 5, 2),
      block('h1', 6, 7, 1),
    ]);

    store.edit(lines, (w) => w.removeBlock(2, 2));
    expect(store.allRanges).toEqual([
      block('h1', 0, 1, 1),
      block('h2', 5, 5, 2),
      block('h1', 6, 7, 1),
    ]);
  });

  // Mid-edit, before the normalize: Enter continuing a list writes the fresh
  // line while the split item still spans the newline.
  it('setBlock replaces a block still reaching in from the line above', () => {
    store.setRanges([block('unordered-list-item', 0, 4)]);

    store.edit('ab\ncd', (w) => w.setBlock('h1', 1, 3, 3));

    expect(store.allRanges).toEqual([block('h1', 3, 5, 1)]);
  });

  it('adjustForEdit grows the edited block and shifts the following ones', () => {
    // "Title1\nitem2", two chars typed inside the heading.
    store.setRanges([block('h2', 0, 6), block('ordered-list-item', 7, 12)]);

    store.edit('TitXXle1\nitem2', (w) => w.adjustForEdit(3, 0, 2));

    expect(store.allRanges).toEqual([
      block('h2', 0, 8),
      block('ordered-list-item', 9, 14),
    ]);
  });

  it('adjustForEdit clips a block whose tail the delete eats into', () => {
    // "abcd\nefgh" -> "ab\nefgh"
    store.setRanges([block('h1', 0, 4), block('h2', 5, 9)]);

    store.edit('ab\nefgh', (w) => w.adjustForEdit(2, 2, 0));

    expect(store.allRanges).toEqual([block('h1', 0, 2), block('h2', 3, 7)]);
  });

  it('a char typed at the line start joins the block once normalized', () => {
    // The insert shifts the range off the line start; the normalize at the
    // end of `edit` snaps it back over the typed char.
    store.setRanges([block('h2', 0, 5)]); // "Title" on line 1

    store.edit('XTitle\nbody', (w) => w.adjustForEdit(0, 0, 1));

    expect(store.allRanges).toEqual([block('h2', 0, 6)]);
  });

  it('Enter typed at the line start carries the block down with its text', () => {
    // The heading must follow "Title" to line 2 rather than stay behind as an
    // empty anchor on the new line 1 - the reason an insert at the start
    // shifts instead of growing the range.
    store.setRanges([block('h2', 0, 5)]);

    store.edit('\nTitle\nbody', (w) => w.adjustForEdit(0, 0, 1));

    expect(store.allRanges).toEqual([block('h2', 1, 6)]);
  });

  it('adjustForEdit holds an anchor still so typing fills its line', () => {
    // "aaaa\n\nbbbb": a paragraph on line 1, an empty heading anchor on line 2.
    store.setRanges([block('paragraph', 0, 4), block('h2', 5, 5)]);

    store.edit('aaaa\nX\nbbbb', (w) => w.adjustForEdit(5, 0, 1));

    expect(store.allRanges).toEqual([
      block('paragraph', 0, 4),
      block('h2', 5, 6),
    ]);
  });

  it('adjustForEdit keeps the block through a replacement of its content', () => {
    // Autocorrect swaps the whole heading text for a same-length word.
    store.setRanges([block('h2', 0, 6)]);

    store.edit('Header', (w) => w.adjustForEdit(0, 6, 6));

    expect(store.allRanges).toEqual([block('h2', 0, 6)]);
  });

  it('adjustForEdit collapses a block emptied exactly to its end into an anchor', () => {
    store.setRanges([block('h2', 0, 6), block('ordered-list-item', 7, 12)]);

    // "Title1\nitem2": the whole list item content deleted; its line (the
    // newline) survives.
    store.edit('Title1\n', (w) => w.adjustForEdit(7, 5, 0));

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

    // "\naaaaaaaa\n\nbbbbbbbb\n": empty lines at 0, 10 and 20. Replace chars
    // 8-15 with two chars (delta -5), deleting the line at 10.
    store.edit('\naaaaaaaXYbbbb\n', (w) => w.adjustForEdit(8, 7, 2));

    expect(store.allRanges).toEqual([
      block('h1', 0, 0),
      block('ordered-list-item', 15, 15),
    ]);
  });

  it('edit normalizes: snaps ranges to their full lines', () => {
    // Math left the heading covering only part of line 1 and leaking a char.
    store.setRanges([block('h2', 1, 5, 2)]);

    store.edit(text, () => {});

    expect(store.allRanges).toEqual([block('h2', 0, 9, 2)]);
  });

  it('edit normalizes: clips a block split by a newline to its first line', () => {
    // An Enter typed inside the heading stretched its range across two lines.
    store.setRanges([block('h1', 0, 14)]);

    store.edit(text, () => {});

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('edit normalizes: drops the duplicate after a line join', () => {
    // Backspace joined two heading lines: both ranges resolve to line 1.
    store.setRanges([block('h1', 0, 4), block('h2', 5, 9)]);

    store.edit(text, () => {});

    expect(store.allRanges).toEqual([block('h1', 0, 9)]);
  });

  it('edit normalizes: resolves a shared start in favour of the earlier range', () => {
    // Forward-delete on an empty heading line pulls the next line up, so the
    // anchor and the paragraph briefly share a start. The anchor is spliced
    // after the paragraph, so the paragraph wins the dedup and the emptied
    // heading goes away rather than claiming the text it absorbed.
    store.setRanges([block('h2', 0, 0), block('paragraph', 1, 5)]);

    store.edit('bbbb', (w) => w.adjustForEdit(0, 1, 0));

    expect(store.allRanges).toEqual([block('paragraph', 0, 4)]);
  });

  it('edit normalizes: keeps anchored empties and drops the rest', () => {
    store.setRanges([block('h1', 17, 17), block('paragraph', 17, 17)]);

    store.edit(text, () => {});

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

    store.edit(text, (w) => w.setBlock('ordered-list-item', 0, 10, 10));

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

    store.edit(lines, (w) => w.removeBlock(1, 1));

    expect(store.allRanges.map((r) => [r.start, r.ordinal])).toEqual([
      [4, 1],
      [8, 2],
    ]);
  });

  // The ancestry clamp overwrites `level`, so a pass over a chain with a hole
  // in it is destructive: the depth it flattens cannot be recovered once the
  // hole is filled. `edit` runs it only once every write is in, so the order
  // of the writes cannot decide the result.
  it('edit gives the same result whichever order the lines are written in', () => {
    // "a\nb" nested, then Enter at the end of line 1 opens a hole at the fresh
    // line - the state the edit pipeline hands to a continuation.
    const held = 'a\n\nb';
    const build = (freshLineFirst: boolean) => {
      const subject = new BlockStore();
      subject.setRanges([
        block('unordered-list-item', 0, 1, 0),
        block('unordered-list-item', 2, 3, 1),
      ]);
      subject.edit(held, (w) => {
        w.adjustForEdit(1, 0, 1);
        const writes = [
          () => w.setBlock('unordered-list-item', 0, 0, 0),
          () => w.setBlock('unordered-list-item', 0, 2, 2),
        ];
        for (const write of freshLineFirst ? writes.reverse() : writes) {
          write();
        }
      });
      return subject.allRanges.map((r) => [r.start, r.level]);
    };

    expect(build(true)).toEqual(build(false));
    expect(build(false)).toEqual([
      [0, 0],
      [2, 0],
      [3, 1],
    ]);
  });

  it('edit renumbers once all writes are in', () => {
    // "a\nb\nc": 0-1 | 2-3 | 4-5
    store.edit('a\nb\nc', (w) => {
      w.setBlock('ordered-list-item', 0, 0, 0);
      w.setBlock('ordered-list-item', 0, 2, 2);
      w.setBlock('ordered-list-item', 0, 4, 4);
    });

    expect(store.allRanges.map((r) => r.ordinal)).toEqual([1, 2, 3]);
  });

  it('pruneOrphanedAnchors drops anchored blocks left mid-line and keeps line starts', () => {
    // "ab\ncd": a heading merged into line 1 at 1, a list item at text start
    // and one right after the newline.
    store.setRanges([
      block('unordered-list-item', 0, 1),
      block('h1', 1, 2),
      block('ordered-list-item', 3, 5),
    ]);

    store.edit('ab\ncd', (w) => w.pruneOrphanedAnchors());

    expect(store.allRanges.map((r) => [r.type, r.start])).toEqual([
      ['unordered-list-item', 0],
      ['ordered-list-item', 3],
    ]);
  });

  it('pruneOrphanedAnchors leaves non-anchored blocks wherever they start', () => {
    store.setRanges([block('paragraph', 1, 2)]);

    store.edit('ab', (w) => w.pruneOrphanedAnchors());

    expect(store.allRanges).toHaveLength(1);
  });

  it('pruneOrphanedAnchors judges an anchor past the text at the text end', () => {
    store.setRanges([block('h1', 9, 9)]);
    store.edit('ab\n', (w) => w.pruneOrphanedAnchors());
    expect(store.allRanges).toHaveLength(1);

    store.setRanges([block('h1', 9, 9)]);
    store.edit('ab', (w) => w.pruneOrphanedAnchors());
    expect(store.allRanges).toHaveLength(0);
  });

  it('setRanges sorts incoming blocks by start', () => {
    store.setRanges([block('paragraph', 6, 11), block('h1', 0, 5)]);

    expect(store.allRanges.map((r) => r.start)).toEqual([0, 6]);
  });
});

describe('BlockStore.rewriteLines', () => {
  let store: BlockStore;

  beforeEach(() => {
    store = new BlockStore();
  });

  it('keeps, replaces or clears each line and leaves the rest alone', () => {
    const kept = block('unordered-list-item', 10, 16);
    store.setRanges([
      block('h1', 0, 9, 1),
      kept,
      block('h2', 17, 17, 2),
      block('ordered-list-item', 18, 21),
    ]);
    const seen: (string | null)[] = [];

    store.edit(text, (w) =>
      w.rewriteLines(
        linesTouching({ start: 12, end: 19 }, text),
        (line, existing) => {
          seen.push(existing?.type ?? null);
          if (line.start === 10) {
            return existing;
          }
          if (line.start === 17) {
            return null;
          }
          return { type: 'unordered-list-item', level: 0 };
        }
      )
    );

    expect(seen).toEqual(['unordered-list-item', 'h2', 'ordered-list-item']);
    expect(store.allRanges).toEqual([
      block('h1', 0, 9, 1),
      block('unordered-list-item', 10, 16),
      block('unordered-list-item', 18, 21),
    ]);
    expect(store.allRanges[1]).toBe(kept);
  });

  it('writes an empty line as an anchor only for anchored types', () => {
    const lines = linesTouching({ start: 10, end: 21 }, text);

    store.edit(text, (w) =>
      w.rewriteLines(lines, () => ({ type: 'paragraph', level: 0 }))
    );
    expect(store.allRanges.map((r) => [r.start, r.end])).toEqual([
      [10, 16],
      [18, 21],
    ]);

    store.edit(text, (w) =>
      w.rewriteLines(lines, () => ({ type: 'h2', level: 2 }))
    );
    expect(store.allRanges).toEqual([
      block('h2', 10, 16, 2),
      block('h2', 17, 17, 2),
      block('h2', 18, 21, 2),
    ]);
  });

  it('rewrites a select-all far past the argument-spread limit', () => {
    const many = Array.from({ length: 200_000 }, () => 'x').join('\n');

    store.edit(many, (w) =>
      w.rewriteLines(
        linesTouching({ start: 0, end: many.length }, many),
        () => ({
          type: 'unordered-list-item',
          level: 0,
        })
      )
    );

    expect(store.allRanges).toHaveLength(200_000);
  });

  // Seeded random documents: one block per line at most, so the expected
  // result is the per-line decisions laid over the untouched lines.
  // `setBlock`/`removeBlock` line by line must agree with it too.
  it('agrees with a per-line model, as does setBlock/removeBlock per line', () => {
    let seed = 1014;
    const random = () => {
      seed = (seed * 1103515245 + 12345) % 2 ** 31;
      return seed / 2 ** 31;
    };
    const pick = <T>(options: readonly T[]): T =>
      options[Math.floor(random() * options.length)]!;
    const lineBlocks: readonly LineBlock[] = [
      null,
      { type: 'h2', level: 2 },
      { type: 'paragraph', level: 0 },
      { type: 'unordered-list-item', level: 0 },
      { type: 'unordered-list-item', level: 1 },
      { type: 'ordered-list-item', level: 2 },
    ];
    const choices: readonly ('keep' | LineBlock)[] = ['keep', ...lineBlocks];

    for (let round = 0; round < 300; round++) {
      const doc = Array.from({ length: 1 + Math.floor(random() * 20) }, () =>
        random() < 0.25 ? '' : 'x'.repeat(1 + Math.floor(random() * 3))
      ).join('\n');
      const allLines = linesTouching({ start: 0, end: doc.length }, doc);
      const drawn = new Map<number, LineBlock>();
      for (const line of allLines) {
        const choice = pick(lineBlocks);
        if (
          choice !== null &&
          (line.end > line.start || choice.type !== 'paragraph')
        ) {
          drawn.set(line.start, choice);
        }
      }
      const toRanges = (blocks: Map<number, LineBlock>) =>
        allLines.flatMap((line) => {
          const b = blocks.get(line.start);
          return b ? [block(b.type, line.start, line.end, b.level)] : [];
        });
      // Start from the depths the ancestry clamp leaves: it overwrites them,
      // so the drawn ones are gone once they are stored.
      const seeded = new BlockStore();
      seeded.setRanges(toRanges(drawn));
      const initial = new Map<number, LineBlock>(
        seeded.allRanges.map((r) => [r.start, { type: r.type, level: r.level }])
      );

      const a = Math.floor(random() * (doc.length + 1));
      const b = Math.floor(random() * (doc.length + 1));
      const selected = linesTouching(
        { start: Math.min(a, b), end: Math.max(a, b) },
        doc
      );
      const decisions = new Map(selected.map((l) => [l.start, pick(choices)]));

      const expected = new Map(initial);
      for (const [start, choice] of decisions) {
        if (choice === 'keep') {
          continue;
        }
        const line = selected.find((l) => l.start === start)!;
        if (
          choice === null ||
          (line.end === line.start && choice.type === 'paragraph')
        ) {
          expected.delete(start);
        } else {
          expected.set(start, choice);
        }
      }
      const model = new BlockStore();
      model.setRanges(toRanges(expected));

      const bulk = new BlockStore();
      bulk.setRanges(toRanges(initial));
      bulk.edit(doc, (w) =>
        w.rewriteLines(selected, (line, existing) => {
          const choice = decisions.get(line.start)!;
          return choice === 'keep' ? existing : choice;
        })
      );

      const perLine = new BlockStore();
      perLine.setRanges(toRanges(initial));
      perLine.edit(doc, (w) => {
        for (const line of selected) {
          const choice = decisions.get(line.start)!;
          if (choice === null) {
            w.removeBlock(line.start, line.start);
          } else if (choice !== 'keep') {
            w.setBlock(choice.type, choice.level, line.start, line.start);
          }
        }
      });

      const context = JSON.stringify({
        doc,
        initial: [...initial],
        decisions: [...decisions],
      });
      expect([context, bulk.allRanges]).toEqual([context, model.allRanges]);
      expect([context, perLine.allRanges]).toEqual([context, model.allRanges]);
    }
  });
});
