import { act, createRef } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownTextInput, EnrichedMarkdownText } from '../src/jest';
import type { EnrichedMarkdownTextInputInstance } from '../src/EnrichedMarkdownTextInput';

const INSTANCE_METHODS: (keyof EnrichedMarkdownTextInputInstance)[] = [
  'focus',
  'blur',
  'measure',
  'measureInWindow',
  'measureLayout',
  'setValue',
  'setSelection',
  'toggleBold',
  'toggleItalic',
  'toggleUnderline',
  'toggleStrikethrough',
  'toggleSpoiler',
  'toggleHeading',
  'toggleUnorderedList',
  'toggleOrderedList',
  'indentList',
  'outdentList',
  'setLink',
  'insertLink',
  'insertMention',
  'startMention',
  'removeLink',
  'copyToClipboard',
  'getMarkdown',
  'getCaretRect',
];

function renderMock(element: ReactElement) {
  const root: Root = createRoot({ textComponentTypes: ['Text', 'TextInput'] });
  act(() => {
    root.render(element);
  });
  const byTestId = (testID: string): TestInstance => {
    const [match] = root.container.queryAll((i) => i.props.testID === testID);
    if (!match) throw new Error(`No element found with testID "${testID}"`);
    return match;
  };
  return { root, byTestId };
}

describe('EnrichedMarkdownTextInput mock', () => {
  it('renders a queryable TextInput seeded with defaultValue', () => {
    const { byTestId } = renderMock(
      <EnrichedMarkdownTextInput testID="input" defaultValue="hello" />
    );
    expect(byTestId('input').props.value).toBe('hello');
  });

  it('emits onChangeText and onChangeMarkdown on user input', () => {
    const onChangeText = jest.fn();
    const onChangeMarkdown = jest.fn();
    const { byTestId } = renderMock(
      <EnrichedMarkdownTextInput
        testID="input"
        onChangeText={onChangeText}
        onChangeMarkdown={onChangeMarkdown}
      />
    );

    act(() => {
      byTestId('input').props.onChangeText('typed');
    });

    expect(onChangeText).toHaveBeenCalledWith('typed');
    expect(onChangeMarkdown).toHaveBeenCalledWith('typed');
    expect(byTestId('input').props.value).toBe('typed');
  });

  it('setValue updates the rendered value without emitting change events', () => {
    const onChangeText = jest.fn();
    const onChangeMarkdown = jest.fn();
    const ref = createRef<EnrichedMarkdownTextInputInstance>();
    const { byTestId } = renderMock(
      <EnrichedMarkdownTextInput
        ref={ref}
        testID="input"
        onChangeText={onChangeText}
        onChangeMarkdown={onChangeMarkdown}
      />
    );

    act(() => {
      ref.current!.setValue('**programmatic**');
    });

    expect(byTestId('input').props.value).toBe('**programmatic**');
    expect(onChangeText).not.toHaveBeenCalled();
    expect(onChangeMarkdown).not.toHaveBeenCalled();
    expect(ref.current!.setValue).toHaveBeenCalledWith('**programmatic**');
  });

  it('exposes every imperative method as a spy', () => {
    const ref = createRef<EnrichedMarkdownTextInputInstance>();
    renderMock(<EnrichedMarkdownTextInput ref={ref} />);

    for (const method of INSTANCE_METHODS) {
      expect(jest.isMockFunction(ref.current![method])).toBe(true);
    }

    act(() => {
      ref.current!.toggleBold();
      ref.current!.insertMention('Ada', 'user://ada');
    });
    expect(ref.current!.toggleBold).toHaveBeenCalledTimes(1);
    expect(ref.current!.insertMention).toHaveBeenCalledWith(
      'Ada',
      'user://ada'
    );
  });

  it('resolves async ref methods with sensible values', async () => {
    const ref = createRef<EnrichedMarkdownTextInputInstance>();
    renderMock(<EnrichedMarkdownTextInput ref={ref} defaultValue="seed" />);

    await expect(ref.current!.getMarkdown()).resolves.toBe('seed');
    act(() => {
      ref.current!.setValue('next');
    });
    await expect(ref.current!.getMarkdown()).resolves.toBe('next');
    await expect(ref.current!.getCaretRect()).resolves.toEqual({
      x: 0,
      y: 0,
      width: 0,
      height: 0,
    });
  });
});

