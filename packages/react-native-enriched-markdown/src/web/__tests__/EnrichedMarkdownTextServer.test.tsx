/**
 * @jest-environment node
 */
// A server render has the markdown (#1110): the WASM loads synchronously on
// the first parse, so no render waits for it.
import { renderToString } from 'react-dom/server';

// The React Native jest setup aliases `window` to the global; a server
// runtime has none.
delete (globalThis as { window?: unknown }).window;

const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

it('renders the markdown with renderToString', () => {
  const html = renderToString(<EnrichedMarkdownText markdown="**Hello**" />);

  expect(html).toContain('<strong');
  expect(html).toContain('Hello');
});
