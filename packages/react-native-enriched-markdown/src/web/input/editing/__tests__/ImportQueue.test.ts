import { ImportQueue } from '../ImportQueue';

// A deferred task runs from a `.then`, and the queue chains several of those
// per import. Yielding to a macrotask drains the microtask queue however deep
// the chain happens to be, which counting turns by hand does not.
async function drain(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

function heldImport(): {
  release: () => Promise<void>;
  task: () => Promise<void>;
} {
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  return {
    task: () => gate,
    release: async () => {
      release();
      await drain();
    },
  };
}

// Nothing queued in these tests is meant to fail; one that does should say so
// rather than be swallowed by the queue's own error handling.
function unexpectedError(error: unknown): never {
  throw new Error(`unexpected queue failure: ${String(error)}`);
}

describe('afterImport', () => {
  it('runs the task and answers its value while nothing is importing', () => {
    const queue = new ImportQueue();

    expect(queue.afterImport(() => 'now')).toBe('now');
  });

  it('holds the task behind an import in flight', async () => {
    const queue = new ImportQueue();
    const { task, release } = heldImport();
    queue.startImport(task, unexpectedError);

    const ran: string[] = [];
    const answer = queue.afterImport(() => {
      ran.push('task');
      return 'later';
    });
    expect(ran).toEqual([]);

    await release();
    await expect(answer).resolves.toBe('later');
  });

  it('is synchronous again once the import has settled', async () => {
    const queue = new ImportQueue();
    const { task, release } = heldImport();
    queue.startImport(task, unexpectedError);
    await release();

    expect(queue.afterImport(() => 'now')).toBe('now');
  });

  // The caller consumes the result, so the failure is theirs either way.
  it('lets a failure through to the caller', async () => {
    const queue = new ImportQueue();
    const boom = new Error('boom');

    expect(() =>
      queue.afterImport(() => {
        throw boom;
      })
    ).toThrow(boom);

    const { task, release } = heldImport();
    queue.startImport(task, unexpectedError);
    // The handler goes on before the release, so the rejection is never
    // momentarily unhandled - which jest reports as a failure of its own.
    const deferred: unknown[] = [];
    (
      queue.afterImport(() => {
        throw boom;
      }) as Promise<never>
    ).catch(deferred.push.bind(deferred));

    await release();
    expect(deferred).toEqual([boom]);
  });
});

describe('runAfterImport', () => {
  it('runs the task while nothing is importing', () => {
    const queue = new ImportQueue();
    const ran: string[] = [];

    queue.runAfterImport(() => ran.push('task'), unexpectedError);

    expect(ran).toEqual(['task']);
  });

  it('holds the task behind an import in flight', async () => {
    const queue = new ImportQueue();
    const { task, release } = heldImport();
    queue.startImport(task, unexpectedError);

    const ran: string[] = [];
    queue.runAfterImport(() => ran.push('task'), unexpectedError);
    expect(ran).toEqual([]);

    await release();
    expect(ran).toEqual(['task']);
  });

  // The command returns nothing, so there is no result for a failure to ride
  // out on. Reporting it the same way in both branches is the whole point:
  // otherwise the error channel depends on whether an import happened to be
  // in flight, and no caller-side `try`/`catch` is right in both cases.
  it('reports a failure to onError whichever branch ran', async () => {
    const queue = new ImportQueue();
    const boom = new Error('boom');
    const immediate: unknown[] = [];

    queue.runAfterImport(() => {
      throw boom;
    }, immediate.push.bind(immediate));
    expect(immediate).toEqual([boom]);

    const { task, release } = heldImport();
    queue.startImport(task, unexpectedError);
    const deferred: unknown[] = [];
    queue.runAfterImport(() => {
      throw boom;
    }, deferred.push.bind(deferred));

    await release();
    expect(deferred).toEqual([boom]);
  });
});

describe('startImport', () => {
  it('reports a failing import without blocking the work behind it', async () => {
    const queue = new ImportQueue();
    const boom = new Error('boom');
    const errors: unknown[] = [];
    const ran: string[] = [];

    queue.startImport(async () => {
      throw boom;
    }, errors.push.bind(errors));
    queue.runAfterImport(() => ran.push('task'), unexpectedError);
    await drain();

    expect(errors).toEqual([boom]);
    expect(ran).toEqual(['task']);
  });

  it('runs imports in the order they were asked for', async () => {
    const queue = new ImportQueue();
    const order: string[] = [];
    const first = heldImport();

    queue.startImport(async () => {
      await first.task();
      order.push('first');
    }, unexpectedError);
    queue.startImport(() => {
      order.push('second');
    }, unexpectedError);
    queue.runAfterImport(() => order.push('command'), unexpectedError);

    expect(order).toEqual([]);
    await first.release();
    expect(order).toEqual(['first', 'second', 'command']);
  });

  // Only the latest import clears the queue: an older one settling afterwards
  // would otherwise let work jump ahead of the import still in flight.
  it('keeps holding the queue while a later import is still running', async () => {
    const queue = new ImportQueue();
    const second = heldImport();

    queue.startImport(() => undefined, unexpectedError);
    queue.startImport(second.task, unexpectedError);
    await drain();

    const ran: string[] = [];
    queue.runAfterImport(() => ran.push('task'), unexpectedError);
    expect(ran).toEqual([]);

    await second.release();
    expect(ran).toEqual(['task']);
  });
});
