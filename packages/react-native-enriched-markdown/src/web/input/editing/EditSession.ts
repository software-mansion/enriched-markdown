export type EditPhase = 'idle' | 'processing' | 'formatting' | 'importing';

const POST_EDIT_GRACE_PERIOD_MS = 100;

// Tracks what our own code is currently doing, so handlers can tell a user
// action from an echo of ours. Composition state lives alongside the phase:
// it describes the browser's IME, not our code.
export class EditSession {
  isComposing = false;

  private currentPhase: EditPhase = 'idle';
  private lastTextChangeTime = 0;

  get phase(): EditPhase {
    return this.currentPhase;
  }

  enterPhase(phase: EditPhase): void {
    this.currentPhase = phase;
  }

  exitPhase(): void {
    this.currentPhase = 'idle';
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
      this.lastTextChangeTime > 0 &&
      performance.now() - this.lastTextChangeTime < POST_EDIT_GRACE_PERIOD_MS
    );
  }

  get shouldSuppressFormatting(): boolean {
    return (
      this.currentPhase === 'formatting' || this.currentPhase === 'importing'
    );
  }

  get shouldSuppressEvents(): boolean {
    return this.currentPhase === 'importing';
  }

  get shouldSuppressSelectionSideEffects(): boolean {
    return this.currentPhase !== 'idle';
  }
}
