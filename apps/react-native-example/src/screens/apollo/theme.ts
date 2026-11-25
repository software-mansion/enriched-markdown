import { Platform } from 'react-native';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

export const SPACE = '#07090D';
export const PANEL = '#12161D';
export const PANEL_EDGE = '#232A35';
export const CONSOLE = '#2B3038';
export const CONSOLE_EDGE = '#454C57';
export const PAPER = '#EEE9DC';
export const PAPER_SOFT = '#9AA3B2';
export const STAR = '#F4F1EA';
// The DSKY's electroluminescent digits and the caution lamps beside them.
export const EL = '#8DFF7A';
export const EL_DIM = '#1B2A1A';
export const AMBER = '#FFB547';
export const AMBER_DIM = '#3A2E1C';
export const SIGNAL = '#E5482F';
export const NASA_BLUE = '#3D7BFF';
export const CARD_LABEL = '#C3CAD6';
// The top edge of a card, catching the light so it lifts off the sky.
export const CARD_HIGHLIGHT = '#33404F';

// One muted accent per component, shared by the card's chip and its tag on
// the Duo's source page, so the eye pairs the two without reading.
export const RENDERER_ACCENTS: Record<string, string> = {
  Timeline: '#8FB8FF',
  Flowchart: '#B9A3FF',
  DescentTrace: '#7FE3C8',
  Transmission: '#FFB08A',
  Dsky: '#A8E89A',
  Printout: '#E8DCC0',
};

export function accentFor(renderer: string) {
  return RENDERER_ACCENTS[renderer] ?? PAPER_SOFT;
}

export const FONTS = {
  display: 'BebasNeue-Regular',
  heading: 'Montserrat-Bold',
  label: 'Montserrat-SemiBold',
  body: 'Newsreader-Regular',
  bodyBold: 'Newsreader-SemiBold',
  bodyItalic: 'Newsreader-Italic',
  typewriter: 'CourierPrime-Regular',
  hand: 'Caveat-Regular',
  handBold: 'Caveat-Bold',
  mono: 'DMMono-Regular',
  monoMedium: 'DMMono-Medium',
};

export const journalSelection = Platform.select({
  ios: { selectionColor: AMBER },
  default: {
    selectionColor: 'rgba(255, 181, 71, 0.35)',
    selectionHandleColor: AMBER,
  },
});

export const journalMarkdownStyle: MarkdownStyle = {
  paragraph: {
    fontFamily: FONTS.body,
    fontSize: 18,
    lineHeight: 27,
    color: PAPER,
    marginBottom: 16,
  },
  h1: {
    fontFamily: FONTS.display,
    fontSize: 64,
    lineHeight: 60,
    color: STAR,
    marginBottom: 8,
  },
  h2: {
    fontFamily: FONTS.heading,
    fontSize: 15,
    lineHeight: 20,
    color: STAR,
    marginTop: 22,
    marginBottom: 10,
  },
  h3: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11.5,
    lineHeight: 18,
    color: PAPER_SOFT,
    marginBottom: 20,
  },
  blockquote: {
    fontFamily: FONTS.bodyItalic,
    fontSize: 20,
    lineHeight: 28,
    color: STAR,
    borderColor: AMBER,
    borderWidth: 2,
    gapWidth: 16,
    backgroundColor: 'transparent',
    marginTop: 4,
    marginBottom: 20,
  },
  strong: { fontFamily: FONTS.bodyBold, fontWeight: 'normal', color: STAR },
  em: {
    fontFamily: FONTS.bodyItalic,
    fontStyle: Platform.OS === 'ios' ? 'italic' : 'normal',
  },
  link: { color: STAR, underline: true },
  code: {
    fontFamily: FONTS.monoMedium,
    fontSize: 15,
    color: EL,
    backgroundColor: 'rgba(141, 255, 122, 0.08)',
    borderColor: 'transparent',
  },
  codeBlock: { marginTop: 10, marginBottom: 26 },
};
