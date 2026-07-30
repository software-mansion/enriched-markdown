/**
 * Jest mock for `react-native-enriched-markdown`.
 *
 * `EnrichedMarkdownTextInput` and `EnrichedMarkdownText` are Fabric/codegen
 * native components. Under Jest there is no native view manager, so rendering
 * them or invoking any imperative ref method (which dispatches a native
 * command) throws. This module provides drop-in replacements that render plain
 * React Native primitives and expose every imperative method as a spy, so
 * consumer screens that embed the input can be rendered and asserted with React
 * Native Testing Library.
 *
 * Wire it up once, in your jest setup file:
 *
 *   jest.mock('react-native-enriched-markdown', () =>
 *     require('react-native-enriched-markdown/jest'),
 *   );
 *
 * The mock is authored against the library's real public types
 * (`EnrichedMarkdownTextInputProps`, `EnrichedMarkdownTextInputInstance`,
 * `EnrichedMarkdownTextProps`), so `yarn typecheck` fails if the API gains a
 * prop or ref method the mock does not cover. That is the anti-drift guarantee:
 * the mock cannot silently fall behind the real component.
 *
 * Semantics that mirror the native component:
 * - Typing in the rendered `TextInput` fires `onChangeText` and, when a handler
 *   is provided, `onChangeMarkdown`. The mock cannot parse markdown, so it
 *   forwards the raw text to `onChangeMarkdown` as a stand-in.
 * - `setValue()` updates the rendered text (so the programmatic value is
 *   observable) but emits no change events, matching the native side's
 *   suppression of emits for programmatic updates (`blockEmitting`).
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

// The `jest` global is always present when this module is loaded (it only runs
// inside `jest.mock(...)`). We declare a minimal shape rather than depend on
// `@types/jest` so the package typecheck stays free of test-runner types.
type AnyFn = (...args: any[]) => any;
declare const jest: { fn: <T extends AnyFn>(impl?: T) => T };

// Returns a Jest spy wrapping `impl` so tests can assert calls while the spy
// still performs the mock's real behavior (e.g. `setValue` updating text).
const spy = <T extends AnyFn>(impl?: T): T => jest.fn(impl);

const EMPTY_CARET_RECT: CaretRect = { x: 0, y: 0, width: 0, height: 0 };

export const EnrichedMarkdownTextInput = ({
  ref,
  defaultValue,
  onChangeText,
  onChangeMarkdown,
  onFocus,
  onBlur,
  editable,
  placeholder,
  placeholderTextColor,
  autoFocus,
  multiline,
  scrollEnabled,
  style,
  testID,
  accessible,
  accessibilityLabel,
  accessibilityHint,
  accessibilityRole,
  accessibilityState,
  nativeID,
  // Enriched-only props with no plain-TextInput equivalent are intentionally
  // dropped so they are not forwarded onto the underlying RN TextInput.
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
  // Kept in sync with `text` so `getMarkdown()` resolves the latest value
  // without a stale closure.
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

  // Build the instance (and its spies) once and reuse it across renders. State
  // setters and refs are stable, so the closures stay valid, and the spy
  // identities persist so tests can assert call counts even after a `setValue`
  // triggers a re-render.
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
  // Consumer callbacks and rendering options have no effect in the mock; they
  // are dropped so they are not forwarded onto the underlying RN Text.
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

export default EnrichedMarkdownTextInput;
