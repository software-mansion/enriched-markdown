import { Platform } from 'react-native';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

// The page is a bench sheet, the board is the bench at night.
export const IVORY = '#F2EEE4';
export const INK = '#1B1C1F';
export const INK_SOFT = '#77726A';
export const RULE = '#D8D1C2';

export const NIGHT = '#0D0E10';
export const TILE = '#191B1F';
export const TILE_EDGE = '#2B2E35';
export const HERO = '#15171A';
export const CREAM = '#EFEADF';
export const CREAM_SOFT = '#8E8B85';

// The works themselves.
export const DISC = '#101114';
export const DISC_RING = '#26282E';
export const BRASS = '#CDA85E';
export const BRASS_LIGHT = '#F0D89A';
export const BRASS_DEEP = '#8F7238';
export const BRASS_DARK = '#5E4B25';
export const STEEL = '#C5C8CE';
export const STEEL_LIGHT = '#F1F2F5';
export const STEEL_DEEP = '#7C8088';
// Heat-blued steel, the one loud colour on the bench.
export const BLUED = '#3F6BDD';
export const BLUED_DEEP = '#27469B';
export const RUBY = '#D7355F';
export const ENAMEL = '#ECE8DD';
export const ENAMEL_DEEP = '#D6CFBE';
// Hairline engraving on the dark plates.
export const ENGRAVE = '#8E8B85';

export const FONTS = {
  display: 'Fraunces-SemiBold',
  body: 'Newsreader-Regular',
  bodyBold: 'Newsreader-SemiBold',
  bodyItalic: 'Newsreader-Italic',
  mono: 'DMMono-Regular',
  monoMedium: 'DMMono-Medium',
};

const italic = {
  fontFamily: FONTS.bodyItalic,
  // On iOS `fontStyle: 'normal'` finds no face in an italic-only family.
  fontStyle: Platform.OS === 'ios' ? ('italic' as const) : ('normal' as const),
};

export const pageMarkdownStyle: MarkdownStyle = {
  paragraph: {
    fontFamily: FONTS.body,
    fontSize: 18,
    lineHeight: 27,
    color: INK,
    marginBottom: 14,
  },
  h1: {
    fontFamily: FONTS.display,
    fontSize: 52,
    lineHeight: 54,
    color: INK,
    marginBottom: 12,
  },
  h2: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    lineHeight: 18,
    color: BLUED_DEEP,
    marginTop: 18,
    marginBottom: 8,
  },
  strong: { fontFamily: FONTS.bodyBold, fontWeight: 'normal' },
  em: italic,
  codeBlock: { marginTop: 6, marginBottom: 22 },
  blockquote: {
    backgroundColor: IVORY,
    fontFamily: FONTS.bodyItalic,
    fontSize: 18,
    lineHeight: 27,
    color: INK_SOFT,
    borderColor: BRASS,
    borderWidth: 2,
    gapWidth: 14,
    marginBottom: 14,
  },
  code: {
    fontFamily: FONTS.monoMedium,
    fontSize: 14.5,
    color: BLUED_DEEP,
    backgroundColor: '#E8E2D3',
    borderColor: RULE,
  },
  list: {
    fontFamily: FONTS.body,
    fontSize: 18,
    lineHeight: 27,
    color: INK,
    markerColor: BRASS_DEEP,
    marginBottom: 14,
  },
  table: {
    fontFamily: FONTS.mono,
    fontSize: 14,
    color: INK,
    headerFontFamily: FONTS.monoMedium,
    headerTextColor: BLUED_DEEP,
    headerBackgroundColor: '#E8E2D3',
    rowEvenBackgroundColor: IVORY,
    rowOddBackgroundColor: IVORY,
    borderColor: RULE,
    borderWidth: 1,
    borderRadius: 10,
    cellPaddingHorizontal: 14,
    cellPaddingVertical: 8,
    marginBottom: 14,
  },
  thematicBreak: { color: RULE, height: 1, marginTop: 10, marginBottom: 16 },
};

function partStyle(color: string): MarkdownStyle {
  return {
    paragraph: {
      fontFamily: FONTS.body,
      fontSize: 18,
      lineHeight: 27,
      color,
      marginBottom: 14,
    },
    strong: { fontFamily: FONTS.bodyBold, fontWeight: 'normal' },
    em: italic,
    strikethrough: { color: '#B8402A' },
  };
}

export const partMarkdownStyle = {
  ivory: partStyle(INK),
  night: partStyle(CREAM),
};
