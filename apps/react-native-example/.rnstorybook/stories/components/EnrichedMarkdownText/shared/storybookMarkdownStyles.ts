type TextAlign = 'auto' | 'left' | 'right' | 'center' | 'justify';
type MathTextAlign = 'left' | 'center' | 'right';
type TableAlign = 'left' | 'center' | 'right';

export type ParagraphStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  marginTop: number;
  marginBottom: number;
  lineHeight: number;
  textAlign: TextAlign;
};

export const paragraphStyledDefaults: ParagraphStyleControls = {
  fontSize: 18,
  fontFamily: '',
  fontWeight: '',
  color: '#1e3a5f',
  marginTop: 0,
  marginBottom: 20,
  lineHeight: 28,
  textAlign: 'left',
};

export type HeadingLevel = 1 | 2 | 3 | 4 | 5 | 6;

export type SingleHeadingStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  lineHeight: number;
  textAlign: TextAlign;
  marginTop: number;
  marginBottom: number;
};

const singleHeadingBaseDefaults = {
  fontFamily: '',
  fontWeight: '',
  color: '#111827',
  lineHeight: 28,
  textAlign: 'left' as TextAlign,
  marginTop: 0,
  marginBottom: 8,
};

export const headingStyledDefaultsByLevel: Record<
  HeadingLevel,
  SingleHeadingStyleControls
> = {
  1: { ...singleHeadingBaseDefaults, fontSize: 30 },
  2: { ...singleHeadingBaseDefaults, fontSize: 24 },
  3: { ...singleHeadingBaseDefaults, fontSize: 20 },
  4: { ...singleHeadingBaseDefaults, fontSize: 18 },
  5: { ...singleHeadingBaseDefaults, fontSize: 16 },
  6: { ...singleHeadingBaseDefaults, fontSize: 14 },
};

export type BlockquoteStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  marginTop: number;
  marginBottom: number;
  lineHeight: number;
  borderColor: string;
  borderWidth: number;
  gapWidth: number;
  backgroundColor: string;
  borderRadius: number;
  padding: number;
};

export const blockquoteStyledDefaults: BlockquoteStyleControls = {
  fontSize: 16,
  fontFamily: '',
  fontWeight: '',
  color: '#4b5563',
  marginTop: 0,
  marginBottom: 16,
  lineHeight: 24,
  borderColor: '#6366f1',
  borderWidth: 4,
  gapWidth: 16,
  backgroundColor: '#eef2ff',
  borderRadius: 0,
  padding: 0,
};

// Admonitions inherit the blockquote geometry controls and add a per-type color
// pair. An empty background renders transparent (no fill).
export type AdmonitionStyleControls = BlockquoteStyleControls & {
  noteColor: string;
  noteBackgroundColor: string;
  tipColor: string;
  tipBackgroundColor: string;
  importantColor: string;
  importantBackgroundColor: string;
  warningColor: string;
  warningBackgroundColor: string;
  cautionColor: string;
  cautionBackgroundColor: string;
};

export const admonitionStyledDefaults: AdmonitionStyleControls = {
  ...blockquoteStyledDefaults,
  noteColor: '#0969da',
  noteBackgroundColor: '',
  tipColor: '#1a7f37',
  tipBackgroundColor: '',
  importantColor: '#8250df',
  importantBackgroundColor: '',
  warningColor: '#9a6700',
  warningBackgroundColor: '',
  cautionColor: '#cf222e',
  cautionBackgroundColor: '',
};

export type CodeBlockStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  marginTop: number;
  marginBottom: number;
  lineHeight: number;
  backgroundColor: string;
  borderColor: string;
  borderRadius: number;
  borderWidth: number;
  padding: number;
};

export const codeBlockStyledDefaults: CodeBlockStyleControls = {
  fontSize: 14,
  fontFamily: '',
  fontWeight: '',
  color: '#f3f4f6',
  marginTop: 0,
  marginBottom: 16,
  lineHeight: 20,
  backgroundColor: '#1f2937',
  borderColor: '#374151',
  borderRadius: 8,
  borderWidth: 1,
  padding: 16,
};

