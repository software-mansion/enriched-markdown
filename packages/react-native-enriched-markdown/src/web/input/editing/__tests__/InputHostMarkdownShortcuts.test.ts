/**
 * @jest-environment jsdom
 */
import { normalizeMarkdownShortcuts } from '../../../../normalizeMarkdownShortcuts';
import { lastState, mount, sendInput, typeText } from './inputHostKit';

// One `beforeinput` per character, as a keyboard sends them.
function typeKeys(root: HTMLElement, text: string): void {
  for (const char of text) {
    typeText(root, char);
  }
}

function mountWithShortcuts(config: unknown = true) {
  const mounted = mount();
  mounted.host.setMarkdownShortcuts(normalizeMarkdownShortcuts(config));
  return mounted;
}

describe('InputHost markdown shortcuts', () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it('keeps a typed prefix as text when off, the default', () => {
    const { root, host } = mount();
    typeKeys(root, '## Title');

    expect(host.value).toBe('## Title');
    expect(host.getMarkdown()).toBe('\\## Title');
  });

  it.each([
    ['# ', '# Title', 1],
    ['### ', '### Title', 3],
    ['###### ', '###### Title', 6],
  ])('turns %j into a heading', (prefix, markdown, level) => {
    const { root, host, states } = mountWithShortcuts();
    typeKeys(root, `${prefix}Title`);

    expect(host.value).toBe('Title');
    expect(host.getMarkdown()).toBe(markdown);
    expect(lastState(states).heading).toEqual({ isActive: true, level });
  });

  it.each(['- ', '* ', '+ '])('turns %j into a bullet item', (prefix) => {
    const { root, host } = mountWithShortcuts();
    typeKeys(root, `${prefix}item`);

    expect(host.value).toBe('item');
    expect(host.getMarkdown()).toBe('- item');
  });

  it.each(['1. ', '3) ', '42. '])('turns %j into a numbered item', (prefix) => {
    const { root, host } = mountWithShortcuts();
    typeKeys(root, `${prefix}item`);

    expect(host.value).toBe('item');
    expect(host.getMarkdown()).toBe('1. item');
  });

  it('leaves the caret where the typed text continues', () => {
    const { root, host, selections } = mountWithShortcuts();
    typeKeys(root, '- ');

    expect(host.value).toBe('');
    expect(selections.at(-1)).toEqual({ start: 0, end: 0 });
    typeKeys(root, 'ab');
    expect(host.getMarkdown()).toBe('- ab');
  });

  it('converts the line the space is typed on, not only the first', () => {
    const { root, host } = mountWithShortcuts();
    typeKeys(root, 'intro');
    sendInput(root, 'insertParagraph');
    typeKeys(root, '- item');

    expect(host.value).toBe('intro\nitem');
    expect(host.getMarkdown()).toBe('intro\n- item');
  });

  it('enables only the families a config names', () => {
    const { root, host } = mountWithShortcuts({ heading: true });
    typeKeys(root, '- item');

    expect(host.value).toBe('- item');
    expect(host.getMarkdown()).toBe('\\- item');
  });

  it.each([
    ['a prefix after text', 'a # b'],
    ['a leading space', ' # b'],
    ['seven hashes', '####### b'],
    ['hashes followed by text', '#a b'],
    ['a ten-digit number', '1234567890. b'],
    ['a bare number', '12 b'],
  ])('ignores %s', (_label, typed) => {
    const { root, host } = mountWithShortcuts();
    typeKeys(root, typed);

    expect(host.value).toBe(typed);
  });

  it('does not convert inside a line that is already a block', () => {
    const { root, host } = mountWithShortcuts();
    typeKeys(root, '# - item');

    expect(host.value).toBe('- item');
    expect(host.getMarkdown()).toBe('# \\- item');
  });

  it('brings the typed prefix back as text with one undo', () => {
    const { root, host, states } = mountWithShortcuts();
    typeKeys(root, '## ');
    expect(host.value).toBe('');

    host.undo();
    expect(host.value).toBe('## ');
    expect(lastState(states).heading.isActive).toBe(false);

    host.redo();
    expect(host.value).toBe('');
    expect(lastState(states).heading).toEqual({ isActive: true, level: 2 });
  });

  it('stops converting once switched off', () => {
    const { root, host } = mountWithShortcuts();
    host.setMarkdownShortcuts(normalizeMarkdownShortcuts(false));
    typeKeys(root, '# Title');

    expect(host.value).toBe('# Title');
  });
});
