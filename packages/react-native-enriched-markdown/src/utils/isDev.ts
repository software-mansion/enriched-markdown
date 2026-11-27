// `__DEV__` is a React Native global; web bundlers (Vite, Next) don't define
// it, so a bare read throws a ReferenceError there. Read it through this
// constant instead (lint enforces it).
export const isDev = typeof __DEV__ !== 'undefined' && __DEV__;
