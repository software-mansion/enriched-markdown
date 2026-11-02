/**
 * @jest-environment jsdom
 */
import { preloadParser } from '../../../parseMarkdown';
import { caretAt, mount, typeText } from './inputHostKit';

function nextTask(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('parser warm-up', () => {
  it('starts when the input component is declared', () => {
    jest.isolateModules(() => {
      const preload = jest.fn(() => Promise.resolve());
      jest.doMock('../../../parseMarkdown', () => ({
        parseMarkdown: jest.fn(),
        preloadParser: preload,
      }));
      require('../../../../EnrichedMarkdownTextInput.web');
      expect(preload).toHaveBeenCalledTimes(1);
    });
    jest.dontMock('../../../parseMarkdown');
  });

  // A keystroke is a task of its own, so with the parser ready the import has
  // landed before it arrives instead of holding the editor inert.
  it('lets an import settle before the next keystroke', async () => {
    await preloadParser();
    const { root, host } = mount();
    root.focus();
    const importing = host.importValue('**bold**');

    await nextTask();
    expect(host.value).toBe('bold');
    caretAt(root, 4);
    typeText(root, '!');
    expect(host.value).toBe('bold!');
    await importing;
  });
});