export type ThematicBreakStyleControls = {
  color: string;
  height: number;
  marginTop: number;
  marginBottom: number;
};

export const thematicBreakStyledDefaults: ThematicBreakStyleControls = {
  color: '#6366f1',
  height: 2,
  marginTop: 24,
  marginBottom: 24,
};

// '' = don't forward resizeMode, demoing the legacy sizing path.
export type ImageResizeMode =
  | ''
  | 'contain'
  | 'cover'
  | 'stretch'
  | 'center'
  | 'none';

export type ImageStyleControls = {
  height: number;
  maxHeight: number;
  aspectRatio: number;
  resizeMode: ImageResizeMode;
  borderRadius: number;
  marginTop: number;
  marginBottom: number;
};

export const imageStyledDefaults: ImageStyleControls = {
  height: 200,
  maxHeight: 0,
  aspectRatio: 0,
  resizeMode: '',
  borderRadius: 12,
  marginTop: 8,
  marginBottom: 16,
};

export type TableStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  marginTop: number;
  marginBottom: number;
  lineHeight: number;
  headerFontFamily: string;
  headerBackgroundColor: string;
  headerTextColor: string;
  rowEvenBackgroundColor: string;
  rowOddBackgroundColor: string;
  borderColor: string;
  borderWidth: number;
  borderRadius: number;
  cellPaddingHorizontal: number;
  cellPaddingVertical: number;
  horizontalOverflow: number;
  align: TableAlign | '';
};

export const tableStyledDefaults: TableStyleControls = {
  fontSize: 14,
  fontFamily: '',
  fontWeight: '',
  color: '#1f2937',
  marginTop: 0,
  marginBottom: 16,
  lineHeight: 22,
  headerFontFamily: '',
  headerBackgroundColor: '#eef2ff',
  headerTextColor: '#312e81',
  rowEvenBackgroundColor: '#ffffff',
  rowOddBackgroundColor: '#f9fafb',
  borderColor: '#c7d2fe',
  borderWidth: 1,
  borderRadius: 8,
  cellPaddingHorizontal: 12,
  cellPaddingVertical: 8,
  horizontalOverflow: 0,
  align: '',
};

export type TaskListStyleControls = {
  checkedColor: string;
  borderColor: string;
  checkboxSize: number;
  checkboxBorderRadius: number;
  checkmarkColor: string;
  checkedTextColor: string;
  checkedStrikethrough: boolean;
};

export const taskListStyledDefaults: TaskListStyleControls = {
  checkedColor: '#2563eb',
  borderColor: '#9ca3af',
  checkboxSize: 18,
  checkboxBorderRadius: 4,
  checkmarkColor: '#ffffff',
  checkedTextColor: '#9ca3af',
  checkedStrikethrough: true,
};

export type MathStyleControls = {
  latexMath: boolean;
  fontSize: number;
  color: string;
  backgroundColor: string;
  padding: number;
  marginTop: number;
  marginBottom: number;
  textAlign: MathTextAlign;
};

export const mathStyledDefaults: MathStyleControls = {
  latexMath: true,
  fontSize: 16,
  color: '#1e3a5f',
  backgroundColor: '#f0f9ff',
  padding: 12,
  marginTop: 0,
  marginBottom: 16,
  textAlign: 'center',
};

export type ListStyleControls = {
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  color: string;
  marginTop: number;
  marginBottom: number;
  lineHeight: number;
  bulletColor: string;
  bulletSize: number;
  markerMinWidth: number;
  markerColor: string;
  markerFontWeight: string;
  gapWidth: number;
  marginLeft: number;
  itemSpacing: number;
};

export const listStyledDefaults: ListStyleControls = {
  fontSize: 16,
  fontFamily: '',
  fontWeight: '',
  color: '#1f2937',
  marginTop: 0,
  marginBottom: 16,
  lineHeight: 24,
  bulletColor: '#6366f1',
  bulletSize: 6,
  markerMinWidth: 0,
  markerColor: '#4f46e5',
  markerFontWeight: '',
  gapWidth: 8,
  marginLeft: 24,
  itemSpacing: 0,
};

