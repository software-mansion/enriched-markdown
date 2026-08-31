import type { MarkdownStyle } from 'react-native-enriched-markdown';
import type { StoryArgs } from './storyTypes';
import type {
  AdmonitionStyleControls,
  BlockquoteStyleControls,
  CodeBlockStyleControls,
  EmphasisStyleControls,
  HeadingLevel,
  ImageStyleControls,
  InlineCodeStyleControls,
  InlineImageStyleControls,
  InlineMathStyleControls,
  LinkStyleControls,
  LinkVariantsDemoControls,
  ListStyleControls,
  MathStyleControls,
  ParagraphStyleControls,
  SingleHeadingStyleControls,
  SpoilerStyleControls,
  HighlightStyleControls,
  StrikethroughStyleControls,
  StrongStyleControls,
  SubscriptStyleControls,
  SuperscriptStyleControls,
  TableStyleControls,
  TaskListStyleControls,
  ThematicBreakStyleControls,
  UnderlineStyleControls,
} from './storybookMarkdownStyles';

/**
 * Split Storybook style-control args from EnrichedMarkdownText props.
 * md4cFlags (e.g. underline, superscript) may live in style controls so they
 * are peeled off alongside markdownStyle knobs — see Underline/Superscript/Subscript.
 */
export function splitStyleControls<TControls extends Record<string, unknown>>(
  args: StoryArgs<TControls>,
  defaults: TControls
): { controls: TControls; rest: StoryArgs } {
  const controls = { ...defaults };
  const rest = { ...args };
  for (const key of Object.keys(defaults) as (keyof TControls)[]) {
    const value = args[key as keyof typeof args];
    if (value !== undefined) {
      controls[key] = value as TControls[keyof TControls];
    }
    delete rest[key as string];
  }
  return { controls, rest: rest as StoryArgs };
}

export function toParagraphStyle(
  controls: ParagraphStyleControls
): NonNullable<MarkdownStyle['paragraph']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    lineHeight: controls.lineHeight,
    textAlign: controls.textAlign,
  };
}

export function toHeadingStyle(
  controls: SingleHeadingStyleControls
): NonNullable<MarkdownStyle['h1']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    lineHeight: controls.lineHeight,
    textAlign: controls.textAlign,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
  };
}

export function toHeadingStyleAtLevel(
  level: HeadingLevel,
  controls: SingleHeadingStyleControls
): Pick<MarkdownStyle, 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6'> {
  const style = toHeadingStyle(controls);
  return { [`h${level}`]: style } as Pick<
    MarkdownStyle,
    'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6'
  >;
}

export function toBlockquoteStyle(
  controls: BlockquoteStyleControls
): NonNullable<MarkdownStyle['blockquote']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    lineHeight: controls.lineHeight,
    borderColor: controls.borderColor,
    borderWidth: controls.borderWidth,
    gapWidth: controls.gapWidth,
    backgroundColor: controls.backgroundColor,
    borderRadius: controls.borderRadius,
    padding: controls.padding,
  };
}

function admonitionColors(color: string, backgroundColor: string) {
  return {
    ...(color ? { color } : {}),
    ...(backgroundColor ? { backgroundColor } : {}),
  };
}

// Blockquote style with the admonition palette nested under it. Admonitions
// reuse the blockquote geometry and only theme colors per type.
export function toAdmonitionStyle(
  controls: AdmonitionStyleControls
): NonNullable<MarkdownStyle['blockquote']> {
  return {
    ...toBlockquoteStyle(controls),
    admonitions: {
      note: admonitionColors(controls.noteColor, controls.noteBackgroundColor),
      tip: admonitionColors(controls.tipColor, controls.tipBackgroundColor),
      important: admonitionColors(
        controls.importantColor,
        controls.importantBackgroundColor
      ),
      warning: admonitionColors(
        controls.warningColor,
        controls.warningBackgroundColor
      ),
      caution: admonitionColors(
        controls.cautionColor,
        controls.cautionBackgroundColor
      ),
    },
  };
}

