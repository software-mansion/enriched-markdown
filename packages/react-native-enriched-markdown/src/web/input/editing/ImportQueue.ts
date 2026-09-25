// Serializes work behind an import in flight, so commands issued right after
// setValue act on the new document.
export class ImportQueue {
  private pending: Promise<void> | null = null;

  afterImport<T>(task: () => T): T | Promise<T> {
    return this.pending === null ? task() : this.pending.then(task);
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
