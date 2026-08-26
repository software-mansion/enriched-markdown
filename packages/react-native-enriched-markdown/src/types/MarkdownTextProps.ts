import type { ColorValue, ViewProps, ViewStyle, TextStyle } from 'react-native';
import type { MarkdownStyle, Md4cFlags } from './MarkdownStyle';
import type { AccessibilityLabels } from './AccessibilityLabels';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  CopyPressEvent,
} from './events';

/**
 * Public context menu item. Each item includes a JS-side `onPress` callback
 * that is called when the user taps the item in the selection context menu.
 */
export interface ContextMenuItem {
  text: string;
  onPress: (event: {
    text: string;
    selection: { start: number; end: number };
  }) => void;
  icon?: string;
  visible?: boolean;
}

/**
 * Plural forms for the "Copy Image URL(s)" action, keyed by CLDR plural
 * category. The right form is chosen at runtime from the number of selected
 * images using `Intl.PluralRules` (resolved against the app's default locale).
 *
 * Each value is a template where the `{count}` token is replaced with the
 * number of selected images. Only `other` is required by CLDR; any category
 * left `undefined` falls back to `other`.
 *
 * @example
 * // Polish: one / few / many / other
 * pluralLabels: {
 *   one: 'Kopiuj adres URL obrazu',
 *   few: 'Kopiuj adresy URL {count} obrazów',
 *   many: 'Kopiuj adresy URL {count} obrazów',
 *   other: 'Kopiuj adresy URL {count} obrazu',
 * }
 */
export interface SelectionMenuPluralLabels {
  /**
   * Required base form. Any category left `undefined` falls back to `other`,
   * so the menu never shows the English default once `pluralLabels` is set.
   */
  other: string;
  zero?: string;
  one?: string;
  two?: string;
  few?: string;
  many?: string;
}

/**
 * Controls the built-in items added to the native text selection menu and
 * lets you localize their labels.
 *
 * Each item accepts an object: `{ enabled }` toggles visibility (the system
 * `copy` item can't be hidden — only relabeled) and `label` overrides the
 * English default. Wire `label` to your i18n library to match the rest of your
 * app's UI. Labels apply to the main text selection menu as well as the table
 * and math block copy menus.
 *
 * @platform ios, android, macos
 */
export interface SelectionMenuConfig {
  /**
   * The system "Copy" item. It can't be hidden — only its label is configurable.
   * @default { label: "Copy" }
   */
  copy?: { label?: string };
  /**
   * The built-in "Copy as Markdown" action for text selections.
   * @default { enabled: true, label: "Copy as Markdown" }
   */
  copyAsMarkdown?: { enabled?: boolean; label?: string };
  /**
   * The built-in "Copy Image URL" action, shown when the selection contains
   * images. `label` is used for a single image; `pluralLabels` provides the
   * forms for multiple images.
   * @default { enabled: true, label: "Copy Image URL" }
   */
  copyImageUrl?: {
    enabled?: boolean;
    label?: string;
    pluralLabels?: SelectionMenuPluralLabels;
  };
}

export interface StreamingConfig {
  /**
   * Controls how incomplete tables are handled during streaming.
   * - `'hidden'`: hide the entire table until it's complete.
   * - `'progressive'` (default): show the table row-by-row as rows complete.
   * Only effective when `streamingAnimation` is `true`.
   * @default 'progressive'
   * @platform ios, android
   */
  tableMode?: 'hidden' | 'progressive';
  /**
   * Controls how a fenced code block whose closing fence has not arrived yet
   * is handled during streaming.
   * - `'hidden'`: hide the entire code block until its closing fence arrives.
   * - `'progressive'` (default): show the code as it streams in with its header
   *   visible but non-interactive (copying is disabled); syntax highlighting is
   *   deferred until the closing fence arrives, so it appears once atomically.
   * Only effective when `streamingAnimation` is `true`.
   * @default 'progressive'
   * @platform ios, android
   */
  codeBlockMode?: 'hidden' | 'progressive';
}