export type StrongStyleControls = {
  fontFamily: string;
  fontWeight: 'bold' | 'normal';
  color: string;
};

export const strongStyledDefaults: StrongStyleControls = {
  fontFamily: '',
  fontWeight: 'bold',
  color: '#111827',
};

export type EmphasisStyleControls = {
  fontFamily: string;
  fontStyle: 'italic' | 'normal';
  color: string;
};

export const emphasisStyledDefaults: EmphasisStyleControls = {
  fontFamily: '',
  fontStyle: 'italic',
  color: '#4b5563',
};

export type LinkStyleControls = {
  fontFamily: string;
  color: string;
  underline: boolean;
  backgroundColor: string;
};

export const linkStyledDefaults: LinkStyleControls = {
  fontFamily: '',
  color: '#2563eb',
  underline: true,
  backgroundColor: 'transparent',
};

export type LinkVariantsDemoControls = LinkStyleControls & {
  userVariantColor: string;
  userVariantUnderline: boolean;
  userVariantBackgroundColor: string;
  channelVariantColor: string;
  channelVariantUnderline: boolean;
  channelVariantBackgroundColor: string;
};

export const linkVariantsDemoDefaults: LinkVariantsDemoControls = {
  ...linkStyledDefaults,
  userVariantColor: '#1a73e8',
  userVariantUnderline: false,
  userVariantBackgroundColor: '#e8f0fe',
  channelVariantColor: '#137333',
  channelVariantUnderline: false,
  channelVariantBackgroundColor: '#e6f4ea',
};

export type InlineCodeStyleControls = {
  fontFamily: string;
  fontSize: number;
  color: string;
  backgroundColor: string;
  borderColor: string;
};

export const inlineCodeStyledDefaults: InlineCodeStyleControls = {
  fontFamily: '',
  fontSize: 0,
  color: '#e01e5a',
  backgroundColor: '#fdf2f4',
  borderColor: '#f8d7da',
};

export type StrikethroughStyleControls = {
  color: string;
};

export const strikethroughStyledDefaults: StrikethroughStyleControls = {
  color: '#9ca3af',
};

export type UnderlineStyleControls = {
  underline: boolean;
  color: string;
};

export const underlineStyledDefaults: UnderlineStyleControls = {
  underline: true,
  color: '#2563eb',
};

export type SuperscriptStyleControls = {
  superscript: boolean;
  fontScale: number;
  baselineOffsetScale: number;
};

export const superscriptStyledDefaults: SuperscriptStyleControls = {
  superscript: true,
  fontScale: 0.75,
  baselineOffsetScale: 0.35,
};

export type SubscriptStyleControls = {
  subscript: boolean;
  fontScale: number;
  baselineOffsetScale: number;
};

export const subscriptStyledDefaults: SubscriptStyleControls = {
  subscript: true,
  fontScale: 0.75,
  baselineOffsetScale: 0.2,
};

export type HighlightStyleControls = {
  highlight: boolean;
  color: string;
  backgroundColor: string;
};

export const highlightStyledDefaults: HighlightStyleControls = {
  highlight: true,
  color: '#1e3a5f',
  backgroundColor: '#fef08a',
};

type NumberControlRange = {
  min: number;
  max: number;
  step?: number;
};

/** Slider for numeric args — RN Storybook `type: 'number'` renders as text; `range` does not. */
export function numberControl(description: string, range: NumberControlRange) {
  const { min, max, step = 1 } = range;
  return {
    control: { type: 'range' as const, min, max, step },
    description,
  };
}

export function scriptStyleArgTypes(styleKey: 'superscript' | 'subscript') {
  return {
    fontScale: numberControl(`markdownStyle.${styleKey}.fontScale`, {
      min: 0.5,
      max: 1,
      step: 0.05,
    }),
    baselineOffsetScale: numberControl(
      `markdownStyle.${styleKey}.baselineOffsetScale`,
      { min: 0, max: 0.6, step: 0.05 }
    ),
  };
}

export type MarkdownFlavor = 'commonmark' | 'github';

