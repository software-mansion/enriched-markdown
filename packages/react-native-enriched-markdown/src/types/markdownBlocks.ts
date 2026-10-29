import type { ReactElement } from 'react';

/**
 * The container a replaceable block sits in directly: the document itself, a
 * blockquote, or an admonition (`> [!NOTE]`). Inside a blockquote or an
 * admonition the block is narrower and indented, so a renderer may size or
 * style its element differently there.
 */
export type MarkdownBlockPlacement = 'root' | 'blockquote' | 'admonition';

/** Shared by every block a `renderers` entry can replace. */
export interface MarkdownSlotBlock {
  /**
   * An opaque string, the same on every platform. It stays the same while the
   * block is unchanged, across streaming appends and edits elsewhere in the
   * document, so it is safe as a React key. Do not parse it.
   */
  id: string;
  placement: MarkdownBlockPlacement;
}

export interface MarkdownMediaBlock extends MarkdownSlotBlock {
  url: string;
}

/** A paragraph whose only content is an image. */
export interface MarkdownImageBlock extends MarkdownMediaBlock {
  kind: 'image';
  /** The Markdown alt text, `""` when there is none. */
  altText: string;
  /** The Markdown title, `""` when there is none. */
  title: string;
  /**
   * The id of this image's `MarkdownImageOccurrence`, the one
   * `resolveImageSource` is asked about. Block ids and occurrence ids are never
   * equal, so one map can hold both.
   */
  occurrenceId: string;
}

/** A `<video src="...">` block. */
export interface MarkdownVideoBlock extends MarkdownMediaBlock {
  kind: 'video';
}

/**
 * A paragraph whose only content is a link: `[label](url)`, an autolink or a
 * bare URL on a line of its own. The hook for file cards, embeds and previews.
 */
export interface MarkdownLinkBlock extends MarkdownMediaBlock {
  kind: 'link';
  /** The link text, `""` for a bare URL or autolink. */
  label: string;
  /** The Markdown title, `""` when there is none. */
  title: string;
}

/**
 * A fenced or indented code block. Its id depends on the language only, so it
 * stays the same while the code streams in and when the fence closes; the
 * element re-renders in place with the new `code`.
 */
export interface MarkdownCodeBlock extends MarkdownSlotBlock {
  kind: 'code';
  /** The fence's language (` ```ts ` gives `"ts"`), `""` when it has none. */
  language: string;
  /** The code, without trailing newlines. */
  code: string;
  /**
   * `false` while the closing fence has not streamed in yet (with
   * `streamingAnimation` and `codeBlockMode: 'progressive'`), `true` otherwise.
   */
  isComplete: boolean;
}

/** Every block a `renderers` entry can replace, for code that handles any kind. */
export type MarkdownBlock =
  | MarkdownImageBlock
  | MarkdownVideoBlock
  | MarkdownLinkBlock
  | MarkdownCodeBlock;

export type MarkdownCodeBlockRenderer = (
  block: MarkdownCodeBlock
) => ReactElement | undefined;

/** A renderer for the code blocks whose language matches `pattern`. */
export interface MarkdownCodeLanguageRenderer {
  /**
   * Matched against the fence language. A string is compiled with
   * `new RegExp(pattern)`; anchor it (`'^mermaid$'`) to match the whole name.
   */
  pattern: string | RegExp;
  content: MarkdownCodeBlockRenderer;
}

export interface MarkdownCodeRenderers {
  /** For code blocks no `languages` entry matches. */
  default?: MarkdownCodeBlockRenderer;
  /**
   * Renderers by language, keyed by a name of your choosing (used only in
   * warnings). When several patterns match, the longest pattern wins.
   */
  languages?: Record<string, MarkdownCodeLanguageRenderer>;
}

/**
 * React replacements for native blocks, keyed by block kind. Return a React
 * element to render it in place of the native block, or nothing (`undefined`)
 * to keep the native rendering for that block.
 */
export interface MarkdownRenderers {
  image?: (block: MarkdownImageBlock) => ReactElement | undefined;
  video?: (block: MarkdownVideoBlock) => ReactElement | undefined;
  link?: (block: MarkdownLinkBlock) => ReactElement | undefined;
  /**
   * One renderer for every code block, or a `default` plus renderers by
   * language. The matching language renderer runs, else `default`; with
   * neither, the block keeps the native code block. The renderer picked is
   * final: returning `undefined` keeps the native block, it does not fall back
   * to `default`.
   */
  code?: MarkdownCodeBlockRenderer | MarkdownCodeRenderers;
}

/**
 * Where an image is rendered. `root`, `blockquote` and `admonition` mean an
 * image paragraph (a replaceable block); `inline` is an image inside running
 * text, `list` one inside a list item, `table` one in a table cell, and `link`
 * an image that is the content of a link (`[![thumb](a)](b)`).
 */
export type MarkdownImagePlacement =
  | MarkdownBlockPlacement
  | 'inline'
  | 'list'
  | 'table'
  | 'link';

/**
 * One image in the document, in document order, wherever it sits. The id is an
 * opaque string that stays the same while the image is unchanged, across
 * streaming appends and edits elsewhere. It never equals a block id; an image
 * block names its occurrence in `MarkdownImageBlock.occurrenceId`.
 */
export interface MarkdownImageOccurrence {
  id: string;
  url: string;
  altText: string;
  title: string;
  placement: MarkdownImagePlacement;
}

/** The request to make for an image instead of its Markdown URL. */
export interface MarkdownImageSource {
  uri: string;
  /** Merged over `imageRequestHeaders`; header names are case-insensitive. */
  headers?: Record<string, string>;
}
