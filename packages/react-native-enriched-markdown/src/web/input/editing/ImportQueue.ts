// Serializes work behind an import in flight, so commands issued right after
// setValue act on the new document.
export class ImportQueue {
  private pending: Promise<void> | null = null;

  // For a command whose result the caller consumes: the value itself when
  // nothing is importing, a promise for it otherwise. A failure reaches the
  // caller either way, so it is theirs to handle.
  afterImport<T>(task: () => T): T | Promise<T> {
    return this.pending === null ? task() : this.pending.then(task);
  }

  // For a command that returns nothing. There is no result to carry a failure
  // on, so it goes to `onError` whichever branch ran: the deferred one would
  // otherwise drop a rejected promise on the floor, which makes the error
  // channel depend on whether an import happened to be in flight.
  runAfterImport(task: () => void, onError: (error: unknown) => void): void {
    if (this.pending === null) {
      try {
        task();
      } catch (error) {
        onError(error);
      }
      return;
    }
    this.pending.then(task).catch(onError);
  }

  startImport(
    importTask: () => Promise<void> | void,
    onError: (error: unknown) => void
  ): void {
    const previous = this.pending ?? Promise.resolve();
    const next = previous
      .then(importTask)
      // A failed import must not block the work queued behind it.
      .catch(onError)
      .finally(() => {
        // A newer import may already be pending; only the latest one clears.
        if (this.pending === next) {
          this.pending = null;
        }
      });
    this.pending = next;
  }
}