export function toCodeBlockStyle(
  controls: CodeBlockStyleControls
): NonNullable<MarkdownStyle['codeBlock']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    lineHeight: controls.lineHeight,
    backgroundColor: controls.backgroundColor,
    borderColor: controls.borderColor,
    borderRadius: controls.borderRadius,
    borderWidth: controls.borderWidth,
    padding: controls.padding,
  };
}

export function toThematicBreakStyle(
  controls: ThematicBreakStyleControls
): NonNullable<MarkdownStyle['thematicBreak']> {
  return {
    color: controls.color,
    height: controls.height,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
  };
}

export function toImageStyle(
  controls: ImageStyleControls
): NonNullable<MarkdownStyle['image']> {
  return {
    height: controls.height,
    // Only forward the new sizing knobs when set, so the default story keeps
    // the exact legacy behavior (backward-compat demo).
    ...(controls.maxHeight > 0 ? { maxHeight: controls.maxHeight } : {}),
    ...(controls.aspectRatio > 0 ? { aspectRatio: controls.aspectRatio } : {}),
    ...(controls.resizeMode ? { resizeMode: controls.resizeMode } : {}),
    borderRadius: controls.borderRadius,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
  };
}

export function toTableStyle(
  controls: TableStyleControls
): NonNullable<MarkdownStyle['table']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    lineHeight: controls.lineHeight,
    ...(controls.headerFontFamily
      ? { headerFontFamily: controls.headerFontFamily }
      : {}),
    headerBackgroundColor: controls.headerBackgroundColor,
    headerTextColor: controls.headerTextColor,
    rowEvenBackgroundColor: controls.rowEvenBackgroundColor,
    rowOddBackgroundColor: controls.rowOddBackgroundColor,
    borderColor: controls.borderColor,
    borderWidth: controls.borderWidth,
    borderRadius: controls.borderRadius,
    cellPaddingHorizontal: controls.cellPaddingHorizontal,
    cellPaddingVertical: controls.cellPaddingVertical,
    horizontalOverflow: controls.horizontalOverflow,
    ...(controls.align ? { align: controls.align } : {}),
  };
}

export function toTaskListStyle(
  controls: TaskListStyleControls
): NonNullable<MarkdownStyle['taskList']> {
  return {
    checkedColor: controls.checkedColor,
    borderColor: controls.borderColor,
    checkboxSize: controls.checkboxSize,
    checkboxBorderRadius: controls.checkboxBorderRadius,
    checkmarkColor: controls.checkmarkColor,
    checkedTextColor: controls.checkedTextColor,
    checkedStrikethrough: controls.checkedStrikethrough,
  };
}

export function toMathStyle(
  controls: Omit<MathStyleControls, 'latexMath'>
): NonNullable<MarkdownStyle['math']> {
  return {
    fontSize: controls.fontSize,
    color: controls.color,
    backgroundColor: controls.backgroundColor,
    padding: controls.padding,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    textAlign: controls.textAlign,
  };
}

export function toListStyle(
  controls: ListStyleControls
): NonNullable<MarkdownStyle['list']> {
  return {
    fontSize: controls.fontSize,
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontWeight ? { fontWeight: controls.fontWeight } : {}),
    color: controls.color,
    marginTop: controls.marginTop,
    marginBottom: controls.marginBottom,
    lineHeight: controls.lineHeight,
    bulletColor: controls.bulletColor,
    bulletSize: controls.bulletSize,
    markerMinWidth: controls.markerMinWidth,
    markerColor: controls.markerColor,
    ...(controls.markerFontWeight
      ? { markerFontWeight: controls.markerFontWeight }
      : {}),
    gapWidth: controls.gapWidth,
    marginLeft: controls.marginLeft,
    itemSpacing: controls.itemSpacing,
  };
}

