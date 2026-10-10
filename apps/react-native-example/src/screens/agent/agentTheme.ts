import { Image } from 'react-native';
import type {
  LinkPillStyle,
  LinkVariantStyle,
  MarkdownStyle,
} from 'react-native-enriched-markdown';

const asset = (source: number) => Image.resolveAssetSource(source).uri;

export const FONT = {
  display: 'Michroma-Regular',
  body: 'ChakraPetch-Regular',
  medium: 'ChakraPetch-Medium',
  semiBold: 'ChakraPetch-SemiBold',
  bold: 'ChakraPetch-Bold',
  mono: 'SpaceMono-Regular',
  monoBold: 'SpaceMono-Bold',
};

// Dark glass, warm ember for what the agent touched, cool steel for who and what it talks to.
export const COLORS = {
  bg: '#0B0A0F',
  panel: 'rgba(17, 16, 24, 0.9)',
  chrome: 'rgba(28, 26, 38, 0.95)',
  line: 'rgba(148, 163, 184, 0.2)',
  text: '#E5E7EB',
  muted: '#9CA3AF',
  faint: '#5B6170',
  ember: '#FB923C',
  gold: '#FBBF24',
  steel: '#93C5FD',
  mint: '#6EE7B7',
  rose: '#FB7185',
};

const ICON = {
  file: asset(require('../../assets/agent/icons/file.png')),
  issue: asset(require('../../assets/agent/icons/issue.png')),
  skill: asset(require('../../assets/agent/icons/skill.png')),
  person: asset(require('../../assets/agent/icons/person.png')),
  commit: asset(require('../../assets/agent/icons/commit.png')),
};

export type DetectorId = 'file' | 'skill' | 'issue' | 'person' | 'commit';

export type Detector = {
  id: DetectorId;
  label: string;
  pattern: string;
  url: string;
  color: string;
  icon: string;
};

const FILE = '[\\w./-]+\\.(?:tsx?|jsx?|json|md)(?::\\d+)?';

export const DETECTORS: Detector[] = [
  {
    id: 'file',
    label: 'files',
    pattern: `\\b${FILE}\\b`,
    url: '\\.(?:tsx?|jsx?|json|md)(?::\\d+)?$',
    color: COLORS.ember,
    icon: ICON.file,
  },
  {
    id: 'skill',
    label: 'skills',
    pattern: '\\$[a-z][a-z0-9-]*',
    url: '^\\$',
    color: COLORS.gold,
    icon: ICON.skill,
  },
  {
    id: 'issue',
    label: 'issues',
    pattern: '#\\d+',
    url: '^#\\d+$',
    color: COLORS.steel,
    icon: ICON.issue,
  },
  {
    id: 'person',
    label: 'people',
    pattern: '@[a-z][a-z0-9_]*',
    url: '^@',
    color: COLORS.mint,
    icon: ICON.person,
  },
  {
    id: 'commit',
    label: 'commits',
    pattern: '\\b[0-9a-f]{7}\\b',
    url: '^[0-9a-f]{7}$',
    color: COLORS.ember,
    icon: ICON.commit,
  },
];

/** Whole inline-code spans that are file paths become file pills too. */
export const INLINE_CODE_PATTERN = FILE;

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
      fontFamily: FONT.monoBold,
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
    fontFamily: FONT.mono,
    fontSize: 14.5,
    // Pills are 25 tall; a fixed line height keeps the text still as they appear.
    lineHeight: 30,
    color: COLORS.text,
    marginBottom: 8,
  },
  h2: {
    fontFamily: FONT.display,
    fontSize: 11,
    color: COLORS.ember,
    marginBottom: 10,
  },
  strong: { fontFamily: FONT.monoBold, color: '#FFFFFF' },
  em: { fontFamily: FONT.mono, color: COLORS.muted },
  code: {
    fontFamily: FONT.mono,
    fontSize: 14.5,
    color: '#FDE68A',
    backgroundColor: 'rgba(251, 191, 36, 0.1)',
    borderColor: 'rgba(251, 191, 36, 0.25)',
  },
  link: { color: COLORS.steel, underline: true },
  blockquote: {
    fontFamily: FONT.mono,
    fontSize: 14.5,
    lineHeight: 30,
    color: '#CBD5E1',
    borderColor: COLORS.steel,
    borderWidth: 2,
    gapWidth: 12,
    backgroundColor: 'rgba(147, 197, 253, 0.07)',
    borderRadius: 6,
    marginBottom: 8,
  },
};

export const STYLE_RAW: MarkdownStyle = BASE;
export const STYLE_PILLS: MarkdownStyle = { ...BASE, linkVariants: VARIANTS };

// ---------------------------------------------------------------------------
// The agent's output for one turn, exactly as a model would write it.

export const PROMPT = 'fix the crash in the chat screen';

export const TRANSCRIPT =
  '## TURN 3 · tracing #1284\n\n' +
  'Reading `screens/Chat.tsx` and hooks/useStream.ts:42 to follow the stack @vega attached to #1284 yesterday.\n\n' +
  'The retry loop in `net/retry.ts` never backs off, so the stream reconnects in a tight loop. Loading $test-runner and $review.\n\n' +
  'Patched hooks/useStream.ts:42 and config/stream.json with a backoff. Committed as 4d1e9ab, 48 tests green via $test-runner.\n\n' +
  '> Review requested from @nova and @priya. Follow-ups filed as #1291 and #1292.\n\n' +
  'Next: @dana rotates the key in `creds.json`, then #1284 closes.';
