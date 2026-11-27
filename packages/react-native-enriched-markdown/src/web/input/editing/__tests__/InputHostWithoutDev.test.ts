/**
 * @jest-environment jsdom
 */

// Vite and Next define no `__DEV__`; the React Native jest setup does, so the
// test removes it before the editor modules load.
describe('without a __DEV__ global', () => {
  const globals = globalThis as { __DEV__?: boolean };
  const saved = globals.__DEV__;

  beforeEach(() => {
    delete globals.__DEV__;
  });

  afterEach(() => {
    globals.__DEV__ = saved;
  });

  it('treats the build as production', () => {
    jest.isolateModules(() => {
      const { isDev } = require('../../../../utils/isDev');
      expect(isDev).toBe(false);
    });
  });

  it('accepts typing', () => {
    jest.isolateModules(() => {
      // Web builds alias `react-native` to react-native-web; the real package
      // reads `__DEV__` itself.
      jest.doMock('react-native', () => ({
        Platform: { OS: 'web' },
        processColor: (color: unknown) => color,
      }));
      const kit = require('./inputHostKit');
      const { root, host } = kit.mount();
      root.focus();
      kit.caretAt(root, 0);
      expect(() => kit.typeText(root, 'a')).not.toThrow();
      expect(host.value).toBe('a');
    });
    jest.dontMock('react-native');
  });
});
