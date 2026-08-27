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
});
