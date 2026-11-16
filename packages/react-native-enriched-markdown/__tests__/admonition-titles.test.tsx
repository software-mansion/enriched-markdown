import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

it('sends the titles to native in a stable markdownStyle', () => {
  const root = createRoot({
    textComponentTypes: ['EnrichedMarkdownTextNativeComponent'],
  });
  const render = () =>
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown="x"
          admonitionTitles={{
            warning: 'Achtung\n',
            tip: '',
            caution: 'Prze\nstroga',
          }}
        />
      )
    );
  const style = () =>
    root.container.queryAll((instance) =>
      String(instance.type).startsWith('EnrichedMarkdown')
    )[0]!.props.markdownStyle;

  render();
  const first = style();
  render();

  expect(style()).toBe(first);
  // The header draws one line, so line breaks become spaces.
  expect(first.blockquote.admonitions.warning.title).toBe('Achtung');
  expect(first.blockquote.admonitions.caution.title).toBe('Prze stroga');
  expect(first.blockquote.admonitions.tip.title).toBe('');
  expect(first.blockquote.admonitions.note.title).toBe('Note');
});
