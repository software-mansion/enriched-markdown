/**
 * @jest-environment jsdom
 */
// md4c ignores a "_" between two word characters, so underline can't start or
// end inside a word: turning it on there takes the whole word.
import {
  lastState,
  mount,
  selectRangeFocused,
  sendInput,
  styledText,
  typeText,
} from './inputHostKit';

afterEach(() => {
  document.body.replaceChildren();
});

function underline(text: string, start: number, end = start) {
  const mounted = mount();
  typeText(mounted.root, text);
  selectRangeFocused(mounted.root, start, end);
  mounted.host.toggleUnderline();
  return mounted;
}

describe('turning underline on inside a word', () => {
  it('underlines the whole word from a caret', () => {
    const { root, markdowns, selections, states } = underline(
      'an underline here',
      6
    );

    expect(markdowns.at(-1)).toBe('an _underline_ here');
    expect(styledText(root, 'underline')).toEqual(['underline']);
    expect(selections.at(-1)).toEqual({ start: 6, end: 6 });
    expect(lastState(states).underline.isActive).toBe(true);
  });

  it('keeps what is typed next inside the underlined word', () => {
    const { root, markdowns } = underline('underline', 5);
    typeText(root, 'X');

    expect(markdowns.at(-1)).toBe('_underXline_');
  });

  it('grows a selection inside a word to the word', () => {
    const { markdowns } = underline('an underline here', 5, 8);

    expect(markdowns.at(-1)).toBe('an _underline_ here');
  });

  it('grows both edges of a selection across words', () => {
    const { markdowns } = underline('foo bar baz', 1, 6);

    expect(markdowns.at(-1)).toBe('_foo bar_ baz');
  });

  it('leaves a selection of whole words as it is', () => {
    const { markdowns } = underline('foo bar baz', 4, 7);

    expect(markdowns.at(-1)).toBe('foo _bar_ baz');
  });

  it('does not grow a selection starting at a space', () => {
    const { markdowns } = underline('foo bar', 3, 7);

    expect(markdowns.at(-1)).toBe('foo _bar_');
  });

  it('stops at punctuation', () => {
    const { markdowns } = underline('foo(bar)', 4, 7);

    expect(markdowns.at(-1)).toBe('foo(_bar_)');
  });

  it('takes the word at its end and keeps typing into it', () => {
    const { root, markdowns } = underline('text', 4);
    typeText(root, 'underline');

    expect(markdowns.at(-1)).toBe('_textunderline_');
  });

  it('takes the word at its start and keeps typing into it', () => {
    const { root, markdowns } = underline('text', 0);
    typeText(root, 'pre');

    expect(markdowns.at(-1)).toBe('_pretext_');
  });

  it('reads back the stacked styles from #1036', () => {
    const { root, host, markdowns } = mount();
    host.toggleBold();
    typeText(root, 'bold text');
    host.toggleItalic();
    typeText(root, 'italic text');
    host.toggleUnderline();
    typeText(root, 'underline');

    expect(markdowns.at(-1)).toBe('**bold text*italic _textunderline_***');
  });

  it('grows over letters typed at the start of an underlined word', () => {
    const { root, markdowns } = underline('bergef', 3);
    selectRangeFocused(root, 0, 0);
    typeText(root, 'mn');

    expect(markdowns.at(-1)).toBe('_mnbergef_');
    expect(styledText(root, 'underline')).toEqual(['mnbergef']);
  });

  it('grows over letters typed right after an underlined word', () => {
    const { root, markdowns } = underline('foo bar', 4, 7);
    selectRangeFocused(root, 7, 7);
    typeText(root, 's');

    expect(markdowns.at(-1)).toBe('foo _bars_');
  });

  it('turns underline off for the whole word from a caret', () => {
    const { root, host, markdowns } = underline('an underline here', 6);
    host.toggleUnderline();

    expect(markdowns.at(-1)).toBe('an underline here');
    expect(styledText(root, 'underline')).toEqual([]);
  });

  it('turns underline off for the whole word from a selection', () => {
    const { root, host, markdowns } = underline('an underline here', 3, 12);
    selectRangeFocused(root, 5, 8);
    host.toggleUnderline();

    expect(markdowns.at(-1)).toBe('an underline here');
  });

  it('keeps letters typed after turning it off at the word end plain', () => {
    const { root, host, markdowns } = underline('text', 4);
    host.toggleUnderline();
    typeText(root, 's more');

    expect(markdowns.at(-1)).toBe('texts more');
  });

  it('still pends at a caret after a space', () => {
    const { root, markdowns } = underline('foo ', 4);
    typeText(root, 'bar');

    expect(markdowns.at(-1)).toBe('foo _bar_');
  });

  it('is one undo step', () => {
    const { host, markdowns } = underline('underline', 5);
    host.undo();

    expect(markdowns.at(-1)).toBe('underline');
  });
});

