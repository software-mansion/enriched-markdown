import { EditSession } from '../EditSession';

describe('EditSession', () => {
  it('scoped restores the previous phase, also when nested or throwing', () => {
    const session = new EditSession();

    const result = session.scoped('processing', () =>
      session.scoped('formatting', () => {
        expect(session.phase).toBe('formatting');
        session.scoped('importing', () => {
          expect(session.phase).toBe('importing');
        });
        expect(session.phase).toBe('formatting');
        return 'done';
      })
    );
    expect(result).toBe('done');
    expect(session.phase).toBe('idle');

    expect(() =>
      session.scoped('importing', () => {
        throw new Error('boom');
      })
    ).toThrow('boom');
    expect(session.phase).toBe('idle');
  });

  // The two suppression getters have near-identical bodies, so a copy-paste
  // slip between them type-checks and either gags ordinary typing or leaks
  // import events to the app.
  it('suppresses events only while importing, selection effects in any phase', () => {
    const session = new EditSession();
    const observed: Record<string, [boolean, boolean]> = {};
    for (const phase of ['processing', 'formatting', 'importing'] as const) {
      session.scoped(phase, () => {
        observed[phase] = [
          session.shouldSuppressEvents,
          session.shouldSuppressSelectionSideEffects,
        ];
      });
    }

    expect(observed).toEqual({
      processing: [false, true],
      formatting: [false, true],
      importing: [true, true],
    });
    expect(session.shouldSuppressEvents).toBe(false);
    expect(session.shouldSuppressSelectionSideEffects).toBe(false);
  });

  it('composition latches until it is explicitly ended', () => {
    const session = new EditSession();
    expect(session.isComposing).toBe(false);

    session.beginComposition();
    expect(session.isComposing).toBe(true);
    session.endComposition();
    expect(session.isComposing).toBe(false);
  });

  // The only arithmetic in the file and the only place the grace period
  // appears, so a seconds/milliseconds slip against iOS's 0.1 would pass
  // every other test here.
  it('holds the post-edit grace period for 100ms', () => {
    jest.useFakeTimers();
    try {
      const session = new EditSession();
      expect(session.isPostEditGracePeriod).toBe(false);

      session.recordTextChange();
      expect(session.isPostEditGracePeriod).toBe(true);
      jest.advanceTimersByTime(99);
      expect(session.isPostEditGracePeriod).toBe(true);
      jest.advanceTimersByTime(1);
      expect(session.isPostEditGracePeriod).toBe(false);
    } finally {
      jest.useRealTimers();
    }
  });
});
