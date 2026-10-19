import {
  createBlockRange,
  HEADING_BLOCK_TYPES,
  LIST_ITEM_BLOCK_TYPES,
  type BlockRange,
  type BlockType,
} from '../model/blocks';
import {
  createFormattingRange,
  INPUT_STYLE_TYPES,
  type FormattingRange,
} from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';
import type { TextEdit } from '../model/textEdit';

// The ranges and selection around an entry, as the host hands them over and
// gets them back. What `undo`/`redo` return is freshly built, so the caller
// may hand it straight to the stores, which mutate their ranges in place.
export interface ModelSnapshot {
  formatting: readonly FormattingRange[];
  blocks: readonly BlockRange[];
  selection: RangeBounds;
  backward: boolean;
}

// A snapshot as stored: the ranges packed into typed arrays rather than kept
// as objects, a third of the size. Packing is also what copies them, so the
// stores' in-place mutations cannot reach a stored snapshot.
interface PackedSnapshot {
  // [type, start, end] per range.
  formatting: Int32Array;
  // Link urls by range index; most ranges have none.
  urls: Map<number, string> | null;
  // [type, start, end, level] per range. `ordinal` is left out: the store
  // recomputes it on the way back in.
  blocks: Int32Array;
  selection: RangeBounds;
  backward: boolean;
}

// - `typing`: an insert with no newline, at a caret.
// - `deleting`: a single Backspace or Delete.
// - `composition`: anything an IME commits; merged until the composition ends.
// - `other`: newlines, paste, cut, replacements, commands. Never merged.
export type EditKind = 'typing' | 'deleting' | 'composition' | 'other';

interface HistoryEntry {
  // Forward, in the order they were made.
  edits: TextEdit[];
  before: PackedSnapshot;
  // The ranges are taken from the live model when the entry is undone, which
  // is exactly the state after it: undo only ever steps back over the newest
  // entry. The selection is not: the user may have moved it since, so it is
  // where the entry left it.
  after: PackedSnapshot | null;
  kind: EditKind;
  lastAt: number;
  // Where the last edit left the caret; unused by a formatting change, which
  // leaves the selection where it was.
  caret: number;
}

export interface HistoryState {
  canUndo: boolean;
  canRedo: boolean;
}

// Typing that pauses longer than this starts a new undo step.
export const GROUP_INTERVAL_MS = 500;
export const MAX_HISTORY_DEPTH = 100;

const BLOCK_TYPES: readonly BlockType[] = [
  'paragraph',
  ...HEADING_BLOCK_TYPES,
  ...LIST_ITEM_BLOCK_TYPES,
];

function pack(snapshot: ModelSnapshot): PackedSnapshot {
  const { formatting, blocks } = snapshot;
  const packedFormatting = new Int32Array(formatting.length * 3);
  let urls: Map<number, string> | null = null;
  formatting.forEach((range, i) => {
    packedFormatting[i * 3] = INPUT_STYLE_TYPES.indexOf(range.type);
    packedFormatting[i * 3 + 1] = range.start;
    packedFormatting[i * 3 + 2] = range.end;
    if (range.url !== undefined) {
      urls ??= new Map();
      urls.set(i, range.url);
    }
  });
  const packedBlocks = new Int32Array(blocks.length * 4);
  blocks.forEach((range, i) => {
    packedBlocks[i * 4] = BLOCK_TYPES.indexOf(range.type);
    packedBlocks[i * 4 + 1] = range.start;
    packedBlocks[i * 4 + 2] = range.end;
    packedBlocks[i * 4 + 3] = range.level;
  });
  return {
    formatting: packedFormatting,
    urls,
    blocks: packedBlocks,
    selection: { ...snapshot.selection },
    backward: snapshot.backward,
  };
}

function unpack(packed: PackedSnapshot): ModelSnapshot {
  const formatting: FormattingRange[] = [];
  for (let i = 0; i < packed.formatting.length / 3; i++) {
    formatting.push(
      createFormattingRange(
        INPUT_STYLE_TYPES[packed.formatting[i * 3]!]!,
        packed.formatting[i * 3 + 1]!,
        packed.formatting[i * 3 + 2]!,
        packed.urls?.get(i)
      )
    );
  }
  const blocks: BlockRange[] = [];
  for (let i = 0; i < packed.blocks.length / 4; i++) {
    blocks.push(
      createBlockRange(
        BLOCK_TYPES[packed.blocks[i * 4]!]!,
        packed.blocks[i * 4 + 1]!,
        packed.blocks[i * 4 + 2]!,
        packed.blocks[i * 4 + 3]!
      )
    );
  }
  return {
    formatting,
    blocks,
    selection: { ...packed.selection },
    backward: packed.backward,
  };
}

