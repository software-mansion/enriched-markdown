import type { MarkdownStyle } from 'react-native-enriched-markdown';

// An after-hours session: an ink-dark stage, one warm amber lamp and one
// cool blue-note light; every cell is a piece of gear standing in it.
export const MIDNIGHT = '#07090F';
export const PANEL = '#121729';
export const PANEL_HIGH = '#1B2138';
export const RULE = '#232A44';
export const CREAM = '#F4EBDD';
export const SOFT = '#8C95B4';
export const BRASS = '#FFB547';
export const BLUE = '#5C8BFF';
export const RED = '#FF5A4E';
export const GREEN = '#4FD69C';
export const INK = '#1C1A24';
export const PAPER = '#F3EAD7';

// The stage behind the answer: the lamp's warmth pooling at the top.
export const STAGE_BACKGROUND =
  'radial-gradient(ellipse 120% 60% at 50% 0%, #2A1F12 0%, #07090F 70%)';

// A piece of gear: a brushed panel, lit from above.
export const GEAR_BACKGROUND =
  'linear-gradient(180deg, #171D33 0%, #0D1120 100%)';
export const GEAR_SHADOW =
  'inset 0 1px 0 rgba(255,255,255,0.07), 0 18px 36px -14px rgba(0,0,0,0.85)';

/** A coloured glow, for lights that are on. */
export function glow(color: string, radius = 14, alpha = 'AA') {
  return `0 0 ${radius}px ${color}${alpha}`;
}

export const FONTS = {
  display: 'Fraunces-SemiBold',
  serif: 'Newsreader-Regular',
  serifBold: 'Newsreader-SemiBold',
  italic: 'Newsreader-Italic',
  mono: 'DMMono-Regular',
  monoMedium: 'DMMono-Medium',
};

// The chord's function in the key, as a colour: home, away, and the pull back.
export const FUNCTION_COLORS: Record<string, string> = {
  I: BRASS,
  IV: BLUE,
  V: RED,
};

export function functionColor(numeral: string) {
  return FUNCTION_COLORS[numeral.replace('7', '')] ?? SOFT;
}

export const bluesMarkdownStyle: MarkdownStyle = {
  paragraph: {
    fontFamily: FONTS.serif,
    fontSize: 18,
    lineHeight: 27,
    color: CREAM,
    marginBottom: 14,
  },
  h1: {
    fontFamily: FONTS.display,
    fontSize: 32,
    lineHeight: 38,
    color: CREAM,
    marginBottom: 12,
  },
  h2: {
    fontFamily: FONTS.display,
    fontSize: 25,
    lineHeight: 31,
    color: CREAM,
    marginTop: 28,
    marginBottom: 8,
  },
  strong: { fontFamily: FONTS.serifBold, fontWeight: 'normal' },
  em: { fontFamily: FONTS.italic, fontStyle: 'italic' },
  code: {
    fontFamily: FONTS.mono,
    fontSize: 15,
    color: BRASS,
    backgroundColor: '#1A1E30',
    borderColor: '#2A3150',
  },
  link: { color: BRASS, underline: false, fontFamily: FONTS.serifBold },
  // Chords and notes in the prose are buttons: tap one to hear it.
  linkVariants: {
    '^chord:': {
      color: BRASS,
      fontFamily: FONTS.monoMedium,
      backgroundColor: '#2E2414',
      pill: {
        borderRadius: 8,
        paddingHorizontal: 8,
        paddingVertical: 1,
        borderWidth: 1,
        borderColor: '#7A5A22',
      },
    },
    '^note:': {
      color: '#A9C0FF',
      fontFamily: FONTS.monoMedium,
      backgroundColor: '#18234A',
      pill: {
        borderRadius: 8,
        paddingHorizontal: 8,
        paddingVertical: 1,
        borderWidth: 1,
        borderColor: '#3A54A8',
      },
    },
  },
  blockquote: {
    fontFamily: FONTS.italic,
    fontSize: 18,
    lineHeight: 27,
    color: SOFT,
    borderColor: BRASS,
    borderWidth: 2,
    gapWidth: 14,
    backgroundColor: 'transparent',
  },
  list: {
    fontFamily: FONTS.serif,
    fontSize: 18,
    lineHeight: 27,
    color: CREAM,
    bulletColor: BRASS,
    markerColor: BRASS,
    marginBottom: 14,
  },
};
