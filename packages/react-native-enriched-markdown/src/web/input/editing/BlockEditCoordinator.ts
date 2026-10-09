import { linesTouching, type BlockStore } from '../formatting/BlockStore';
import {
  blockTypeForHeadingLevel,
  isListItem,
  MAX_LIST_DEPTH,
  type BlockType,
} from '../model/blocks';
import type { RangeBounds } from '../model/rangeBounds';
import { clamp } from '../utils';

export class BlockEditCoordinator {
  private readonly blockStore: BlockStore;

  constructor(blockStore: BlockStore) {
    this.blockStore = blockStore;
  }

  // Returns whether the model actually changed, which is what tells the
  // caller a re-render is worth doing.
  //
  // The requested depth is clamped twice: once here against MAX_LIST_DEPTH,
  // then again by the store's ancestry pass, which holds an item at most one
  // level below the item above it. A write that survives the first clamp can
  // still land on the depth the item already had - indenting the first item
  // of a list is the common case - so the answer is only knowable after the
  // writes, by comparing the depths the lines ended up with.
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

    const lines = linesTouching(selection, text);
    const depthsBefore = lines.map((line) => this.listDepthAt(line.start));

    this.blockStore.batchWrites(() => {
      for (const line of lines) {
        const block = this.blockStore.blockStartingAt(line.start);
        if (!isListItem(block)) {
          continue;
        }
        const depth = clamp(block.level + delta, 0, MAX_LIST_DEPTH);
        this.blockStore.setBlock(
          block.type,
          depth,
          line.start,
          line.start,
          text
        );
      }
    });
    this.blockStore.normalizeToLineBounds(text);

    return lines.some(
      (line, index) => this.listDepthAt(line.start) !== depthsBefore[index]
    );
  }

  private listDepthAt(lineStart: number): number | null {
    const block = this.blockStore.blockStartingAt(lineStart);
    return isListItem(block) ? block.level : null;
  }

  toggleHeading(level: number, selection: RangeBounds, text: string): void {
    const type = blockTypeForHeadingLevel(level);
    if (type === null) {
      return;
    }
    const startBlock = this.blockStore.blockAt(selection.start, text);
    const turningOff =
      startBlock !== null &&
      startBlock.type === type &&
      startBlock.level === level;

    this.blockStore.batchWrites(() => {
      for (const line of linesTouching(selection, text)) {
        if (turningOff) {
          this.blockStore.removeBlock(line.start, line.start, text);
        } else {
          this.blockStore.setBlock(type, level, line.start, line.start, text);
        }
      }
    });
    this.blockStore.normalizeToLineBounds(text);
  }

  // Turns the list off when the item at the selection start already has
  // `type`; otherwise makes every touched line an item of `type`, keeping an
  // existing depth.
  toggleListType(type: BlockType, selection: RangeBounds, text: string): void {
    const startBlock = this.blockStore.blockAt(selection.start, text);
    const turningOff = isListItem(startBlock) && startBlock.type === type;

    this.blockStore.batchWrites(() => {
      for (const line of linesTouching(selection, text)) {
        if (turningOff) {
          this.blockStore.removeBlock(line.start, line.start, text);
          continue;
        }
        const existing = this.blockStore.blockStartingAt(line.start);
        const depth = isListItem(existing) ? existing.level : 0;
        this.blockStore.setBlock(type, depth, line.start, line.start, text);
      }
    });
    this.blockStore.normalizeToLineBounds(text);
  }
}