describe('a caret at the edge of an underlined word', () => {
  // Letters typed there join the word, so the state shows underline and one
  // toggle takes it off the whole word.
  it('shows underline at the end of the word and grows over typing', () => {
    const { root, states, markdowns } = underline('hello', 3);
    selectRangeFocused(root, 5, 5);

    expect(lastState(states).underline.isActive).toBe(true);
    typeText(root, 'xy');
    expect(markdowns.at(-1)).toBe('_helloxy_');
    expect(lastState(states).underline.isActive).toBe(true);
  });

  it('shows underline when a deletion leaves the caret at the word end', () => {
    const { root, host, states, markdowns } = mount();
    typeText(root, 'hello ');
    selectRangeFocused(root, 0, 5);
    host.toggleUnderline();
    selectRangeFocused(root, 6, 6);
    expect(lastState(states).underline.isActive).toBe(false);
    sendInput(root, 'deleteContentBackward');

    expect(lastState(states).underline.isActive).toBe(true);
    typeText(root, 'x');
    expect(markdowns.at(-1)).toBe('_hellox_');
  });

  it('keeps the word and stops what follows with one toggle at the end', () => {
    const { root, host, states, markdowns } = underline('on web', 0, 6);
    selectRangeFocused(root, 6, 6);
    host.toggleUnderline();

    expect(markdowns.at(-1)).toBe('_on web_');
    expect(lastState(states).underline.isActive).toBe(false);
    typeText(root, ' x');
    expect(markdowns.at(-1)).toBe('_on web_ x');
    expect(lastState(states).underline.isActive).toBe(false);
  });

  it('lets a letter typed right after turning it off join the word', () => {
    const { root, host, states, markdowns } = underline('hello', 3);
    selectRangeFocused(root, 5, 5);
    host.toggleUnderline();
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('_hellox_');
    expect(lastState(states).underline.isActive).toBe(true);
  });

  it('keeps the word with one toggle at the start', () => {
    const { root, host, states, markdowns } = underline('hello', 3);
    selectRangeFocused(root, 0, 0);

    expect(lastState(states).underline.isActive).toBe(true);
    host.toggleUnderline();
    expect(markdowns.at(-1)).toBe('_hello_');
    expect(lastState(states).underline.isActive).toBe(false);
    typeText(root, 'a');
    expect(markdowns.at(-1)).toBe('_ahello_');
    expect(lastState(states).underline.isActive).toBe(true);
  });

  it('only pends when turned on at the end of a plain word', () => {
    const { root, host, states, markdowns } = mount();
    typeText(root, 'hello');
    host.toggleUnderline();

    expect(markdowns.at(-1)).toBe('hello');
    expect(lastState(states).underline.isActive).toBe(true);
    typeText(root, ' world');
    expect(markdowns.at(-1)).toBe('hello _world_');
  });

  it('shows no underline past a space or punctuation', () => {
    const { root, states, markdowns } = underline('foo! bar', 0, 3);
    selectRangeFocused(root, 4, 4);
    expect(lastState(states).underline.isActive).toBe(false);
    selectRangeFocused(root, 5, 5);
    expect(lastState(states).underline.isActive).toBe(false);
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('_foo_! xbar');
  });
});

describe('growing next to other styles', () => {
  // Growth never changes an underline whose markdown reads back: another
  // style's delimiter between the "_" and a letter already separates them.
  async function mountWith(markdown: string) {
    const mounted = mount();
    await mounted.host.setValue(markdown);
    return mounted;
  }

  it('leaves an underline away from the edit alone', async () => {
    const { root, markdowns } = await mountWith('*foo*_bar_ baz');
    selectRangeFocused(root, 10, 10);
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('*foo*_bar_ bazx');
  });

  it('stops at an italic word ending where the underline starts', async () => {
    const { root, markdowns, states } = await mountWith('*foo*_bar_');
    selectRangeFocused(root, 6, 6);
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('*foo*_barx_');
    expect(styledText(root, 'underline')).toEqual(['barx']);
    expect(lastState(states).underline.isActive).toBe(true);
  });

  it('stops at a bold word starting where the underline ends', async () => {
    const { root, markdowns } = await mountWith('_foo_**bar**');
    selectRangeFocused(root, 0, 0);
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('_xfoo_**bar**');
  });

  it('stops at a link ending where the underline starts', async () => {
    const { root, markdowns } = await mountWith('[foo](https://e.com)_bar_');
    selectRangeFocused(root, 6, 6);
    typeText(root, 'x');

    expect(markdowns.at(-1)).toBe('[foo](https://e.com)_barx_');
  });

  it('keeps an underline nested inside a link mid-word', async () => {
    const { root, host, markdowns } = await mountWith(
      'foo[bar](https://e.com)'
    );
    selectRangeFocused(root, 3, 6);
    host.toggleUnderline();

    expect(markdowns.at(-1)).toBe('foo[_bar_](https://e.com)');
  });

  it('grows over the word once the italic between is gone', async () => {
    const { root, host, markdowns, states } = await mountWith('*foo*_bar_');
    selectRangeFocused(root, 0, 3);
    host.toggleItalic();

    expect(markdowns.at(-1)).toBe('_foobar_');
    expect(lastState(states).underline.isActive).toBe(true);
  });
});

describe('clearing the value', () => {
  // A chat input sends by calling setValue(""): the underline pending at the
  // old caret must not style the next message.
  it('drops the underline pending at the caret', async () => {
    const { root, host, states, markdowns } = underline('hello', 3);
    expect(lastState(states).underline.isActive).toBe(true);

    await host.setValue('');
    expect(lastState(states).underline.isActive).toBe(false);
    typeText(root, 'next');
    expect(markdowns.at(-1)).toBe('next');
  });
});