export function toStrongStyle(
  controls: StrongStyleControls
): NonNullable<MarkdownStyle['strong']> {
  return {
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    fontWeight: controls.fontWeight,
    ...(controls.color ? { color: controls.color } : {}),
  };
}

export function toEmphasisStyle(
  controls: EmphasisStyleControls
): NonNullable<MarkdownStyle['em']> {
  return {
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    fontStyle: controls.fontStyle,
    ...(controls.color ? { color: controls.color } : {}),
  };
}

export function toLinkStyle(
  controls: LinkStyleControls
): NonNullable<MarkdownStyle['link']> {
  return {
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    color: controls.color,
    underline: controls.underline,
    backgroundColor: controls.backgroundColor,
  };
}

export function toLinkVariantsDemoStyle(
  controls: LinkVariantsDemoControls
): Pick<MarkdownStyle, 'link' | 'linkVariants'> {
  const {
    userVariantColor,
    userVariantUnderline,
    userVariantBackgroundColor,
    channelVariantColor,
    channelVariantUnderline,
    channelVariantBackgroundColor,
    ...linkControls
  } = controls;

  return {
    link: toLinkStyle(linkControls),
    linkVariants: {
      '^user:': {
        color: userVariantColor,
        underline: userVariantUnderline,
        backgroundColor: userVariantBackgroundColor,
      },
      '^channel:': {
        color: channelVariantColor,
        underline: channelVariantUnderline,
        backgroundColor: channelVariantBackgroundColor,
      },
    },
  };
}

export function toInlineCodeStyle(
  controls: InlineCodeStyleControls
): NonNullable<MarkdownStyle['code']> {
  return {
    ...(controls.fontFamily ? { fontFamily: controls.fontFamily } : {}),
    ...(controls.fontSize > 0 ? { fontSize: controls.fontSize } : {}),
    color: controls.color,
    backgroundColor: controls.backgroundColor,
    borderColor: controls.borderColor,
  };
}

export function toStrikethroughStyle(
  controls: StrikethroughStyleControls
): NonNullable<MarkdownStyle['strikethrough']> {
  return { color: controls.color };
}

export function toUnderlineStyle(
  controls: Omit<UnderlineStyleControls, 'underline'>
): NonNullable<MarkdownStyle['underline']> {
  return { color: controls.color };
}

export function toSuperscriptStyle(
  controls: Omit<SuperscriptStyleControls, 'superscript'>
): NonNullable<MarkdownStyle['superscript']> {
  return {
    fontScale: controls.fontScale,
    baselineOffsetScale: controls.baselineOffsetScale,
  };
}

export function toSubscriptStyle(
  controls: Omit<SubscriptStyleControls, 'subscript'>
): NonNullable<MarkdownStyle['subscript']> {
  return {
    fontScale: controls.fontScale,
    baselineOffsetScale: controls.baselineOffsetScale,
  };
}

export function toHighlightStyle(
  controls: Omit<HighlightStyleControls, 'highlight'>
): NonNullable<MarkdownStyle['highlight']> {
  return {
    ...(controls.color ? { color: controls.color } : {}),
    backgroundColor: controls.backgroundColor,
  };
}

export function toInlineImageStyle(
  controls: InlineImageStyleControls
): NonNullable<MarkdownStyle['inlineImage']> {
  return { size: controls.size };
}

export function toInlineMathStyle(
  controls: Omit<InlineMathStyleControls, 'latexMath'>
): NonNullable<MarkdownStyle['inlineMath']> {
  return { color: controls.color };
}

export function toSpoilerStyle(
  controls: SpoilerStyleControls
): NonNullable<MarkdownStyle['spoiler']> {
  return {
    color: controls.color,
    particles: {
      density: controls.particleDensity,
      speed: controls.particleSpeed,
    },
    solid: {
      borderRadius: controls.solidBorderRadius,
    },
  };
}
