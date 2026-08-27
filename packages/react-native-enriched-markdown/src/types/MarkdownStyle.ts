type TextAlign = 'auto' | 'left' | 'right' | 'center' | 'justify';

type ImageResizeMode = 'contain' | 'cover' | 'stretch' | 'center' | 'none';

interface BaseBlockStyle {
  fontSize?: number;
  fontFamily?: string;
  fontWeight?: string;
  color?: string;
  marginTop?: number;
  marginBottom?: number;
  lineHeight?: number;
}

interface ParagraphStyle extends BaseBlockStyle {
  textAlign?: TextAlign;
}

interface HeadingStyle extends BaseBlockStyle {
  textAlign?: TextAlign;
}

interface BlockquoteStyle extends BaseBlockStyle {
  borderColor?: string;
  borderWidth?: number;
  gapWidth?: number;
  backgroundColor?: string;
  borderRadius?: number;
  padding?: number;
}

interface ListStyle extends BaseBlockStyle {
  bulletColor?: string;
  bulletSize?: number;
  /**
   * Minimum reserved marker column width applied uniformly to UL/OL/task lists.
   * `0` (the default) means no minimum — each list uses its natural marker width.
   */
  markerMinWidth?: number;
  markerColor?: string;
  markerFontWeight?: string;
  gapWidth?: number;
  marginLeft?: number;
  /**
   * Vertical spacing between consecutive list items, including nested ones.
   * Adds no space above the first item or below the last one — the outer
   * edges are still controlled by `marginTop`/`marginBottom`.
   * @default 0
   */
  itemSpacing?: number;
}

/**
 * Per-token syntax highlight colors for fenced code blocks, keyed on the
 * tree-sitter highlight token types. Any key omitted falls back to the default
 * palette (Operator/Punctuation/Variable/Embedded inherit the code block's
 * base `color`). Colors only take visible effect when the optional syntax
 * highlighting module is compiled in; otherwise code blocks render uncolored.
 */
interface CodeBlockSyntaxColors {
  keyword?: string;
  /** Color for operator tokens (e.g. `+`, `=>`). */
  operator?: string;
  punctuation?: string;
  string?: string;
  number?: string;
  constant?: string;
  comment?: string;
  function?: string;
  type?: string;
  variable?: string;
  property?: string;
  tag?: string;
  attribute?: string;
  embedded?: string;
}

interface CodeBlockStyle extends BaseBlockStyle {
  backgroundColor?: string;
  borderColor?: string;
  borderRadius?: number;
  borderWidth?: number;
  padding?: number;
  syntaxColors?: CodeBlockSyntaxColors;
}

export interface LinkStyle {
  fontFamily?: string;
  color?: string;
  underline?: boolean;
  backgroundColor?: string;
}

export interface LinkVariantStyle {
  color?: string;
  underline?: boolean;
  backgroundColor?: string;
}

interface StrongStyle {
  fontFamily?: string;
  /**
   * Controls whether bold is applied on top of the custom fontFamily.
   * Only relevant when fontFamily is set. Defaults to 'bold'.
   * Set to 'normal' to use the font face as-is without adding bold.
   */
  fontWeight?: 'bold' | 'normal';
  color?: string;
}

interface EmphasisStyle {
  fontFamily?: string;
  /**
   * Controls whether italic is applied on top of the custom fontFamily.
   * Only relevant when fontFamily is set. Defaults to 'italic'.
   * Set to 'normal' to use the font face as-is without adding italic.
   */
  fontStyle?: 'italic' | 'normal';
  color?: string;
}

interface StrikethroughStyle {
  /**
   * Color of the strikethrough line.
   * @platform iOS
   */
  color?: string;
}

interface UnderlineStyle {
  /**
   * Color of the underline.
   * @platform iOS
   */
  color?: string;
}

interface CodeStyle {
  fontFamily?: string;
  fontSize?: number;
  color?: string;
  backgroundColor?: string;
  borderColor?: string;
}

