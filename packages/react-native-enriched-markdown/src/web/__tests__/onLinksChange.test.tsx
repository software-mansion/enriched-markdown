import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../EnrichedMarkdownText';

it('reports the parsed links first, with no empty report before the parse', async () => {
  const onLinksChange = jest.fn();
  const root = createRoot();
  await act(async () => {
    await root.render(
      <EnrichedMarkdownText
        markdown="[e](https://e.com)"
        md4cFlags={{ latexMath: false }}
        onLinksChange={onLinksChange}
      />
    );
  });
  for (let i = 0; i < 30 && onLinksChange.mock.calls.length === 0; i++) {
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 100));
    });
  }
  expect(onLinksChange).toHaveBeenCalledTimes(1);
  expect(onLinksChange).toHaveBeenLastCalledWith([
    { url: 'https://e.com', label: 'e', title: '' },
  ]);
});