describe('EnrichedMarkdownText mock', () => {
  it('renders its markdown as plain text', () => {
    const { byTestId } = renderMock(
      <EnrichedMarkdownText testID="display" markdown="# Title" />
    );
    expect(byTestId('display').children).toContain('# Title');
  });

  it('renders links as pressable elements with role "link"', () => {
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        markdown="Click [here](https://example.com) for info"
        onLinkPress={jest.fn()}
      />
    );
    const link = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'link'
    )[0];
    expect(link).toBeDefined();
    expect(link!.children).toContain('here');
  });

  it('calls onLinkPress with the url when a link is pressed', () => {
    const onLinkPress = jest.fn();
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        markdown="See [docs](https://docs.example.com/path)"
        onLinkPress={onLinkPress}
      />
    );
    const link = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'link'
    )[0]!;

    act(() => {
      link.props.onPress();
    });

    expect(onLinkPress).toHaveBeenCalledWith({
      url: 'https://docs.example.com/path',
    });
  });

  it('calls onLinkLongPress with the url when a link is long-pressed', () => {
    const onLinkLongPress = jest.fn();
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        markdown="[link](https://example.com)"
        onLinkLongPress={onLinkLongPress}
      />
    );
    const link = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'link'
    )[0]!;

    act(() => {
      link.props.onLongPress();
    });

    expect(onLinkLongPress).toHaveBeenCalledWith({
      url: 'https://example.com',
    });
  });

  it('strips inline formatting from link text', () => {
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        markdown="[**bold link**](https://example.com)"
        onLinkPress={jest.fn()}
      />
    );
    const link = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'link'
    )[0]!;
    expect(link.children).toContain('bold link');
  });

  it('renders plain text when no onLinkPress is provided (no transform)', () => {
    const { byTestId } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        markdown="See [docs](https://example.com)"
      />
    );
    const links = byTestId('display').queryAll(
      (i) => i.props.accessibilityRole === 'link'
    );
    expect(links).toHaveLength(0);
    expect(byTestId('display').children).toContain(
      'See [docs](https://example.com)'
    );
  });

  it('renders task list items as pressable checkboxes', () => {
    const onTaskListItemPress = jest.fn();
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        flavor="github"
        markdown={'- [ ] Buy milk\n- [x] Write code'}
        onTaskListItemPress={onTaskListItemPress}
      />
    );
    const checkboxes = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'checkbox'
    );
    expect(checkboxes).toHaveLength(2);
    expect(checkboxes[0]!.props.accessibilityState).toEqual({ checked: false });
    expect(checkboxes[1]!.props.accessibilityState).toEqual({ checked: true });
  });

  it('calls onTaskListItemPress with toggled state on checkbox press', () => {
    const onTaskListItemPress = jest.fn();
    const { root } = renderMock(
      <EnrichedMarkdownText
        testID="display"
        flavor="github"
        markdown={'- [ ] First task\n- [x] Second task'}
        onTaskListItemPress={onTaskListItemPress}
      />
    );
    const checkboxes = root.container.queryAll(
      (i) => i.props.accessibilityRole === 'checkbox'
    );

    act(() => {
      checkboxes[0]!.props.onPress();
    });

    expect(onTaskListItemPress).toHaveBeenCalledWith({
      index: 0,
      checked: true,
      text: 'First task',
    });

    act(() => {
      checkboxes[1]!.props.onPress();
    });

    expect(onTaskListItemPress).toHaveBeenCalledWith({
      index: 1,
      checked: false,
      text: 'Second task',
    });
  });
});
