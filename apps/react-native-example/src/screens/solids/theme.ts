import type { MarkdownStyle } from 'react-native-enriched-markdown';

export const NIGHT = '#08080F';
export const PANEL = '#11111C';
export const RULE = '#22223A';
export const TEXT = '#E7E5F2';
export const TEXT_SOFT = '#8D8AA8';
export const VIOLET = '#9D7BFF';

export const FONTS = {
  sans: 'Montserrat-Regular',
  sansMedium: 'Montserrat-Medium',
  sansBold: 'Montserrat-SemiBold',
  italic: 'Montserrat-Italic',
  mono: 'DMMono-Regular',
  monoMedium: 'DMMono-Medium',
};

// Each solid's colour by the function's name, in linear RGB for the shader.
const TINTS: Record<string, [number, number, number]> = {
  sphere: [0.62, 0.5, 1],
  pawn: [1, 0.86, 0.62],
  mandelbulb: [0.3, 0.75, 1],
};

export function tintFor(name: string): [number, number, number] {
  const known = TINTS[name];
  if (known) return known;
  let hash = 0;
  for (let i = 0; i < name.length; i++)
    hash = (hash * 31 + name.charCodeAt(i)) | 0;
  const hue = ((hash % 360) + 360) % 360;
  const k = (n: number) => (n + hue / 60) % 6;
  const f = (n: number) => 1 - 0.55 * Math.max(0, Math.min(k(n), 4 - k(n), 1));
  return [f(5), f(3), f(1)];
}

// The tint as a CSS colour, gamma-encoded like the shader's output.
export function tintColor(name: string, alpha = 1) {
  const [r, g, b] = tintFor(name).map((c) =>
    Math.round(255 * Math.pow(c, 1 / 2.2))
  );
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const solidsMarkdownStyle: MarkdownStyle = {
  paragraph: {
    fontFamily: FONTS.sans,
    fontSize: 16,
    lineHeight: 25,
    color: TEXT,
    marginBottom: 14,
  },
  h1: {
    fontFamily: FONTS.sansBold,
    fontSize: 30,
    lineHeight: 36,
    color: TEXT,
    marginBottom: 12,
  },
  h2: {
    fontFamily: FONTS.sansBold,
    fontSize: 20,
    lineHeight: 26,
    color: TEXT,
    marginTop: 18,
    marginBottom: 8,
  },
  strong: { fontFamily: FONTS.sansBold, fontWeight: 'normal' },
  em: { fontFamily: FONTS.italic, fontStyle: 'italic' },
  code: {
    fontFamily: FONTS.mono,
    fontSize: 14,
    color: VIOLET,
    backgroundColor: '#1A1830',
    borderColor: '#2A2650',
  },
  link: { color: VIOLET, underline: true },
  math: {
    fontSize: 19,
    color: TEXT,
    backgroundColor: 'transparent',
    padding: 4,
    marginTop: 2,
    marginBottom: 14,
    textAlign: 'center',
  },
  inlineMath: { color: TEXT },
};
