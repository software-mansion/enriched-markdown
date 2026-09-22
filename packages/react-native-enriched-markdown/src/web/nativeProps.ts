/**
 * Props that form the native (iOS/Android) EnrichedMarkdownText API but have no
 * effect on web.
 *
 * In a typical React Native + react-native-web project the component is
 * type-checked against the native `MarkdownTextProps.ts` interface (bundlers
 * swap in `.web.tsx` at runtime, but `tsc` resolves the base `.ts` unless the
 * project sets `moduleSuffixes`). So JSX like `flavor="github"` or
 * `streamingAnimation` compiles fine and would otherwise be spread onto the
 * root DOM element, triggering React "unknown prop" warnings. They are dropped
 * here before reaching the DOM.
 *
 * This list mirrors the library's own public API. Generic React Native
 * ViewProps (nativeID, accessibility*, hitSlop, etc.) are a broader
 * react-native-web concern and are intentionally out of scope.
 */
const NATIVE_ONLY_PROP_NAMES = [
  'onCopyPress',
  'onLatexError',
  'enableBlockContextMenu',
  'enableLinkPreview',
  'selectionHandleColor',
  'allowFontScaling',
  'maxFontSizeMultiplier',
  'flavor',
  'streamingAnimation',
  'streamingConfig',
  'spoilerOverlay',
  'contextMenuItems',
  'imageRequestHeaders',
  'selectionMenuConfig',
  'accessibilityLabels',
  'textBreakStrategy',
  'lineBreakStrategyIOS',
  'writingDirection',
  'numberOfLines',
  'ellipsizeMode',
] as const;

type NativeOnlyPropName = (typeof NATIVE_ONLY_PROP_NAMES)[number];

const NATIVE_ONLY_PROPS = new Set<string>(NATIVE_ONLY_PROP_NAMES);

/**
 * Removes native-only props so they are never forwarded to a DOM element.
 * Returns a shallow copy; the input is left untouched.
 */
export function filterNativeOnlyProps<T extends object>(
  props: T
): Omit<T, NativeOnlyPropName> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(props)) {
    if (!NATIVE_ONLY_PROPS.has(key)) {
      result[key] = value;
    }
  }
  return result as Omit<T, NativeOnlyPropName>;
}
