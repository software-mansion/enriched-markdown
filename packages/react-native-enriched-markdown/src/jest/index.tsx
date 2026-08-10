/**
 * Jest mock for `react-native-enriched-markdown`, wired up via
 * `jest.mock('react-native-enriched-markdown', () => require('react-native-enriched-markdown/jest'))`.
 * See docs/TESTING.md for setup and the behavior it mirrors.
 *
 * The two components are Fabric/codegen native views: under Jest there is no
 * native view manager, so rendering them or calling any imperative ref method
 * (each dispatches a native command) throws. These replacements render plain RN
 * primitives and expose every imperative method as a spy.
 *
 * Behavior mirrored from the native component: typing fires `onChangeText` and,
 * when set, `onChangeMarkdown` (the raw text stands in for parsed markdown);
 * `setValue()` updates the rendered text but emits no change events, matching
 * the native suppression of emits for programmatic updates.
 *
 * The mock is typed against the real public types, so `yarn typecheck` fails if
 * the API gains a prop or ref method the mock does not cover -- it cannot
 * silently drift from the real component.
 */
import { useImperativeHandle, useRef, useState } from 'react';
import type { ComponentRef } from 'react';
import { Text, TextInput } from 'react-native';
import type {
  CaretRect,
  EnrichedMarkdownTextInputInstance,
  EnrichedMarkdownTextInputProps,
} from '../EnrichedMarkdownTextInput';
import type { EnrichedMarkdownTextProps } from '../native/EnrichedMarkdownText';

export {
  DEFAULT_ACCESSIBILITY_LABELS,
  resolveAccessibilityLabels,
} from '../accessibilityLabelDefaults';

type AnyFn = (...args: any[]) => any;
declare const jest: { fn: <T extends AnyFn>(impl?: T) => T };

const spy = <T extends AnyFn>(impl?: T): T => jest.fn(impl);

const EMPTY_CARET_RECT: CaretRect = { x: 0, y: 0, width: 0, height: 0 };

export const EnrichedMarkdownTextInput = ({
  ref,
  defaultValue,
  onChangeText,
  onChangeMarkdown,
  onFocus,
  onBlur,
  editable = true,
  placeholder,
  placeholderTextColor,
  autoFocus = false,
  multiline = true,
  scrollEnabled = true,
  style,
  testID,
  accessible,
  accessibilityLabel,
  accessibilityHint,
  accessibilityRole,
  accessibilityState,
  nativeID,
  markdownStyle: _markdownStyle,
  cursorColor: _cursorColor,
  selectionColor: _selectionColor,
  autoCapitalize: _autoCapitalize,
  onChangeSelection: _onChangeSelection,
  onChangeState: _onChangeState,
  onKeyPress: _onKeyPress,
  onCaretRectChange: _onCaretRectChange,
  onLinkDetected: _onLinkDetected,
  mentionIndicators: _mentionIndicators,
  onStartMention: _onStartMention,
  onChangeMention: _onChangeMention,
  onEndMention: _onEndMention,
  contextMenuItems: _contextMenuItems,
  selectionMenuConfig: _selectionMenuConfig,
  formatMenuConfig: _formatMenuConfig,
  linkRegex: _linkRegex,
  writingDirection: _writingDirection,
}: EnrichedMarkdownTextInputProps) => {
  const [text, setText] = useState(defaultValue ?? '');
  const textRef = useRef(text);
  const inputRef = useRef<ComponentRef<typeof TextInput> | null>(null);

  const applyText = (next: string) => {
    textRef.current = next;
    setText(next);
  };

  const handleChangeText = (next: string) => {
    applyText(next);
    onChangeText?.(next);
    onChangeMarkdown?.(next);
  };

  const instanceRef = useRef<EnrichedMarkdownTextInputInstance | null>(null);
  if (instanceRef.current === null) {
    instanceRef.current = {
      focus: spy(() => inputRef.current?.focus()),
      blur: spy(() => inputRef.current?.blur()),
      measure: spy((callback) => callback(0, 0, 0, 0, 0, 0)),
      measureInWindow: spy((callback) => callback(0, 0, 0, 0)),
      measureLayout: spy((_relativeToNativeNode, onSuccess) =>
        onSuccess(0, 0, 0, 0)
      ),
      setValue: spy((markdown: string) => applyText(markdown)),
      setSelection: spy((_start: number, _end: number) => {}),
      toggleBold: spy(() => {}),
      toggleItalic: spy(() => {}),
      toggleUnderline: spy(() => {}),
      toggleStrikethrough: spy(() => {}),
      toggleSpoiler: spy(() => {}),
      toggleHeading: spy((_level) => {}),
      toggleUnorderedList: spy(() => {}),
      toggleOrderedList: spy(() => {}),
      indentList: spy(() => {}),
      outdentList: spy(() => {}),
      setLink: spy((_url: string) => {}),
      insertLink: spy((_text: string, _url: string) => {}),
      insertText: spy((_text: string) => {}),
      insertMention: spy((_displayText: string, _url: string) => {}),
      startMention: spy((_indicator: string) => {}),
      removeLink: spy(() => {}),
      copyToClipboard: spy(() => {}),
      getMarkdown: spy(() => Promise.resolve(textRef.current)),
      getCaretRect: spy(() => Promise.resolve(EMPTY_CARET_RECT)),
    };
  }

  useImperativeHandle(ref, () => instanceRef.current!);

  return (
    <TextInput
      ref={inputRef}
      value={text}
      onChangeText={handleChangeText}
      onFocus={() => onFocus?.()}
      onBlur={() => onBlur?.()}
      editable={editable}
      placeholder={placeholder}
      placeholderTextColor={placeholderTextColor}
      autoFocus={autoFocus}
      multiline={multiline}
      scrollEnabled={scrollEnabled}
      style={style}
      testID={testID}
      accessible={accessible}
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityRole={accessibilityRole}
      accessibilityState={accessibilityState}
      nativeID={nativeID}
    />
  );
};

export const EnrichedMarkdownText = ({
  markdown,
  containerStyle,
  testID,
  accessible,
  accessibilityLabel,
  accessibilityHint,
  accessibilityRole,
  accessibilityState,
  nativeID,
  markdownStyle: _markdownStyle,
  onLinkPress: _onLinkPress,
  onLinkLongPress: _onLinkLongPress,
  onTaskListItemPress: _onTaskListItemPress,
  enableLinkPreview: _enableLinkPreview,
  selectable: _selectable,
  md4cFlags: _md4cFlags,
  allowFontScaling: _allowFontScaling,
  maxFontSizeMultiplier: _maxFontSizeMultiplier,
  allowTrailingMargin: _allowTrailingMargin,
  flavor: _flavor,
  streamingAnimation: _streamingAnimation,
  streamingConfig: _streamingConfig,
  spoilerOverlay: _spoilerOverlay,
  contextMenuItems: _contextMenuItems,
  imageRequestHeaders: _imageRequestHeaders,
  selectionMenuConfig: _selectionMenuConfig,
  accessibilityLabels: _accessibilityLabels,
  selectionColor: _selectionColor,
  selectionHandleColor: _selectionHandleColor,
  textBreakStrategy: _textBreakStrategy,
  lineBreakStrategyIOS: _lineBreakStrategyIOS,
  writingDirection: _writingDirection,
}: EnrichedMarkdownTextProps) => {
  return (
    <Text
      style={containerStyle}
      testID={testID}
      accessible={accessible}
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityRole={accessibilityRole}
      accessibilityState={accessibilityState}
      nativeID={nativeID}
    >
      {markdown}
    </Text>
  );
};
