/**
 * @jest-environment jsdom
 */
// Hydrating a server render keeps its HTML as is (#1110): the browser's first
// render parses too, loading the WASM on the way.
import { act } from 'react';
import { hydrateRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';

// jsdom has no TextEncoder, which the block collector reads at module load.
globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

// Rendered by a module registry of its own, so this file's WASM is still
// unloaded when hydrating, as in a browser.
function renderOnServer(markdown: string): string {
  let html = '';
  jest.isolateModules(() => {
    // The browser build needs a MessageChannel, which jsdom lacks.
    const { renderToString } =
      require('react-dom/server.node') as typeof import('react-dom/server');
    const server =
      require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');
    html = renderToString(<server.EnrichedMarkdownText markdown={markdown} />);
  });
  return html;
}

it('hydrates the server HTML without replacing it', () => {
  const container = document.createElement('div');
  container.innerHTML = renderOnServer('**Hello**');
  const strong = container.querySelector('strong');
  expect(strong).not.toBeNull();
  const errors: unknown[] = [];

  let root!: Root;
  act(() => {
    root = hydrateRoot(
      container,
      <EnrichedMarkdownText markdown="**Hello**" />,
      { onRecoverableError: (error) => errors.push(error) }
    );
  });

  expect(errors).toEqual([]);
  expect(container.querySelector('strong')).toBe(strong);
  act(() => root.unmount());
});
