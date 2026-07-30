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
});