export function githubFlavorArgTypes(description: string) {
  return {
    flavor: {
      options: ['commonmark', 'github'] satisfies MarkdownFlavor[],
      control: { type: 'inline-radio' },
      description,
    },
  };
}

/** Bundled fonts in apps/react-native-example/assets/fonts (see src/markdownStyles.ts). */
export const EXAMPLE_FONT_FAMILIES = [
  '',
  'Montserrat-Regular',
  'Montserrat-Bold',
  'Montserrat-SemiBold',
  'Montserrat-Medium',
  'Montserrat-Italic',
  'CourierPrime-Regular',
] as const;

const EXAMPLE_FONT_FAMILY_LABELS: Record<
  (typeof EXAMPLE_FONT_FAMILIES)[number],
  string
> = {
  '': 'Default',
  'Montserrat-Regular': 'Montserrat Regular',
  'Montserrat-Bold': 'Montserrat Bold',
  'Montserrat-SemiBold': 'Montserrat SemiBold',
  'Montserrat-Medium': 'Montserrat Medium',
  'Montserrat-Italic': 'Montserrat Italic',
  'CourierPrime-Regular': 'Courier Prime',
};

export function fontFamilyControl(description: string) {
  return {
    options: [...EXAMPLE_FONT_FAMILIES],
    control: {
      type: 'select' as const,
      labels: EXAMPLE_FONT_FAMILY_LABELS,
    },
    description,
  };
}

/** React Native fontWeight values (see Text style prop). */
export const EXAMPLE_FONT_WEIGHTS = [
  '',
  'normal',
  '300',
  '500',
  '600',
  'bold',
] as const;

const EXAMPLE_FONT_WEIGHT_LABELS: Record<
  (typeof EXAMPLE_FONT_WEIGHTS)[number],
  string
> = {
  '': 'Default',
  'normal': 'Normal',
  '300': 'Light (300)',
  '500': 'Medium (500)',
  '600': 'SemiBold (600)',
  'bold': 'Bold',
};

export function fontWeightControl(description: string) {
  return {
    options: [...EXAMPLE_FONT_WEIGHTS],
    control: {
      type: 'select' as const,
      labels: EXAMPLE_FONT_WEIGHT_LABELS,
    },
    description,
  };
}

export function strongFontWeightControl(description: string) {
  return {
    options: ['bold', 'normal'] as const,
    control: { type: 'inline-radio' as const },
    description,
  };
}

const TEXT_ALIGN_OPTIONS = [
  'auto',
  'left',
  'right',
  'center',
  'justify',
] as const satisfies readonly TextAlign[];

const MATH_TEXT_ALIGN_OPTIONS = [
  'left',
  'center',
  'right',
] as const satisfies readonly MathTextAlign[];

export function textAlignControl(description: string) {
  return {
    options: [...TEXT_ALIGN_OPTIONS],
    control: { type: 'select' as const },
    description,
  };
}

export function mathTextAlignControl(description: string) {
  return {
    options: [...MATH_TEXT_ALIGN_OPTIONS],
    control: { type: 'select' as const },
    description,
  };
}

const TABLE_ALIGN_OPTIONS = [
  '',
  'left',
  'center',
  'right',
] as const satisfies readonly (TableAlign | '')[];

export function tableAlignControl(description: string) {
  return {
    options: [...TABLE_ALIGN_OPTIONS],
    control: { type: 'select' as const },
    description,
  };
}

export type InlineImageStyleControls = {
  size: number;
};

export const inlineImageStyledDefaults: InlineImageStyleControls = {
  size: 20,
};

export type InlineMathStyleControls = {
  latexMath: boolean;
  color: string;
};

export const inlineMathStyledDefaults: InlineMathStyleControls = {
  latexMath: true,
  color: '#1e3a5f',
};

export type SpoilerStyleControls = {
  color: string;
  particleDensity: number;
  particleSpeed: number;
  solidBorderRadius: number;
};

export const spoilerStyledDefaults: SpoilerStyleControls = {
  color: '#374151',
  particleDensity: 8,
  particleSpeed: 20,
  solidBorderRadius: 4,
};
