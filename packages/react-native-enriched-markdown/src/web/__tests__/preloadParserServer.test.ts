/**
 * @jest-environment node
 */
jest.mock('../wasm/md4c', () => ({
  __esModule: true,
  default: jest.fn(() => new Promise(() => {})),
}));

import createModule from '../wasm/md4c';
import { preloadParser } from '../parseMarkdown';

describe('preloadParser without a window', () => {
  // The React Native jest setup aliases `window` to the global; a server
  // runtime has none.
  beforeEach(() => {
    delete (globalThis as { window?: unknown }).window;
  });

  it('does not load the WASM', async () => {
    await preloadParser();
    expect(createModule).not.toHaveBeenCalled();
  });
});
