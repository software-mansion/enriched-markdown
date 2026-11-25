import type { MarkdownStyle } from 'react-native-enriched-markdown';

// A sunset-over-the-coast palette: hot pink, teal and orange on deep purple.
export const NIGHT = '#0E0718';
export const PANEL = '#1A0F2B';
export const PANEL_HI = '#26163D';
export const RULE = '#3A2556';
export const TEXT = '#F6EEFF';
export const TEXT_SOFT = '#A893C4';
export const PINK = '#FF4FA3';
export const TEAL = '#2EE6D6';
export const ORANGE = '#FF9E3D';
export const GREEN = '#7CFF9B';

export const FONTS = {
  display: 'BebasNeue-Regular',
  sans: 'Poppins-Regular',
  sansMedium: 'Poppins-Medium',
  sansBold: 'Poppins-SemiBold',
  italic: 'Poppins-Italic',
  mono: 'DMMono-Regular',
  monoMedium: 'DMMono-Medium',
};

// @handles, #tags and $amounts become pills, with no link syntax in the text.
export const linkRecognition = { text: /[@#]\w+|\$\d[\d,]*k?/ };

const linkVariants: MarkdownStyle['linkVariants'] = {
  '^@': {
    color: TEAL,
    backgroundColor: 'rgba(46, 230, 214, 0.14)',
    underline: false,
    pill: { borderRadius: 6, paddingHorizontal: 5, paddingVertical: 1 },
  },
  '^#': {
    color: PINK,
    backgroundColor: 'rgba(255, 79, 163, 0.14)',
    underline: false,
    pill: { borderRadius: 6, paddingHorizontal: 5, paddingVertical: 1 },
  },
  '^\\$': {
    color: GREEN,
    backgroundColor: 'rgba(124, 255, 155, 0.12)',
    underline: false,
    fontFamily: FONTS.monoMedium,
    pill: { borderRadius: 6, paddingHorizontal: 5, paddingVertical: 1 },
  },
};

const shared: MarkdownStyle = {
  strong: { fontFamily: FONTS.sansBold, fontWeight: 'normal', color: TEXT },
  em: { fontFamily: FONTS.italic, fontStyle: 'normal' },
  code: {
    fontFamily: FONTS.mono,
    fontSize: 13,
    color: ORANGE,
    backgroundColor: 'rgba(255, 158, 61, 0.12)',
    borderColor: 'rgba(255, 158, 61, 0.3)',
  },
  link: { color: TEAL, underline: true },
  linkVariants,
  spoiler: { color: PINK },
  highlight: { color: NIGHT, backgroundColor: ORANGE },
  strikethrough: { color: PINK },
};

export const chatMarkdownStyle: MarkdownStyle = {
  ...shared,
  paragraph: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 21,
    color: TEXT,
    marginBottom: 6,
  },
  list: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 21,
    color: TEXT,
    bulletColor: PINK,
    markerColor: PINK,
    marginBottom: 6,
  },
  taskList: {
    checkedColor: PINK,
    borderColor: TEXT_SOFT,
    checkmarkColor: NIGHT,
    checkedTextColor: TEXT_SOFT,
    checkedStrikethrough: true,
  },
};

export const jobMarkdownStyle: MarkdownStyle = {
  ...shared,
  paragraph: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 23,
    color: TEXT,
    marginBottom: 12,
  },
  h1: {
    fontFamily: FONTS.display,
    fontSize: 46,
    lineHeight: 48,
    color: PINK,
    marginBottom: 4,
  },
  h2: {
    fontFamily: FONTS.display,
    fontSize: 26,
    lineHeight: 30,
    color: TEAL,
    marginTop: 14,
    marginBottom: 6,
  },
  blockquote: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 22,
    color: TEXT,
    borderColor: ORANGE,
    borderWidth: 3,
    gapWidth: 12,
    backgroundColor: PANEL,
    borderRadius: 10,
    padding: 12,
    marginBottom: 14,
    admonitions: {
      important: { color: ORANGE, backgroundColor: 'rgba(255,158,61,0.10)' },
      warning: { color: PINK, backgroundColor: 'rgba(255,79,163,0.10)' },
    },
  },
  list: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 22,
    color: TEXT,
    bulletColor: PINK,
    markerColor: PINK,
    markerFontWeight: 'bold',
    itemSpacing: 6,
    marginBottom: 12,
  },
  taskList: {
    checkedColor: TEAL,
    borderColor: TEAL,
    checkboxBorderRadius: 4,
    checkmarkColor: NIGHT,
    checkedTextColor: TEXT_SOFT,
    checkedStrikethrough: true,
  },
  table: {
    fontFamily: FONTS.sans,
    fontSize: 14,
    lineHeight: 20,
    color: TEXT,
    headerFontFamily: FONTS.monoMedium,
    headerBackgroundColor: PANEL_HI,
    headerTextColor: TEAL,
    rowEvenBackgroundColor: PANEL,
    rowOddBackgroundColor: NIGHT,
    borderColor: RULE,
    borderWidth: 1,
    borderRadius: 10,
    cellPaddingHorizontal: 10,
    cellPaddingVertical: 8,
    marginBottom: 14,
  },
  thematicBreak: { color: RULE, height: 1, marginTop: 6, marginBottom: 16 },
};

export const feedMarkdownStyle: MarkdownStyle = {
  ...shared,
  paragraph: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 22,
    color: TEXT,
    marginBottom: 4,
  },
  list: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 22,
    color: TEXT,
    bulletColor: TEAL,
    markerColor: TEAL,
    marginBottom: 4,
  },
};
