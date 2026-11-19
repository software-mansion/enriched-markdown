import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

it('sends the titles to native in their own stable prop, not the style', () => {
  const root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  const render = () =>
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown="x"
          flavor="github"
          admonitionTitles={{
            warning: 'Achtung\n',
            tip: '',
            caution: 'Prze\nstroga',
          }}
        />
      )
    );
  const props = () =>
    root.container.queryAll((instance) =>
      String(instance.type).startsWith('EnrichedMarkdown')
    )[0]!.props;

  render();
  const first = props().admonitionTitles;
  render();

  expect(props().admonitionTitles).toBe(first);
  // The header draws one line, so line breaks become spaces.
  expect(first).toEqual({
    note: 'Note',
    tip: '',
    important: 'Important',
    warning: 'Achtung',
    caution: 'Prze stroga',
  });
  expect(props().markdownStyle.blockquote.admonitions.note).not.toHaveProperty(
    'title'
  );
});
