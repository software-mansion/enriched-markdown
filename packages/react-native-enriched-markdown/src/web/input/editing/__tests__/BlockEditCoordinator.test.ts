import { BlockEditCoordinator } from '../BlockEditCoordinator';
import { BlockStore } from '../../formatting/BlockStore';
import { createBlockRange as block } from '../../model/blocks';

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
});
