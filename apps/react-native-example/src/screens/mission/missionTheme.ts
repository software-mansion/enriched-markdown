import { Image } from 'react-native';
import type {
  LinkPillContent,
  LinkPillStyle,
  LinkVariantStyle,
  MarkdownStyle,
} from 'react-native-enriched-markdown';

const asset = (source: number) => Image.resolveAssetSource(source).uri;

// Fonts linked from assets/fonts: Michroma, Chakra Petch and Space Mono (OFL).
export const FONT = {
  display: 'Michroma-Regular',
  body: 'ChakraPetch-Regular',
  bodyItalic: 'ChakraPetch-Italic',
  medium: 'ChakraPetch-Medium',
  semiBold: 'ChakraPetch-SemiBold',
  bold: 'ChakraPetch-Bold',
  mono: 'SpaceMono-Regular',
  monoBold: 'SpaceMono-Bold',
};

export const COLORS = {
  space: '#04060F',
  panel: 'rgba(9, 14, 32, 0.82)',
  panelLine: 'rgba(94, 234, 212, 0.28)',
  text: '#E2E8F0',
  muted: '#94A3B8',
  faint: '#64748B',
  cyan: '#5EEAD4',
  sky: '#7DD3FC',
  violet: '#C4B5FD',
  amber: '#FBBF24',
  red: '#FB7185',
  green: '#4ADE80',
  mars: '#FB923C',
};

// White duotone glyphs (Phosphor Icons, MIT): every one is colored by a tint.
export const ICON = {
  module: asset(require('../../assets/mission/icons/cube-focus.png')),
  rover: asset(require('../../assets/mission/icons/rocket-launch.png')),
  pin: asset(require('../../assets/mission/icons/map-pin.png')),
  code: asset(require('../../assets/mission/icons/file-code.png')),
  csv: asset(require('../../assets/mission/icons/file-csv.png')),
  chart: asset(require('../../assets/mission/icons/chart-line-up.png')),
  channel: asset(require('../../assets/mission/icons/hash.png')),
  oxygen: asset(require('../../assets/mission/icons/wind.png')),
  power: asset(require('../../assets/mission/icons/lightning.png')),
  thermal: asset(require('../../assets/mission/icons/thermometer-simple.png')),
  comms: asset(require('../../assets/mission/icons/broadcast.png')),
  warning: asset(require('../../assets/mission/icons/warning.png')),
  vitals: asset(require('../../assets/mission/icons/heartbeat.png')),
  planet: asset(require('../../assets/mission/icons/planet.png')),
};

// Illustrated portraits (DiceBear "lorelei", CC0).
const CREW = {
  vega: asset(require('../../assets/mission/crew/crew_vega.png')),
  okoro: asset(require('../../assets/mission/crew/crew_okoro.png')),
  reyes: asset(require('../../assets/mission/crew/crew_reyes.png')),
  lind: asset(require('../../assets/mission/crew/crew_lindqvist.png')),
  tanaka: asset(require('../../assets/mission/crew/crew_tanaka.png')),
};

const FILES = 'https://ares.space/files';
export const FILE = {
  plan: `${FILES}/nav/sol214/traverse_plan_v7.json`,
  spectra: `${FILES}/science/sol213/spectra_batch_12.csv`,
  drill: `${FILES}/eng/drill/telemetry_sol213.chart`,
};

// ---------------------------------------------------------------------------
// Style: one variant per kind of link.

const pill: LinkPillStyle = {
  borderRadius: 999,
  paddingHorizontal: 8,
  paddingVertical: 2,
  borderWidth: 1,
};

const variant = (
  color: string,
  background: string,
  border: string,
  extra: LinkPillStyle
): LinkVariantStyle => ({
  color,
  backgroundColor: background,
  underline: false,
  fontFamily: FONT.semiBold,
  pill: { ...pill, borderColor: border, ...extra },
});

