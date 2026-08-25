import type { CSSProperties, HTMLAttributes } from 'react';
import type { MarkdownStyle, Md4cFlags } from './MarkdownStyle';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
} from './events';

export interface EnrichedMarkdownTextProps extends Omit<
  HTMLAttributes<HTMLDivElement>,
  'style' | 'dir'
> {
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
  containerStyle?: CSSProperties;
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
   * On web the checkbox keeps its normal appearance and is marked
   * `readOnly` / `aria-disabled` rather than `disabled`, so it stays visually
   * consistent with iOS and Android. It is also made pointer-inert
   * (`pointer-events: none`) so the browser cannot paint hover or active
   * states on a checkbox that cannot be toggled.
   *
   * @default true
   * @platform ios, android, web
   */
  enableTaskListItemToggle?: boolean;
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
   * @platform web
   */
  selectionColor?: string;
  /**
   * When false (default), removes trailing margin from the last element to
   * eliminate bottom spacing.
   * When true, keeps the trailing margin from the last element's marginBottom style.
   * @default false
   * @platform ios, android, web
   */
  allowTrailingMargin?: boolean;
  /**
   * Sets the text direction on the root container.
   * Useful for RTL languages — CSS logical properties in the renderers
   * automatically flip blockquote borders, list indentation, etc.
   * @platform web
   */
  dir?: 'ltr' | 'rtl' | 'auto';
}
