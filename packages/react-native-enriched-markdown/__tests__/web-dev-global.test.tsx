// Web bundlers (Vite, Next) don't define React Native's `__DEV__`, and alias react-native to
// react-native-web, which doesn't read it either.
const dev = (global as { __DEV__?: boolean }).__DEV__;
beforeEach(() => {
  delete (global as { __DEV__?: boolean }).__DEV__;
  jest.resetModules();
  jest.doMock('react-native', () => ({
    processColor: (color: unknown) => color,
  }));
});
afterEach(() => {
  (global as { __DEV__?: boolean }).__DEV__ = dev;
});

it('mounts a view without a stream when __DEV__ is not defined', () => {
  const { renderToStaticMarkup } = require('react-dom/server');
  const { useMarkdownStreamSnapshot } = require('../src/markdownStream');
  const View = ({ stream }: { stream?: unknown }) => {
    useMarkdownStreamSnapshot(stream);
    return null;
  };
  expect(() => renderToStaticMarkup(<View />)).not.toThrow();
  expect(() => renderToStaticMarkup(<View stream={{}} />)).not.toThrow();
});

it('takes an unknown streaming animation when __DEV__ is not defined', () => {
  const { normalizeStreamingAnimation } = require('../src/streamingAnimation');
  expect(normalizeStreamingAnimation('typewriter').animation).toBe('none');
});
