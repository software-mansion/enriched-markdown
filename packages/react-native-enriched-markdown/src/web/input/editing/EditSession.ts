export type EditPhase = 'idle' | 'processing' | 'formatting' | 'importing';

const POST_EDIT_GRACE_PERIOD_MS = 100;

// Tracks what our own code is currently doing, so handlers can tell a user
// action from an echo of ours.
//
// Composition state lives alongside the phase because it describes the
// browser's IME rather than our code. The authority on it is the event -
// `InputEvent.isComposing` and `KeyboardEvent.isComposing` - and this latch
// only covers the handlers that get no event to ask, so it has to be cleared
// on every way out of a composition (commit, blur, teardown) or the editor
// would stay read-only for the rest of its life.
export class EditSession {
  private composing = false;
  private currentPhase: EditPhase = 'idle';
  // Not 0: `performance.now()` is 0 at the document's time origin, so a zero
  // sentinel reads as a text change that just happened for the first
  // millisecond of the page's life.
  private lastTextChangeTime = Number.NEGATIVE_INFINITY;

  get phase(): EditPhase {
    return this.currentPhase;
  }

  get isComposing(): boolean {
    return this.composing;
  }

  beginComposition(): void {
    this.composing = true;
  }

  endComposition(): void {
    this.composing = false;
  }

  scoped<T>(phase: EditPhase, block: () => T): T {
    const previous = this.currentPhase;
    this.currentPhase = phase;
    try {
      return block();
    } finally {
      this.currentPhase = previous;
    }
  }

  recordTextChange(): void {
    this.lastTextChangeTime = performance.now();
  }

  get isPostEditGracePeriod(): boolean {
    return (
      performance.now() - this.lastTextChangeTime < POST_EDIT_GRACE_PERIOD_MS
    );
  }

  get shouldSuppressEvents(): boolean {
    return this.currentPhase === 'importing';
  }

  // Only catches a side effect delivered on the same stack as the write that
  // caused it. `selectionchange` is queued rather than dispatched, so this
  // does not cover it - see `InputHost.handleSelectionChange`.
  get shouldSuppressSelectionSideEffects(): boolean {
    return this.currentPhase !== 'idle';
  }
}