interface ImageStyle {
  height?: number;
  /**
   * Maximum height the image is fitted into, preserving aspect ratio. When set,
   * this replaces `height` as the primary sizing knob. Ignored when `aspectRatio`
   * is set. Sizing precedence: `aspectRatio` > `maxHeight` > `height`.
   */
  maxHeight?: number;
  /**
   * Width / height ratio (e.g. `16 / 9`). The image fills the available width and
   * its height is derived from this ratio, ignoring `height`/`maxHeight`.
   * Sizing precedence: `aspectRatio` > `maxHeight` > `height`.
   */
  aspectRatio?: number;
  /**
   * How the image fills its box, analogous to React Native `resizeMode` / CSS
   * `object-fit`. Applies whenever set explicitly, including with a fixed
   * `height` box. When omitted, block images keep the legacy fill-width
   * behavior, unless `maxHeight` or `aspectRatio` is set — then it defaults
   * to `'cover'`.
   */
  resizeMode?: ImageResizeMode;
  borderRadius?: number;
  marginTop?: number;
  marginBottom?: number;
}

interface InlineImageStyle {
  size?: number;
}

interface ThematicBreakStyle {
  color?: string;
  height?: number;
  marginTop?: number;
  marginBottom?: number;
}

interface TableStyle extends BaseBlockStyle {
  headerFontFamily?: string;
  headerBackgroundColor?: string;
  headerTextColor?: string;
  rowEvenBackgroundColor?: string;
  rowOddBackgroundColor?: string;
  borderColor?: string;
  borderWidth?: number;
  borderRadius?: number;
  cellPaddingHorizontal?: number;
  cellPaddingVertical?: number;
  horizontalOverflow?: number;
  /**
   * Horizontal alignment of the whole table within the container. Only applies
   * when the table is narrower than the container; tables that overflow and
   * scroll always start at the table's beginning. When unset, tables keep the
   * legacy start-aligned placement. On web, setting any value (including
   * 'left') also makes the table shrink to fit its content instead of filling
   * the container width.
   */
  align?: 'left' | 'center' | 'right';
}

interface TaskListStyle {
  checkedColor?: string;
  borderColor?: string;
  checkboxSize?: number;
  checkboxBorderRadius?: number;
  checkmarkColor?: string;
  checkedTextColor?: string;
  checkedStrikethrough?: boolean;
}

interface MathStyle {
  fontSize?: number;
  color?: string;
  backgroundColor?: string;
  padding?: number;
  marginTop?: number;
  marginBottom?: number;
  textAlign?: 'left' | 'center' | 'right';
}

interface InlineMathStyle {
  color?: string;
}

interface SpoilerParticlesStyle {
  /**
   * Number of particles per 100x100pt area.
   * Higher values = denser, more opaque concealment.
   * @default 8
   */
  density?: number;
  /**
   * Base speed of particle drift in points per second.
   * @default 20
   */
  speed?: number;
}

interface SpoilerSolidStyle {
  /**
   * Corner radius of the solid spoiler overlay rectangles.
   * @default 4
   */
  borderRadius?: number;
}

interface SpoilerStyle {
  /** Color used by all presets for the spoiler overlay. */
  color?: string;
  /** Particle-preset tuning (only applies when spoilerOverlay='particles'). */
  particles?: SpoilerParticlesStyle;
  /** Solid-preset tuning (only applies when spoilerOverlay='solid'). */
  solid?: SpoilerSolidStyle;
}

interface SuperscriptStyle {
  /**
   * Font size as a fraction of the surrounding text size.
   * @default 0.75
   */
  fontScale?: number;
  /**
   * Vertical shift as a fraction of the surrounding text size.
   * Positive values shift the text upward.
   * @default 0.35
   */
  baselineOffsetScale?: number;
}

interface SubscriptStyle {
  /**
   * Font size as a fraction of the surrounding text size.
   * @default 0.75
   */
  fontScale?: number;
  /**
   * Vertical shift as a fraction of the surrounding text size.
   * Positive values shift the text downward.
   * @default 0.20
   */
  baselineOffsetScale?: number;
}

