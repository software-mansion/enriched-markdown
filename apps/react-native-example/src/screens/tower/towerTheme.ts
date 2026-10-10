import { Image } from 'react-native';
import type {
  LinkPillStyle,
  LinkVariantStyle,
  MarkdownStyle,
} from 'react-native-enriched-markdown';

const asset = (source: number) => Image.resolveAssetSource(source).uri;

// Michroma, Chakra Petch and Space Mono (OFL), linked from assets/fonts.
export const FONT = {
  display: 'Michroma-Regular',
  body: 'ChakraPetch-Regular',
  italic: 'ChakraPetch-Italic',
  medium: 'ChakraPetch-Medium',
  semiBold: 'ChakraPetch-SemiBold',
  bold: 'ChakraPetch-Bold',
  mono: 'SpaceMono-Regular',
  monoBold: 'SpaceMono-Bold',
};

// Phosphor green on black glass, amber for anything on the ground.
export const COLORS = {
  bg: '#02070A',
  panel: 'rgba(4, 16, 12, 0.84)',
  line: 'rgba(74, 222, 128, 0.26)',
  text: '#DCFCE7',
  muted: '#86A892',
  faint: '#4E6B58',
  green: '#4ADE80',
  bright: '#A7F3D0',
  amber: '#FBBF24',
  red: '#FB7185',
};

// White duotone glyphs (Phosphor Icons, MIT), colored by tint.
const ICON = {
  flight: asset(require('../../assets/tower/icons/flight.png')),
  runway: asset(require('../../assets/tower/icons/runway.png')),
  frequency: asset(require('../../assets/tower/icons/frequency.png')),
  level: asset(require('../../assets/tower/icons/level.png')),
  squawk: asset(require('../../assets/tower/icons/squawk.png')),
  stand: asset(require('../../assets/tower/icons/stand.png')),
};

export type DetectorId =
  | 'flight'
  | 'runway'
  | 'level'
  | 'frequency'
  | 'stand'
  | 'squawk';

export type Detector = {
  id: DetectorId;
  label: string;
  pattern: string;
  /** Matches the recognized URL (the matched text) back to its detector. */
  url: string;
  color: string;
  icon: string;
};

export const DETECTORS: Detector[] = [
  {
    id: 'flight',
    label: 'FLIGHTS',
    pattern: '\\b[A-Z]{3}\\d{1,4}[A-Z]{0,2}\\b',
    url: '^[A-Z]{3}\\d',
    color: COLORS.green,
    icon: ICON.flight,
  },
  {
    id: 'runway',
    label: 'RUNWAYS',
    pattern: '\\b\\d{2}[LRC]\\b',
    url: '^\\d{2}[LRC]$',
    color: COLORS.amber,
    icon: ICON.runway,
  },
  {
    id: 'level',
    label: 'LEVELS',
    pattern: '\\bFL\\d{3}\\b',
    url: '^FL\\d{3}$',
    color: COLORS.bright,
    icon: ICON.level,
  },
  {
    id: 'frequency',
    label: 'FREQS',
    pattern: '\\b1[1-3]\\d\\.\\d{1,3}\\b',
    url: '^1[1-3]\\d\\.',
    color: COLORS.bright,
    icon: ICON.frequency,
  },
  {
    id: 'stand',
    label: 'STANDS',
    pattern: '\\b[A-Z]\\d{1,2}\\b',
    url: '^[A-Z]\\d{1,2}$',
    color: COLORS.amber,
    icon: ICON.stand,
  },
  {
    id: 'squawk',
    label: 'SQUAWK',
    pattern: '(?<=squawk )\\d{4}\\b',
    url: '^\\d{4}$',
    color: COLORS.green,
    icon: ICON.squawk,
  },
];

export function detectorFor(url: string): Detector | undefined {
  return DETECTORS.find((d) => new RegExp(d.url).test(url));
}

// ---------------------------------------------------------------------------
// Style

const pill: LinkPillStyle = {
  borderRadius: 6,
  paddingHorizontal: 7,
  paddingVertical: 2,
  borderWidth: 1,
};

const rgba = (hex: string, alpha: number) => {
  const channel = (i: number) => parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16);
  return `rgba(${channel(0)}, ${channel(1)}, ${channel(2)}, ${alpha})`;
};

const VARIANTS: Record<string, LinkVariantStyle> = Object.fromEntries(
  DETECTORS.map((d) => [
    d.url,
    {
      color: d.color,
      backgroundColor: rgba(d.color, 0.12),
      underline: false,
      fontFamily: FONT.semiBold,
      pill: {
        ...pill,
        borderColor: rgba(d.color, 0.5),
        iconUri: d.icon,
        iconTintColor: d.color,
      },
    } satisfies LinkVariantStyle,
  ])
);

const BASE: MarkdownStyle = {
  paragraph: {
    fontFamily: FONT.body,
    fontSize: 16,
    // Pills are 26 tall; a fixed line height keeps the text still as they appear.
    lineHeight: 31,
    color: COLORS.text,
    marginBottom: 8,
  },
  h2: {
    fontFamily: FONT.display,
    fontSize: 11.5,
    color: COLORS.green,
    marginBottom: 10,
  },
  strong: { fontFamily: FONT.mono, color: COLORS.faint },
  em: { fontFamily: FONT.italic, color: COLORS.muted },
  link: { color: COLORS.bright, underline: true },
  blockquote: {
    fontFamily: FONT.italic,
    fontSize: 16,
    lineHeight: 31,
    color: '#FDE68A',
    borderColor: COLORS.amber,
    borderWidth: 2,
    gapWidth: 12,
    backgroundColor: 'rgba(251, 191, 36, 0.08)',
    borderRadius: 6,
    marginBottom: 8,
  },
};

export const STYLE_RAW: MarkdownStyle = BASE;
export const STYLE_PILLS: MarkdownStyle = { ...BASE, linkVariants: VARIANTS };

// ---------------------------------------------------------------------------
// Transcript: raw tower comms. Not a single Markdown link in it.

export const TRANSCRIPT =
  '## 22:41Z · APPROACH & TOWER\n\n' +
  '**22:41:07** BAW117 contact tower 118.5, runway 27L, wind 240 at 14 knots.\n\n' +
  '**22:41:19** BAW117 cleared to land 27L, caution wake turbulence.\n\n' +
  '**22:41:40** DLH4EK hold short 27L, traffic on short final, squawk 4521.\n\n' +
  '**22:42:03** SAS1522 descend FL080, QNH 1009, expect ILS 27L.\n\n' +
  '> SUPERVISOR: 09R wet, braking action medium. Advise EZY53VT and RYR8TQ.\n\n' +
  '**22:42:30** EZY53VT go around, climb FL040, heading 180, traffic on the runway.\n\n' +
  '**22:43:02** BAW117 vacate via N4, contact ground 121.9, stand A12.';
