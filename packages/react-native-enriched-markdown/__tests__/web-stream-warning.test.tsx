import { renderToStaticMarkup } from 'react-dom/server';
import { EnrichedMarkdownText } from '../src/web/EnrichedMarkdownText';
import type { MarkdownStream } from '../src/markdownStream';

jest.mock('react-native', () => ({
  Platform: { OS: 'web' },
  processColor: (color: unknown) => color,
}));

it('warns once of a stream not from createMarkdownStream()', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  renderToStaticMarkup(
    <EnrichedMarkdownText stream={{} as MarkdownStream} markdown="" />
  );
  expect(
    warn.mock.calls.filter(([message]) =>
      String(message).includes('takes a stream from createMarkdownStream()')
    )
  ).toHaveLength(1);
  warn.mockRestore();
});