const PILL_VARIANTS: Record<string, LinkVariantStyle> = {
  // Crew pills take their portrait from `linkPillContent`; the tint below only
  // colors this fallback glyph, never a portrait.
  '^crew:': variant(
    '#E0F2FE',
    'rgba(56, 189, 248, 0.14)',
    'rgba(125, 211, 252, 0.55)',
    { iconUri: ICON.vitals, iconTintColor: COLORS.sky }
  ),
  '^module:': variant(
    '#EDE9FE',
    'rgba(167, 139, 250, 0.16)',
    'rgba(196, 181, 253, 0.55)',
    { iconUri: ICON.module, iconTintColor: COLORS.violet }
  ),
  '^nav:': variant(
    '#FEF3C7',
    'rgba(251, 191, 36, 0.14)',
    'rgba(251, 191, 36, 0.55)',
    { iconUri: ICON.pin, iconTintColor: COLORS.amber }
  ),
  '^chan:': variant(
    '#FFE4E6',
    'rgba(251, 113, 133, 0.14)',
    'rgba(251, 113, 133, 0.5)',
    { iconUri: ICON.channel, iconTintColor: COLORS.red }
  ),
  '^https://ares\\.space/files/': variant(
    '#CCFBF1',
    'rgba(94, 234, 212, 0.12)',
    'rgba(94, 234, 212, 0.5)',
    { iconUri: ICON.code, iconTintColor: COLORS.cyan, maxWidth: 230 }
  ),
  // Systems are neutral: each link's reading and status color come per link.
  '^sys:': variant(
    '#E2E8F0',
    'rgba(148, 163, 184, 0.14)',
    'rgba(148, 163, 184, 0.4)',
    { borderRadius: 8, iconUri: ICON.planet, iconTintColor: COLORS.muted }
  ),
};

const BASE_STYLE: MarkdownStyle = {
  paragraph: {
    fontFamily: FONT.body,
    fontSize: 16.5,
    // A pill here is 28 tall. The same line height with and without pills keeps text
    // still while a streamed link turns into a pill, and leaves 4 between stacked pills.
    lineHeight: 32,
    color: COLORS.text,
    marginBottom: 10,
  },
  h2: {
    fontFamily: FONT.display,
    fontSize: 12,
    color: COLORS.cyan,
    marginBottom: 10,
  },
  strong: { fontFamily: FONT.bold, color: '#FFFFFF' },
  em: { fontFamily: FONT.bodyItalic, color: COLORS.muted },
  code: {
    fontFamily: FONT.mono,
    fontSize: 13,
    color: COLORS.cyan,
    backgroundColor: 'rgba(94, 234, 212, 0.1)',
    borderColor: 'rgba(94, 234, 212, 0.25)',
  },
  link: { color: COLORS.sky, underline: true },
  blockquote: {
    fontFamily: FONT.bodyItalic,
    fontSize: 16.5,
    lineHeight: 32,
    color: '#CBD5E1',
    borderColor: COLORS.mars,
    borderWidth: 2,
    gapWidth: 12,
    backgroundColor: 'rgba(251, 146, 60, 0.1)',
    borderRadius: 6,
    marginBottom: 10,
  },
  list: {
    fontFamily: FONT.body,
    fontSize: 16.5,
    lineHeight: 32,
    color: COLORS.text,
    bulletColor: COLORS.cyan,
    bulletSize: 6,
    gapWidth: 8,
    marginLeft: 2,
    itemSpacing: 7,
    marginBottom: 10,
  },
  table: {
    fontFamily: FONT.body,
    fontSize: 14.5,
    color: COLORS.text,
    headerFontFamily: FONT.semiBold,
    headerBackgroundColor: '#10203A',
    headerTextColor: COLORS.cyan,
    rowEvenBackgroundColor: '#0B1228',
    rowOddBackgroundColor: '#0E1630',
    borderColor: 'rgba(148, 163, 184, 0.22)',
    borderWidth: 1,
    borderRadius: 10,
    cellPaddingHorizontal: 11,
    cellPaddingVertical: 9,
    marginBottom: 10,
  },
};

export const STYLE_PILLS: MarkdownStyle = {
  ...BASE_STYLE,
  linkVariants: PILL_VARIANTS,
};
// The same links with no variants: what the Markdown looks like without pills.
export const STYLE_RAW: MarkdownStyle = BASE_STYLE;

