/**
 * @jest-environment node
 */
// With `suspense`, a server render waits for the WASM and renders the
// markdown, instead of nothing (#1110).
import { Suspense } from 'react';
import { prerenderToNodeStream } from 'react-dom/static';

// The React Native jest setup aliases `window` to the global; a server
// runtime has none.
delete (globalThis as { window?: unknown }).window;

const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

async function renderOnServer(element: React.ReactNode): Promise<string> {
  const { prelude } = await prerenderToNodeStream(element);
  let html = '';
  for await (const chunk of prelude) {
    html += chunk;
  }
  return html;
}

it('renders the markdown with suspense', async () => {
  const html = await renderOnServer(
    <Suspense fallback="Loading">
      <EnrichedMarkdownText markdown="**Hello**" suspense />
    </Suspense>
  );

  expect(html).toContain('<strong');
  expect(html).toContain('Hello');
  expect(html).not.toContain('Loading');
});
