import { linesTouching, type BlockStore } from '../formatting/BlockStore';
import { isListItem, MAX_LIST_DEPTH, type BlockType } from '../model/blocks';
import type { RangeBounds } from '../model/rangeBounds';
import { clamp } from '../utils';

export class BlockEditCoordinator {
  private readonly blockStore: BlockStore;

  constructor(blockStore: BlockStore) {
    this.blockStore = blockStore;
  }

  changeListDepthBy(
    delta: number,
    selection: RangeBounds,
    text: string
  ): boolean {
    const startBlock = this.blockStore.blockAt(selection.start, text);
    if (!isListItem(startBlock)) {
      // Indenting a plain paragraph starts a list; a heading stays put.
      if (delta > 0 && startBlock === null) {
        this.toggleListType('unordered-list-item', selection, text);
        return true;
      }
      return false;
    }
    if (delta < 0 && startBlock.level === 0) {
      this.toggleListType(startBlock.type, selection, text);
      return true;
    }

    for (const line of linesTouching(selection, text)) {
      const block = this.blockStore.blockStartingAt(line.start);
      if (!isListItem(block)) {
        continue;
      }
      const depth = clamp(block.level + delta, 0, MAX_LIST_DEPTH);
      this.blockStore.setBlock(block.type, depth, line.start, line.start, text);
    }
    this.blockStore.normalizeToLineBounds(text);
    return true;
  }

  // Turns the list off when the item at the selection start already has
  // `type`; otherwise makes every touched line an item of `type`, keeping an
  // existing depth.
  toggleListType(type: BlockType, selection: RangeBounds, text: string): void {
    const startBlock = this.blockStore.blockAt(selection.start, text);
    const turningOff = isListItem(startBlock) && startBlock.type === type;

    for (const line of linesTouching(selection, text)) {
      if (turningOff) {
        this.blockStore.removeBlock(line.start, line.start, text);
        continue;
      }
      const existing = this.blockStore.blockStartingAt(line.start);
      const depth = isListItem(existing) ? existing.level : 0;
      this.blockStore.setBlock(type, depth, line.start, line.start, text);
    }
    this.blockStore.normalizeToLineBounds(text);
  }
}