// ---------------------------------------------------------------------------
// Content: per-link label, icon and tint, keyed by exact URL.

const CREW_CONTENT: Record<string, LinkPillContent> = {
  'crew:vega': { iconUri: CREW.vega },
  'crew:okoro': { iconUri: CREW.okoro },
  'crew:reyes': { iconUri: CREW.reyes },
  'crew:lind': { iconUri: CREW.lind },
  'crew:tanaka': { iconUri: CREW.tanaka },
};

const STATIC_CONTENT: Record<string, LinkPillContent> = {
  ...CREW_CONTENT,
  'module:rover-1': { iconUri: ICON.rover, iconTintColor: COLORS.violet },
  [FILE.spectra]: { iconUri: ICON.csv, iconTintColor: COLORS.cyan },
  [FILE.drill]: { iconUri: ICON.chart, iconTintColor: COLORS.cyan },
};

export type Weather = 'nominal' | 'storm';

const reading = (
  label: string,
  iconUri: string,
  iconTintColor: string
): LinkPillContent => ({ label, iconUri, iconTintColor });

export const CONTENT: Record<Weather, Record<string, LinkPillContent>> = {
  nominal: {
    ...STATIC_CONTENT,
    'sys:o2': reading('O₂ 98%', ICON.oxygen, COLORS.green),
    'sys:power': reading('Solar 4.2 kW', ICON.power, COLORS.green),
    'sys:thermal': reading('21.4 °C', ICON.thermal, COLORS.green),
    'sys:comms': reading('Relay locked', ICON.comms, COLORS.green),
  },
  storm: {
    ...STATIC_CONTENT,
    'sys:o2': reading('O₂ 97%', ICON.oxygen, COLORS.green),
    'sys:power': reading('Solar 1.1 kW', ICON.power, COLORS.amber),
    'sys:thermal': reading('17.9 °C', ICON.thermal, COLORS.amber),
    'sys:comms': reading('Relay lost', ICON.warning, COLORS.red),
  },
};

// ---------------------------------------------------------------------------
// Markdown: three pages of one mission log. Systems never change their
// Markdown; only `linkPillContent` does.

export type Page = 'log' | 'systems' | 'crew';

export const MARKDOWN: Record<Page, string> = {
  log:
    '## SOL 214 · 06:42 LMST\n\n' +
    '[Cmdr. Vega](crew:vega) cleared [Hab-2](module:hab-2) for EVA. ' +
    '[Okoro](crew:okoro) and [Reyes](crew:reyes) take [Rover-1](module:rover-1) ' +
    'to [4.59°S 137.44°E](nav:gale-crater), following ' +
    `[traverse_plan_v7.json](${FILE.plan}).\n\n` +
    '> Dust is settling. We roll at first light. — [Vega](crew:vega)\n\n' +
    `Uplink [spectra_batch_12.csv](${FILE.spectra}) and the ` +
    `[drill telemetry](${FILE.drill}) on [science](chan:science).`,
  systems:
    '## SYSTEMS · HAB-2\n\n' +
    '| System | Reading | Owner |\n' +
    '| :-- | :-- | :-- |\n' +
    '| Air | [o2](sys:o2) | [Tanaka](crew:tanaka) |\n' +
    '| Power | [power](sys:power) | [Okoro](crew:okoro) |\n' +
    '| Heat | [thermal](sys:thermal) | [Lind](crew:lind) |\n' +
    '| Comms | [comms](sys:comms) | [Reyes](crew:reyes) |\n\n' +
    'Same Markdown all along. Only each pill’s **label** and **tint** change.',
  crew:
    '## CREW · 5 ABOARD\n\n' +
    '- [Vega](crew:vega) commander · [Hab-2](module:hab-2)\n' +
    '- [Okoro](crew:okoro) engineer · [Rover-1](module:rover-1)\n' +
    '- [Reyes](crew:reyes) pilot · [Rover-1](module:rover-1)\n' +
    '- [Lind](crew:lind) geologist · [Lab](module:lab)\n' +
    '- [Tanaka](crew:tanaka) surgeon · [Hab-2](module:hab-2)\n\n' +
    '*Hold a name or a module for its menu.*',
};
