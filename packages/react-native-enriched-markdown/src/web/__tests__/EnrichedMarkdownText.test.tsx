/**
 * @jest-environment jsdom
 */
// Every commit must already show the markdown it was given (#1082): a
// virtualized list measures rows in layout effects, and a recycled row must
// not show the previous item. Driven through react-dom with the real WASM.
import { act, useLayoutEffect, useRef } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';

// jsdom has no TextEncoder, which the block collector reads at module load.
globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
// Required, not imported, so that it loads after the polyfill above.
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

// The first case runs before anything has loaded the WASM: the parse that
// loads it is the one in the first render.
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
