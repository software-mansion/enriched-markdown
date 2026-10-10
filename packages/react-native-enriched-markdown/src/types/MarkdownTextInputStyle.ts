export interface LinkStyle {
  color?: string;
  underline?: boolean;
  backgroundColor?: string;
}

export interface HeadingStyle {
  fontSize?: number;
  fontWeight?: string;
  color?: string;
}

export interface MarkdownTextInputStyle {
  strong?: {
    color?: string;
  };
  em?: {
    color?: string;
  };
  link?: LinkStyle;
  linkVariants?: Record<string, LinkStyle>;
  spoiler?: {
    color?: string;
    backgroundColor?: string;
  };
  /**
   * Per-level heading styling for the editor, mirroring the readonly
   * renderer's `markdownStyle` h1..h6. Omitted levels fall back to defaults
   * (font sizes 30/24/20/18/16/14).
   */
  h1?: HeadingStyle;
  h2?: HeadingStyle;
  h3?: HeadingStyle;
  h4?: HeadingStyle;
  h5?: HeadingStyle;
  h6?: HeadingStyle;
  /** List styling shared by bullet and numbered lists. */
  list?: {
    /**
     * Vertical spacing (points) added above each list item so items read as
     * separate rows. iOS uses `paragraphSpacingBefore`; Android a `LineHeightSpan`.
     * @default 0
     */
    itemSpacing?: number;
  };
}
