export interface LinkPressEvent {
  url: string;
}

export interface LinkLongPressEvent {
  url: string;
}

export interface ImagePressEvent {
  url: string;
  altText: string;
}

export interface TextPressEvent {
  /** UTF-16 index of the tapped character within `text`. */
  index: number;
  /** The rendered text of the tapped block. */
  text: string;
}

/** The part of the rendered text that one block shows. */
export interface RenderedTextBlock {
  /** UTF-16 offset in the rendered text where the block starts. */
  start: number;
  /** UTF-16 offset where the block ends (exclusive). */
  end: number;
  /**
   * `text` for prose (paragraphs, headings, lists, quotes), `code` for a
   * fenced code block, `table` for a table.
   */
  kind: 'text' | 'code' | 'table';
}

export interface RenderedTextChangeEvent {
  /**
   * The text as the view shows it, which differs from the Markdown source.
   * `highlights` offsets index into it. Blocks are joined with `\n`.
   */
  text: string;
  /** The blocks in document order. */
  blocks: RenderedTextBlock[];
}

/** Where a highlight shows, in the component's coordinates. */
export interface HighlightRect {
  /** The highlight's index in `highlights`. */
  index: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface HighlightLayoutEvent {
  /** One rect for each highlight that shows, in `highlights` order. */
  highlights: HighlightRect[];
}

export interface TaskListItemPressEvent {
  index: number;
  checked: boolean;
  text: string;
}

export interface CopyPressEvent {
  code: string;
  language: string;
}

export interface CodeBlockPressEvent {
  code: string;
  language: string;
}

/**
 * Event payload fired when a text selection is copied from the native
 * selection menu, with the keyboard shortcut, or through TalkBack.
 */
export interface SelectionCopyEvent {
  /** What was put on the clipboard as plain text. */
  text: string;
  /**
   * How it was copied: `'plain'` for Copy and for keyboard or TalkBack copies,
   * `'markdown'` for Copy as Markdown, `'imageUrls'` for Copy Image URL(s).
   */
  format: 'plain' | 'markdown' | 'imageUrls';
  /**
   * The copied range, in UTF-16 offsets of the rendered text. With
   * `flavor="github"` the offsets restart at each block that renders as its own
   * view, such as a table, code block or quote, so consecutive paragraphs count
   * as one run of text.
   */
  selection: { start: number; end: number };
}

/**
 * Event payload fired when a math expression fails to parse or render.
 *
 * The whole expression is the unit of failure: the LaTeX engine either renders
 * an expression in full or rejects it, so there is no single offending command
 * to report. Consumers can classify `source` themselves (e.g. report it to an
 * error tracker) without maintaining an allowlist that goes stale on engine
 * upgrades.
 */
export interface LatexErrorEvent {
  /** Raw LaTeX of the failing expression, without `$`/`$$` delimiters. */
  source: string;
  /** Engine error message, when one is available. */
  message?: string;
  /** `false` for inline `$...$`, `true` for block `$$...$$`. */
  displayMode: boolean;
}

/** A link menu item as sent to native: no callback, every field set. */
export interface LinkContextMenuItemConfig {
  text: string;
  icon: string;
  disabled: boolean;
  destructive: boolean;
}

/** The menu items for links whose URL matches `pattern`. */
export interface LinkContextMenuItemsConfig {
  pattern: string;
  items: ReadonlyArray<Readonly<LinkContextMenuItemConfig>>;
}

/** `pattern` is the entry that supplied the menu, so JS finds the item without matching again. */
export interface OnLinkContextMenuItemPressEvent {
  url: string;
  pattern: string;
  itemText: string;
}

/**
 * Native-level context menu item config sent to the native component.
 * Does not include the `onPress` callback — callbacks are managed on the JS side.
 */
export interface ContextMenuItemConfig {
  text: string;
  icon?: string;
}

/**
 * Event payload fired by the native component when a context menu item is pressed.
 */
export interface OnContextMenuItemPressEvent {
  itemText: string;
  selectedText: string;
  selectionStart: number;
  selectionEnd: number;
}