export interface EnrichedMarkdownTextProps extends Omit<ViewProps, 'style'> {
  /**
   * Markdown content to render.
   * @platform ios, android, web
   */
  markdown: string;
  /**
   * Style configuration for markdown elements.
   * @platform ios, android, web
   */
  markdownStyle?: MarkdownStyle;
  /**
   * Style for the container view.
   * @platform ios, android, web
   */
  containerStyle?: ViewStyle | TextStyle;
  /**
   * MD4C parser flags configuration.
   * Controls how the markdown parser interprets certain syntax.
   * @platform ios, android, web
   */
  md4cFlags?: Md4cFlags;
  /**
   * Callback fired when a link is pressed.
   * Receives the link URL directly.
   * @platform ios, android, web
   */
  onLinkPress?: (event: LinkPressEvent) => void;
  /**
   * Callback fired when a link is long pressed.
   * Receives the link URL directly.
   * - iOS: When provided, automatically disables the system link preview
   *   (unless `enableLinkPreview` is explicitly set to `true`).
   * - Android: Handles long press gestures on links.
   * - Web: Mapped to the `contextmenu` event (right-click).
   * @platform ios, android, web
   */
  onLinkLongPress?: (event: LinkLongPressEvent) => void;
  /**
   * Callback fired when a task list checkbox is tapped.
   *
   * The checkbox is toggled on the native side automatically.
   * Receives the 0-based task index, the new checked state (after toggling),
   * and the item's plain text.
   *
   * Only fires when `flavor="github"` (GFM task lists require GitHub flavor).
   * @platform ios, android, web
   */
  onTaskListItemPress?: (event: TaskListItemPressEvent) => void;
  /**
   * Controls whether tapping a task list checkbox toggles its checked state.
   *
   * When `true` (default), tapping the checkbox toggles it and fires
   * `onTaskListItemPress`. When `false`, the checkbox renders its markdown
   * state read-only: the tap is fully inert — no visual toggle and no
   * `onTaskListItemPress` emission. Text selection and links in the same row
   * are unaffected.
   *
   * @default true
   * @platform ios, android, web
   */
  enableTaskListItemToggle?: boolean;
  /**
   * Callback fired when code is copied from a fenced code block, via the header
   * copy button, the long-press context-menu "Copy" action, or the VoiceOver
   * copy action. Receives the copied code and its language. Does not fire for
   * "Copy as Markdown".
   *
   * Only fires when `flavor="github"` (the copy button is part of the GitHub
   * flavor's container-based code block renderer).
   * @platform ios, android, macos
   */
  onCopyPress?: (event: CopyPressEvent) => void;
  /**
   * Controls whether the system link preview is shown on long press (iOS only).
   *
   * When `true`, long-pressing a link shows the native iOS link preview.
   * When `false`, the system preview is suppressed.
   *
   * Defaults to `true`, but automatically becomes `false` when `onLinkLongPress`
   * is provided. Set explicitly to override the automatic behavior.
   *
   * @default true
   * @platform ios
   */
  enableLinkPreview?: boolean;
  /**
   * Controls text selection.
   * - iOS: Controls text selection and link previews on long press.
   * - Android: Controls text selection.
   * - Web: Applies `user-select: none` when `false`.
   * @default true
   * @platform ios, android, web
   */
  selectable?: boolean;
  /**
   * Color of the text selection highlight.
   *
   * On iOS, this also affects the caret and selection handle colors
   * (they share a single tint). On macOS, only the selection background
   * is affected.
   *
   * @platform ios, android, macos, web
   */
  selectionColor?: ColorValue;
  /**
   * Color of the selection handles (drag anchors).
   * No-op on API levels below 29.
   *
   * @platform android
   */
  selectionHandleColor?: ColorValue;
  /**
   * Specifies whether fonts should scale to respect Text Size accessibility settings.
   * When false, text will not scale with the user's accessibility settings.
   * @default true
   * @platform ios, android
   */
  allowFontScaling?: boolean;
  /**
   * Specifies the largest possible scale a font can reach when `allowFontScaling`
   * is enabled.
   * - `undefined` / `null` (default): no limit
   * - `0`: no limit
   * - `>= 1`: sets the maxFontSizeMultiplier of this node to this value
   * @default undefined
   * @platform ios, android
   */
  maxFontSizeMultiplier?: number;
  /**
   * When false (default), removes trailing margin from the last element to
   * eliminate bottom spacing.
   * When true, keeps the trailing margin from the last element's marginBottom style.
   * @default false
   * @platform ios, android, web
   */
  allowTrailingMargin?: boolean;
  /**
   * Specifies which Markdown flavor to use for rendering.
   * - `'commonmark'` (default): standard CommonMark renderer (single TextView).
   * - `'github'`: GitHub Flavored Markdown — container-based renderer with
   *   support for tables and other GFM extensions.
   * @default 'commonmark'
   * @platform ios, android
   */
  flavor?: 'commonmark' | 'github';
  /**
   * When true, newly appended content fades in during streaming updates.
   * Only the tail (new characters beyond the previous content) is animated.
   * Recommended for LLM streaming use cases with `flavor="commonmark"`.
   * @default false
   * @platform ios, android
   */
  streamingAnimation?: boolean;
  /**
   * Fine-grained control over streaming behavior for block-level elements.
   * Only effective when `streamingAnimation` is `true`.
   * @platform ios, android
   */
  streamingConfig?: StreamingConfig;
  /**
   * Controls how spoiler text is displayed before being revealed.
   * - `'particles'` (default): animated particle overlay (CAEmitterLayer on iOS,
   *   Choreographer-driven Canvas particles on Android).
   * - `'solid'`: opaque rectangle covering the text (Discord-style).
   *
   * Both modes support tap-to-reveal.
   * @default 'particles'
   * @platform ios, android
   */
  spoilerOverlay?: 'particles' | 'solid';
  /**
   * Custom items to show in the text selection context menu.
   * Each item requires a `text` label and an `onPress` callback.
   * Items with `visible: false` are hidden from the menu.
   * @platform ios, android
   */
  contextMenuItems?: ContextMenuItem[];
  /**
   * HTTP headers to attach to remote image requests, e.g. a `Referer`
   * required by CDN hotlink protection or an `Authorization` token.
   *
   * Headers participate in image cache identity, so the same URL requested
   * with different headers is fetched and cached separately.
   *
   * Not supported on web — browsers don't allow custom headers on `<img>`
   * requests.
   * @platform ios, android
   */
  imageRequestHeaders?: Record<string, string>;
  /**
   * Controls the built-in items added to the native text selection menu and
   * lets you localize their labels. Custom app-provided actions are controlled
   * separately with `contextMenuItems`.
   * @default { copyAsMarkdown: { enabled: true }, copyImageUrl: { enabled: true } }
   * @platform ios, android, macos
   */
  selectionMenuConfig?: SelectionMenuConfig;
  /**
   * Translations for VoiceOver / TalkBack announcements (list items, table
   * rows, math, and the iOS rotor). All keys are optional and fall back to
   * the English defaults from `accessibilityLabelDefaults.ts` — see
   * `AccessibilityLabels` for the placeholder syntax and the no-plural
   * rationale.
   * @platform ios, android
   */
  accessibilityLabels?: AccessibilityLabels;
  /**
   * Sets the text direction on the root container.
   * Useful for RTL languages — CSS logical properties in the renderers
   * automatically flip blockquote borders, list indentation, etc.
   * @platform web
   */
  dir?: 'ltr' | 'rtl' | 'auto';
  /**
   * Sets the text break strategy on Android (API 23+).
   * - `'simple'`: no hyphenation, minimal line-break work.
   * - `'highQuality'` (default): full paragraph optimization with hyphenation.
   * - `'balanced'`: balances line lengths, no hyphenation.
   *
   * Both the measurement pass and the render pass use this value so that
   * measured line counts match rendered line counts.
   * @default 'highQuality'
   * @platform android
   */
  textBreakStrategy?: 'simple' | 'highQuality' | 'balanced';
  /**
   * Sets the line break strategy on iOS (iOS 14+).
   * - `'none'` (default): no additional line break strategy.
   * - `'standard'`: standard line breaking rules.
   * - `'hangul-word'`: Korean word-boundary breaking.
   * - `'push-out'`: pushes text out to avoid orphaned words.
   * @default 'none'
   * @platform ios
   */
  lineBreakStrategyIOS?: 'none' | 'standard' | 'hangul-word' | 'push-out';
  /**
   * Paragraph writing direction.
   * - `'first-strong'` (default): resolves each paragraph from its first strong
   *   directional character. Neutral-only paragraphs fall back to the view's
   *   resolved layout direction (inherits ancestor `direction` style). Library
   *   extension beyond React Native — matches Android's `TEXT_DIRECTION_FIRST_STRONG`.
   * - `'auto'`: React Native parity. iOS TextKit follows the app's
   *   `userInterfaceLayoutDirection`; mixed-direction paragraphs do not
   *   auto-resolve.
   * - `'ltr'` / `'rtl'`: force base direction on every paragraph. Code blocks
   *   always stay LTR.
   * @default 'first-strong'
   * @platform ios
   */
  writingDirection?: 'auto' | 'ltr' | 'rtl' | 'first-strong';
}
