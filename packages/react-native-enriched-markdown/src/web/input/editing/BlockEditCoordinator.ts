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

    this.blockStore.edit(text, (blocks) =>
      blocks.rewriteLines(lines, (_line, existing) =>
        isListItem(existing)
          ? {
              type: existing.type,
              level: clamp(existing.level + delta, 0, MAX_LIST_DEPTH),
            }
          : existing
      )
    );

    return lines.some(
      (line, index) => this.listDepthAt(line.start) !== depthsBefore[index]
    );
  }

  private listDepthAt(lineStart: number): number | null {
    const block = this.blockStore.blockStartingAt(lineStart);
    return isListItem(block) ? block.level : null;
  }

  // Returns false when `level` names no heading and nothing was touched.
  toggleHeading(level: number, selection: RangeBounds, text: string): boolean {
    const type = blockTypeForHeadingLevel(level);
    if (type === null) {
      return false;
    }
    const startBlock = this.blockStore.blockAt(selection.start, text);
    const turningOff =
      startBlock !== null &&
      startBlock.type === type &&
      startBlock.level === level;

    this.blockStore.edit(text, (blocks) =>
      blocks.rewriteLines(linesTouching(selection, text), () =>
        turningOff ? null : { type, level }
      )
    );
    return true;
  }

  // Turns the list off when the item at the selection start already has
  // `type`; otherwise makes every touched line an item of `type`, keeping an
  // existing depth.
  toggleListType(type: BlockType, selection: RangeBounds, text: string): void {
    const startBlock = this.blockStore.blockAt(selection.start, text);
    const turningOff = isListItem(startBlock) && startBlock.type === type;

    this.blockStore.edit(text, (blocks) =>
      blocks.rewriteLines(linesTouching(selection, text), (_line, existing) => {
        if (turningOff) {
          return null;
        }
        return { type, level: isListItem(existing) ? existing.level : 0 };
      })
    );
  }
}
