/**
 * @jest-environment jsdom
 */
// Every commit must already show the markdown it was given (#1082): a
// virtualized list measures rows in layout effects, and a recycled row must
// not show the previous item. Driven through react-dom with the real WASM.
import { act, useLayoutEffect, useRef } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';
import {
  isParserReady,
  loadParser,
  subscribeParserReady,
} from '../parseMarkdown';

// jsdom has no TextEncoder, which the block collector reads at module load.
globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
// Not the package entry: it also loads the input, which preloads the parser.
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

// What the DOM held when each commit's layout effects ran.
function Probe({
  markdown,
  latexMath,
  commits,
}: {
  markdown: string;
  latexMath?: boolean;
  commits: string[];
}) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    commits.push(ref.current?.textContent ?? '');
  });
  return (
    <div ref={ref}>
      <EnrichedMarkdownText markdown={markdown} md4cFlags={{ latexMath }} />
    </div>
  );
}

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
});

// Runs first: the parser is module state, loaded once for the whole file.
it('renders nothing until the first WASM load, then the markdown', async () => {
  expect(isParserReady()).toBe(false);
  const commits: string[] = [];

  act(() => root.render(<Probe markdown="Hello" commits={commits} />));
  expect(commits).toEqual(['']);

  // The component starts the load itself, so only wait for it to land. Only
  // the markdown re-renders then, not the probe.
  await act(
    () =>
      new Promise<void>((resolve) => {
        const unsubscribe = subscribeParserReady(() => {
          unsubscribe();
          resolve();
        });
      })
  );
  expect(container.textContent).toBe('Hello');
});

describe('once the WASM has loaded', () => {
  beforeAll(() => loadParser());

  it.each([true, false])(
    'shows the markdown in the first commit (latexMath: %s)',
    (latexMath) => {
      const commits: string[] = [];

      act(() =>
        root.render(
          <Probe markdown="Hello" latexMath={latexMath} commits={commits} />
        )
      );

      expect(commits).toEqual(['Hello']);
    }
  );

  it('shows the new markdown in the commit that changes it', () => {
    const commits: string[] = [];

    act(() => root.render(<Probe markdown="Row A" commits={commits} />));
    act(() => root.render(<Probe markdown="Row B" commits={commits} />));
    act(() => root.render(<Probe markdown="Row A" commits={commits} />));

    expect(commits).toEqual(['Row A', 'Row B', 'Row A']);
  });
});