interface HighlightStyle {
  /**
   * Text color inside the highlight span.
   * Inherits the surrounding block color when omitted.
   */
  color?: string;
  /**
   * Background color of the highlight span.
   * @default '#FEF08A'
   */
  backgroundColor?: string;
}

export interface MarkdownStyle {
  paragraph?: ParagraphStyle;
  h1?: HeadingStyle;
  h2?: HeadingStyle;
  h3?: HeadingStyle;
  h4?: HeadingStyle;
  h5?: HeadingStyle;
  h6?: HeadingStyle;
  blockquote?: BlockquoteStyle;
  list?: ListStyle;
  codeBlock?: CodeBlockStyle;
  link?: LinkStyle;
  /**
   * Per-URL-pattern link style overrides. Each key is a regex string tested
   * against the full URL. Patterns are normalized longest-first so more
   * specific patterns take precedence.
   *
   * `color` and `underline` inherit from the base `link` style when omitted.
   * `backgroundColor` defaults to `transparent`.
   * `fontFamily` always follows the base `link` style and cannot be overridden per-variant.
   *
   * @example
   * linkVariants: {
   *   '^user:':    { color: '#1A73E8', backgroundColor: '#E8F0FE' },
   *   '^channel:': { color: '#137333', backgroundColor: '#E6F4EA' },
   *   '^cite:':    { color: '#B06000', backgroundColor: '#FEF3C7' },
   *   // path-based: matches any https URL with /user/ in the path
   *   '\\/user\\/': { color: '#4F46E5', backgroundColor: '#EEF2FF' },
   * }
   */
  linkVariants?: Record<string, LinkVariantStyle>;
  strong?: StrongStyle;
  em?: EmphasisStyle;
  strikethrough?: StrikethroughStyle;
  underline?: UnderlineStyle;
  code?: CodeStyle;
  image?: ImageStyle;
  inlineImage?: InlineImageStyle;
  thematicBreak?: ThematicBreakStyle;
  table?: TableStyle;
  taskList?: TaskListStyle;
  math?: MathStyle;
  inlineMath?: InlineMathStyle;
  spoiler?: SpoilerStyle;
  superscript?: SuperscriptStyle;
  subscript?: SubscriptStyle;
  highlight?: HighlightStyle;
}

/**
 * MD4C parser flags configuration.
 * Controls how the markdown parser interprets certain syntax.
 */
export interface Md4cFlags {
  /**
   * Enable underline syntax support (__text__).
   * When enabled, underscores are treated as underline markers.
   * When disabled, underscores are treated as emphasis markers (same as asterisks).
   * @default false
   */
  underline?: boolean;
  /**
   * Enable superscript span parsing (^text^).
   * When enabled, the parser recognizes caret superscript delimiters.
   * When disabled, carets are treated as plain text.
   * @default false
   */
  superscript?: boolean;
  /**
   * Enable subscript span parsing (~text~).
   * When enabled, single tildes are treated as subscript markers.
   * When disabled, single and double tildes are treated as strikethrough markers.
   * @default false
   */
  subscript?: boolean;
  /**
   * Enable LaTeX math span parsing ($..$ and $$..$$).
   * When enabled, the parser recognizes LaTeX math delimiters.
   * When disabled, dollar signs are treated as plain text.
   * Requires the optional RaTeX native dependency (iOS and Android).
   * @default true
   */
  latexMath?: boolean;
  /**
   * Enable highlight span parsing (==text==).
   * When enabled, double equals are treated as highlight markers.
   * When disabled, equals signs are treated as plain text.
   * @default false
   */
  highlight?: boolean;
  /**
   * Treat soft breaks (single newlines) as hard breaks (visible line breaks).
   * When enabled, a single newline in the source renders as a line break
   * instead of being collapsed to a space (CommonMark default).
   * @default false
   */
  hardSoftBreaks?: boolean;
  /**
   * Autolink bare URLs and e-mail addresses without angle brackets.
   * When disabled, only explicit `[text](url)` and `<url>` links are parsed.
   * @default true
   */
  permissiveAutolinks?: boolean;
}
