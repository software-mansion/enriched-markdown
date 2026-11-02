// Serializes work behind an import in flight, so commands issued right after
// setValue act on the new document.
export class ImportQueue {
  private pending: Promise<void> | null = null;

  // A failure reaches the caller either way, so it is theirs to handle.
  afterImport<T>(task: () => T): T | Promise<T> {
    return this.pending === null ? task() : this.pending.then(task);
  }

  // With no result to carry a failure, both branches report to `onError`, so
  // the error channel does not depend on whether an import was in flight.
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
