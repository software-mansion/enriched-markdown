import { completeMarkdown } from '../InputRemend';

describe('completeMarkdown', () => {
  it('returns balanced markdown unchanged', () => {
    expect(completeMarkdown('')).toBe('');
    expect(completeMarkdown('git rebase **main**')).toBe('git rebase **main**');
    expect(completeMarkdown('[docs](https://git-scm.com)')).toBe(
      '[docs](https://git-scm.com)'
    );
  });

  it('closes unclosed symmetric delimiters in LIFO order', () => {
    expect(completeMarkdown('**force push')).toBe('**force push**');
    expect(completeMarkdown('**rebase *interactive')).toBe(
      '**rebase *interactive***'
    );
    expect(completeMarkdown('~~drop ||squash')).toBe('~~drop ||squash||~~');
  });

  it('treats a repeated delimiter as the closing one', () => {
    // The second '*' closes, so only '**' stays open.
    expect(completeMarkdown('**a *b* c')).toBe('**a *b* c**');
  });

  it('completes a truncated link', () => {
    expect(completeMarkdown('[changelog')).toBe('[changelog]');
    expect(completeMarkdown('[changelog](https://git-scm')).toBe(
      '[changelog](https://git-scm)'
    );
  });

  it('drops styles left open inside link text', () => {
    // The bracket contains the unclosed '**'; only the url needs closing.
    expect(completeMarkdown('[**stable](https://git-scm')).toBe(
      '[**stable](https://git-scm)'
    );
  });

  it('ignores delimiters inside a link url and after a backslash', () => {
    expect(completeMarkdown('[a](https://x.dev/**path')).toBe(
      '[a](https://x.dev/**path)'
    );
    expect(completeMarkdown('2 \\* 2')).toBe('2 \\* 2');
  });

  it('leaves a closing bracket with nothing open alone', () => {
    // The asymmetric pair only pops when its own opener is on top of the
    // stack, so a stray or surplus ']' is consumed without touching it.
    expect(completeMarkdown('a] b')).toBe('a] b');
    expect(completeMarkdown('[a]] b')).toBe('[a]] b');
    expect(completeMarkdown('a) b')).toBe('a) b');
  });

  it('closes a delimiter the user meant literally', () => {
    // A known limitation rather than intent: the serializer does not escape,
    // so an unescaped '**' reaching import is indistinguishable from a
    // half-typed one. Pinned because it is what makes a round trip of
    // '2 \\*\\* 2' grow a delimiter on its second pass.
    expect(completeMarkdown('2 ** 2')).toBe('2 ** 2**');
    expect(completeMarkdown('a || b')).toBe('a || b||');
  });
});
