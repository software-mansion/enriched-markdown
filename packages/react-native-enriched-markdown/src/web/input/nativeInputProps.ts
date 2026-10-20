import type { ViewProps } from 'react-native';
import type { EnrichedMarkdownTextInputProps as NativeInputProps } from '../../EnrichedMarkdownTextInput';
import type { EnrichedMarkdownTextInputProps as WebInputProps } from '../../EnrichedMarkdownTextInput.web';

/**
 * Props of the native (iOS/Android) EnrichedMarkdownTextInput API that have
 * no effect on web, dropped before the rest is spread onto the editor's
 * `<div>` (review §2.8.2): otherwise React warns about each one, and values
 * like `markdownstyle="[object Object]"` land in the DOM.
 *
 * As in `nativeProps.ts`, the set is derived rather than hand-maintained: the
 * native prop names minus those web implements and minus generic ViewProps, so
 * a native-only prop added to `EnrichedMarkdownTextInput.tsx` fails the build
 * here until it is listed. The React Native press props the native input takes
 * from TextInput fall in that set too; `hitSlop` (a ViewProp) is listed by hand
 * because it reaches the DOM as an invalid attribute just the same.
 *
 * Every import here is type-only, so nothing from `react-native` reaches the
 * web bundle.
 */
type NativeOnlyInputPropName = Exclude<
  keyof NativeInputProps,
  keyof WebInputProps | keyof ViewProps
>;

// The index signature keeps this compiling where the native prop type cannot
// be told apart from the web one: under a `.web` module suffix (an app's
// tsconfig) the import above resolves to the web file and the derived set is
// empty. The library's own build still requires every derived name.
const NATIVE_ONLY_INPUT_PROP_NAMES: Record<
  NativeOnlyInputPropName | 'hitSlop',
  true
> &
  Record<string, true> = {
  ref: true,
  scrollEnabled: true,
  markdownShortcuts: true,
  multiline: true,
  markdownStyle: true,
  onCaretRectChange: true,
  onLinkDetected: true,
  mentionIndicators: true,
  onStartMention: true,
  onChangeMention: true,
  onEndMention: true,
  contextMenuItems: true,
  selectionMenuConfig: true,
  formatMenuConfig: true,
  linkRegex: true,
  writingDirection: true,
  onPress: true,
  onPressIn: true,
  onPressOut: true,
  rejectResponderTermination: true,
  hitSlop: true,
};

const NATIVE_ONLY_INPUT_PROPS = new Set<string>(
  Object.keys(NATIVE_ONLY_INPUT_PROP_NAMES)
);

// A shallow copy of `props` without the native-only ones.
export function filterNativeOnlyInputProps<T extends object>(
  props: T
): Omit<T, NativeOnlyInputPropName | 'hitSlop'> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(props)) {
    if (!NATIVE_ONLY_INPUT_PROPS.has(key)) {
      result[key] = value;
    }
  }
  return result as Omit<T, NativeOnlyInputPropName | 'hitSlop'>;
}
