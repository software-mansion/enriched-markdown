import { EditSession } from '../EditSession';

describe('EditSession', () => {
  it('scoped restores the previous phase, also when nested or throwing', () => {
    const session = new EditSession();
    session.enterPhase('processing');

    const result = session.scoped('formatting', () => {
      expect(session.phase).toBe('formatting');
      session.scoped('importing', () => {
        expect(session.phase).toBe('importing');
      });
      expect(session.phase).toBe('formatting');
      return 'done';
    });
    expect(result).toBe('done');
    expect(session.phase).toBe('processing');

    expect(() =>
      session.scoped('importing', () => {
        throw new Error('boom');
      })
    ).toThrow('boom');
    expect(session.phase).toBe('processing');
  });
});