// The model's undo and redo stacks. Text is kept as the edits themselves and
// replayed backwards; ranges and selection as one snapshot per entry, taken
// when the entry opens. Pure: the host captures and restores.
//
// Snapshots are whole, not scoped to the edit: an edit reaches ranges well
// outside its own span (deleting a list item re-clamps the depth of every
// item nested below it, and ordinals renumber down the list).
export class EditHistory {
  private readonly now: () => number;
  private readonly maxDepth: number;
  private undoStack: HistoryEntry[] = [];
  private redoStack: HistoryEntry[] = [];
  // Whether the newest undo entry may still take more edits.
  private open = false;
  // What `recordFormatting` cleared, held until something else is recorded,
  // so a command that turns out to change nothing can be taken back whole.
  private discardable: { entry: HistoryEntry; redo: HistoryEntry[] } | null =
    null;

  constructor(
    now: () => number = () => performance.now(),
    maxDepth = MAX_HISTORY_DEPTH
  ) {
    this.now = now;
    this.maxDepth = maxDepth;
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  get state(): HistoryState {
    return { canUndo: this.canUndo, canRedo: this.canRedo };
  }

  // `captureBefore` runs only when the edit opens a new entry: once per undo
  // step, not once per keystroke. `caret` is where the edit leaves it.
  record(
    edit: TextEdit,
    kind: EditKind,
    captureBefore: () => ModelSnapshot,
    caret = edit.editStart + edit.insertedText.length
  ): void {
    const at = this.now();
    const top = this.undoStack[this.undoStack.length - 1];
    this.discardable = null;
    this.redoStack = [];
    if (top !== undefined && this.open && merges(top, edit, kind, at)) {
      top.edits.push({ ...edit });
      top.lastAt = at;
      top.caret = caret;
      return;
    }
    this.push({
      edits: [{ ...edit }],
      before: pack(captureBefore()),
      after: null,
      kind,
      lastAt: at,
      caret,
    });
    this.open = kind !== 'other';
  }

  // A change to the ranges alone. Always an entry of its own.
  recordFormatting(captureBefore: () => ModelSnapshot): void {
    const entry: HistoryEntry = {
      edits: [],
      before: pack(captureBefore()),
      after: null,
      kind: 'other',
      lastAt: this.now(),
      caret: 0,
    };
    this.discardable = { entry, redo: this.redoStack };
    this.redoStack = [];
    this.push(entry);
    this.open = false;
  }

  // Takes back the entry `recordFormatting` just opened, for a command that
  // ended up changing nothing, and puts back the redo steps it cleared.
  discardFormatting(): void {
    const discardable = this.discardable;
    this.discardable = null;
    if (
      discardable === null ||
      this.undoStack[this.undoStack.length - 1] !== discardable.entry
    ) {
      return;
    }
    this.undoStack.pop();
    this.redoStack = discardable.redo;
  }

  // The next edit starts a new entry, whatever it is.
  breakGroup(): void {
    this.open = false;
  }

  // The entry to restore `before` from, with its `after` filled in by
  // `captureAfter`; null when there is nothing to undo.
  undo(captureAfter: () => ModelSnapshot): {
    edits: readonly TextEdit[];
    target: ModelSnapshot;
  } | null {
    const entry = this.undoStack.pop();
    if (entry === undefined) {
      return null;
    }
    this.open = false;
    this.discardable = null;
    entry.after = { ...pack(captureAfter()), ...selectionAfter(entry) };
    this.redoStack.push(entry);
    return { edits: entry.edits, target: unpack(entry.before) };
  }

  redo(): { edits: readonly TextEdit[]; target: ModelSnapshot } | null {
    const entry = this.redoStack.pop();
    if (entry === undefined || entry.after === null) {
      return null;
    }
    this.open = false;
    this.discardable = null;
    this.undoStack.push(entry);
    return { edits: entry.edits, target: unpack(entry.after) };
  }

  clear(): void {
    this.undoStack = [];
    this.redoStack = [];
    this.open = false;
    this.discardable = null;
  }

  private push(entry: HistoryEntry): void {
    this.undoStack.push(entry);
    if (this.undoStack.length > this.maxDepth) {
      this.undoStack.shift();
    }
  }
}

function selectionAfter(
  entry: HistoryEntry
): Pick<PackedSnapshot, 'selection' | 'backward'> {
  if (entry.edits.length === 0) {
    return {
      selection: { ...entry.before.selection },
      backward: entry.before.backward,
    };
  }
  return {
    selection: { start: entry.caret, end: entry.caret },
    backward: false,
  };
}

function merges(
  top: HistoryEntry,
  edit: TextEdit,
  kind: EditKind,
  at: number
): boolean {
  if (top.kind !== kind) {
    return false;
  }
  // An IME's updates rewrite their own word in place, wherever it began, and
  // land as one step however long the user takes to pick a candidate.
  if (kind === 'composition') {
    return true;
  }
  if (at - top.lastAt > GROUP_INTERVAL_MS) {
    return false;
  }
  const last = top.edits[top.edits.length - 1]!;
  if (kind === 'typing') {
    return edit.editStart === top.caret;
  }
  if (kind === 'deleting') {
    // Backspace ends where the previous delete began; Delete starts there.
    return (
      edit.editStart + edit.deletedText.length === last.editStart ||
      edit.editStart === last.editStart
    );
  }
  return false;
}
