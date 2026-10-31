/**
 * @jest-environment jsdom
 */
// With `suspense`, hydrating a server render keeps its HTML until the WASM
// has loaded in the browser too, then takes it over as is (#1110).
import { Suspense, useEffect } from 'react';
import { hydrateRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';
import { isParserReady } from '../parseMarkdown';

// jsdom has no TextEncoder, which the block collector reads at module load.
globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
// Not the package entry: it also loads the input, which preloads the parser.
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

// Whether the WASM was loaded at each render, and called once hydrated.
let renders: boolean[] = [];
let onHydrated = () => {};

function Spy() {
  renders.push(isParserReady());
  useEffect(() => onHydrated(), []);
  return null;
}

// Hydrated without `act`, which would only render once the WASM has loaded.
(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = false;

const app = (
  <Suspense fallback="Loading">
    <Spy />
    <EnrichedMarkdownText markdown="**Hello**" suspense />
  </Suspense>
);

// The server's HTML, rendered by a module registry of its own, whose WASM has
// loaded: this file's has not.
let serverHtml = '';

beforeAll(() =>
  jest.isolateModulesAsync(async () => {
    const parser =
      require('../parseMarkdown') as typeof import('../parseMarkdown');
    await parser.loadParser();
    // The browser build needs a MessageChannel, which jsdom lacks.
    const { renderToString } =
      require('react-dom/server.node') as typeof import('react-dom/server');
    const isolated =
      require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');
    serverHtml = renderToString(
      <Suspense fallback="Loading">
        <isolated.EnrichedMarkdownText markdown="**Hello**" suspense />
      </Suspense>
    );
  })
);

let container: HTMLDivElement;
let root: Root | undefined;

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
});

afterEach(() => {
  root?.unmount();
  container.remove();
});

it('keeps the server HTML until the WASM has loaded', async () => {
  expect(serverHtml).toContain('<strong');
  expect(isParserReady()).toBe(false);
  container.innerHTML = serverHtml;
  const strong = container.querySelector('strong');
  const errors: unknown[] = [];

  renders = [];
  const hydrated = new Promise<void>((resolve) => {
    onHydrated = resolve;
  });

  root = hydrateRoot(container, app, {
    onRecoverableError: (error) => errors.push(error),
  });
  await hydrated;

  // Hydrated before the WASM had loaded: it suspended, then took the server's
  // HTML over as is, the same `<strong>` rather than one of its own.
  expect(renders[0]).toBe(false);
  expect(isParserReady()).toBe(true);
  expect(errors).toEqual([]);
  expect(container.querySelector('strong')).toBe(strong);
  expect(container.textContent).toBe('Hello');
});
