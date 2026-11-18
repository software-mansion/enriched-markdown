/**
 * @jest-environment node
 */
// A WASM that fails to load renders the raw markdown. The load fails the same
// way again, so later parses don't retry it.
import { renderToString } from 'react-dom/server';

const mockCreateModule = jest.fn(() =>
  Promise.reject(new Error('CompileError'))
);
jest.mock('../wasm/md4c', () => ({
  __esModule: true,
  default: mockCreateModule,
}));

delete (globalThis as { window?: unknown }).window;

const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

it('renders the raw markdown without retrying the load', async () => {
  const consoleError = jest.spyOn(console, 'error').mockImplementation();

  for (const markdown of ['**Hello**', '**Hello again**']) {
    expect(
      renderToString(<EnrichedMarkdownText markdown={markdown} />)
    ).toMatch(/<pre[^>]*>\*\*Hello( again)?\*\*<\/pre>/);
  }
  expect(mockCreateModule).toHaveBeenCalledTimes(1);

  // The cause is only known once the factory's promise rejects.
  await Promise.resolve();
  expect(consoleError).toHaveBeenCalledWith(
    expect.stringContaining('WASM parser failed to load'),
    expect.objectContaining({ message: 'CompileError' })
  );
  consoleError.mockRestore();
});
