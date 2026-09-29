import { act } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import {
  toNativeRegexConfig,
  toNativeTextLinkRegexConfig,
} from '../src/utils/regexParser';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

const renderNative = (element: ReactElement): TestInstance => {
  const root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  act(() => root.render(element));
  const [native] = root.container.queryAll((instance) =>
    String(instance.type).startsWith('EnrichedMarkdown')
  );
  if (!native) throw new Error('Missing native markdown view');
  return native;
};

it.each(['commonmark', 'github'] as const)(
  'disables both recognizers by default in %s',
  (flavor) => {
    const native = renderNative(
      <EnrichedMarkdownText markdown="ref:one `ref:two`" flavor={flavor} />
    );
    expect(native.props.linkRegex.isDisabled).toBe(true);
    expect(native.props.inlineCodeLinkRegex.isDisabled).toBe(true);
  }
);

it.each(['commonmark', 'github'] as const)(
  'normalizes independent regex props without rewriting the source in %s',
  (flavor) => {
    const markdown = 'ref:one [ref:two](https://example.com) `ref:three`';
    const native = renderNative(
      <EnrichedMarkdownText
        markdown={markdown}
        flavor={flavor}
        linkRegex={/ref:\w+/gims}
        inlineCodeLinkRegex={/ref:[\w-]+/i}
      />
    );
    expect(native.props.markdown).toBe(markdown);
    expect(native.props.linkRegex).toEqual({
      pattern: 'ref:\\w+',
      caseInsensitive: true,
      dotAll: true,
      isDisabled: false,
      isDefault: false,
    });
    expect(native.props.inlineCodeLinkRegex).toEqual({
      pattern: 'ref:[\\w-]+',
      caseInsensitive: true,
      dotAll: false,
      isDisabled: false,
      isDefault: false,
    });
  }
);

it('null and undefined disable rendering recognition, leaving input defaults intact', () => {
  expect(toNativeTextLinkRegexConfig(null).isDisabled).toBe(true);
  expect(toNativeTextLinkRegexConfig(undefined).isDisabled).toBe(true);
  expect(toNativeRegexConfig(undefined).isDefault).toBe(true);
});

it('uses the existing variable-width lookbehind rejection without enabling fallback detection', () => {
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  try {
    expect(toNativeTextLinkRegexConfig(/(?<=a+)ref:\w+/).isDisabled).toBe(true);
    expect(error).toHaveBeenCalled();
  } finally {
    error.mockRestore();
  }
});

it('ignores JavaScript execution state and only transports supported i/s options', () => {
  const regex = /ref:\w+/dgmy;
  regex.lastIndex = 14;
  expect(toNativeTextLinkRegexConfig(regex)).toEqual({
    pattern: 'ref:\\w+',
    caseInsensitive: false,
    dotAll: false,
    isDisabled: false,
    isDefault: false,
  });
  expect(regex.lastIndex).toBe(14);
});
