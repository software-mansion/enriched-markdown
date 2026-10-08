import { BlockEditCoordinator } from '../BlockEditCoordinator';
import { BlockStore } from '../../formatting/BlockStore';
import { createBlockRange as block, MAX_LIST_DEPTH } from '../../model/blocks';

// "stack\nreview\nmerge": 0-5 | 6-12 | 13-18
const text = 'stack\nreview\nmerge';

function caret(position: number) {
  return { start: position, end: position };
}

function depths(store: BlockStore) {
  return store.allRanges.map((b) => [b.type, b.level]);
}

describe('BlockEditCoordinator', () => {
  it('indents no deeper than one level below the item above', () => {
    const store = new BlockStore();
    store.setRanges([
      block('unordered-list-item', 0, 5),
      block('unordered-list-item', 6, 12),
    ]);
    const coordinator = new BlockEditCoordinator(store);

    coordinator.changeListDepthBy(1, caret(8), text);
    coordinator.changeListDepthBy(1, caret(8), text);

    expect(depths(store)).toEqual([
      ['unordered-list-item', 0],
      ['unordered-list-item', 1],
    ]);
  });

  it('outdents at depth 0 out of the list, and indent starts a list only on a paragraph', () => {
    const store = new BlockStore();
    store.setRanges([
      block('unordered-list-item', 0, 5),
      block('h2', 13, 18, 2),
    ]);
    const coordinator = new BlockEditCoordinator(store);

    expect(coordinator.changeListDepthBy(-1, caret(2), text)).toBe(true);
    expect(coordinator.changeListDepthBy(1, caret(8), text)).toBe(true);
    expect(coordinator.changeListDepthBy(1, caret(15), text)).toBe(false);

    expect(depths(store)).toEqual([
      ['unordered-list-item', 0],
      ['h2', 2],
    ]);
  });

  it('changes depth only on the list items a selection touches', () => {
    const store = new BlockStore();
    store.setRanges([
      block('unordered-list-item', 0, 5),
      block('unordered-list-item', 6, 12),
    ]);
    const coordinator = new BlockEditCoordinator(store);

    // Selection spans "review" (item) and "merge" (paragraph).
    coordinator.changeListDepthBy(1, { start: 8, end: 15 }, text);

    expect(depths(store)).toEqual([
      ['unordered-list-item', 0],
      ['unordered-list-item', 1],
    ]);
  });

  it('toggles the type across a selection and switching type keeps depth', () => {
    const store = new BlockStore();
    store.setRanges([
      block('unordered-list-item', 0, 5),
      block('unordered-list-item', 6, 12, 1),
    ]);
    const coordinator = new BlockEditCoordinator(store);

    coordinator.toggleListType(
      'ordered-list-item',
      { start: 0, end: 18 },
      text
    );
    expect(depths(store)).toEqual([
      ['ordered-list-item', 0],
      ['ordered-list-item', 1],
      ['ordered-list-item', 0],
    ]);

    coordinator.toggleListType(
      'ordered-list-item',
      { start: 0, end: 12 },
      text
    );
    expect(depths(store)).toEqual([['ordered-list-item', 0]]);
  });

  it('stops indenting at MAX_LIST_DEPTH', () => {
    // A ladder of items each one level deeper, so the last already sits at
    // the cap and the ancestry clamp is not what holds it there.
    const count = MAX_LIST_DEPTH + 1;
    const ladder = Array.from({ length: count }, () => 'item').join('\n');
    const store = new BlockStore();
    store.setRanges(
      Array.from({ length: count }, (_, i) =>
        block('unordered-list-item', i * 5, i * 5 + 4, i)
      )
    );
    const coordinator = new BlockEditCoordinator(store);

    coordinator.changeListDepthBy(1, caret((count - 1) * 5 + 2), ladder);

    expect(store.allRanges.map((b) => b.level)).toEqual(
      Array.from({ length: count }, (_, i) => i)
    );
  });

  describe('toggleHeading', () => {
    it('applies the level to every line the selection touches', () => {
      const store = new BlockStore();
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(2, { start: 2, end: 15 }, text);

      expect(store.allRanges.map((b) => [b.type, b.start, b.level])).toEqual([
        ['h2', 0, 2],
        ['h2', 6, 2],
        ['h2', 13, 2],
      ]);
    });

    it('toggles the same level back off', () => {
      const store = new BlockStore();
      store.setRanges([block('h2', 0, 5, 2)]);
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(2, caret(2), text);

      expect(store.allRanges).toEqual([]);
    });

    // Decided by the line the selection starts on, so a mixed selection
    // becomes uniform rather than each line flipping on its own.
    it('turns a mixed selection on from the start line', () => {
      const store = new BlockStore();
      store.setRanges([block('h2', 6, 12, 2)]);
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(2, { start: 2, end: 8 }, text);

      expect(store.allRanges.map((b) => [b.type, b.start])).toEqual([
        ['h2', 0],
        ['h2', 6],
      ]);
    });

    it('replaces a heading of another level rather than clearing it', () => {
      const store = new BlockStore();
      store.setRanges([block('h1', 0, 5, 1)]);
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(3, caret(2), text);

      expect(store.allRanges.map((b) => [b.type, b.level])).toEqual([
        ['h3', 3],
      ]);
    });

    it('replaces a list item on the line', () => {
      const store = new BlockStore();
      store.setRanges([block('unordered-list-item', 0, 5, 0)]);
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(1, caret(2), text);

      expect(store.allRanges.map((b) => b.type)).toEqual(['h1']);
    });

    it('ignores a level no heading type covers', () => {
      const store = new BlockStore();
      store.setRanges([block('h1', 0, 5, 1)]);
      const coordinator = new BlockEditCoordinator(store);

      coordinator.toggleHeading(0, caret(2), text);
      coordinator.toggleHeading(7, caret(2), text);
      coordinator.toggleHeading(-1, caret(2), text);

      expect(store.allRanges.map((b) => [b.type, b.level])).toEqual([
        ['h1', 1],
      ]);
    });
  });
});
