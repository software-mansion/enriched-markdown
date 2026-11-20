// A bundle without a usable default export, as a bundler that loads md4c.js as
// an ES module saw before it had one: the load throws inside the import chain.
jest.mock('../wasm/md4c', () => ({ __esModule: true, default: undefined }));

import { loadParser, parseMarkdown, preloadParser } from '../parseMarkdown';

describe('a parser that fails to load', () => {
  let consoleError: jest.SpyInstance;

  beforeEach(() => {
    consoleError = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleError.mockRestore();
  });

  it('logs the failure once, even when every caller drops the error', async () => {
    await preloadParser();
    await expect(loadParser()).rejects.toThrow(TypeError);
    await expect(parseMarkdown('# Title')).rejects.toThrow(TypeError);

    expect(consoleError).toHaveBeenCalledTimes(1);
    expect(consoleError).toHaveBeenCalledWith(
      expect.stringContaining('WASM markdown parser failed to load'),
      expect.any(TypeError)
    );
  });
});
