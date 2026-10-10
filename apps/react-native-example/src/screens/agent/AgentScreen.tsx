import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Appearance,
  Easing,
  Image,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownText,
  type LinkContextMenuItem,
  type LinkRecognition,
} from 'react-native-enriched-markdown';
import type { RootStackScreenProps } from '../../navigation/types';
import { TerminalBackdrop } from './TerminalBackdrop';
import {
  COLORS,
  DETECTORS,
  FONT,
  INLINE_CODE_PATTERN,
  PROMPT,
  STYLE_PILLS,
  STYLE_RAW,
  TRANSCRIPT,
  detectorFor,
  type Detector,
  type DetectorId,
} from './agentTheme';

type Props = RootStackScreenProps<'Agent'>;

/** Pieces safe to reveal one at a time: a code span is one piece, block markers travel with the next word. */
function tokenize(markdown: string): string[] {
  const atoms = markdown.match(/`[^`]*`|\s+|[^\s`]+/g) ?? [];
  const tokens: string[] = [];
  let carry = '';
  for (const atom of atoms) {
    if (/^\s+$/.test(atom)) {
      if (carry) carry += atom;
      else if (tokens.length) tokens[tokens.length - 1] += atom;
      continue;
    }
    if (/^(#{1,6}|>)$/.test(atom)) {
      carry += atom;
      continue;
    }
    tokens.push(carry + atom);
    carry = '';
  }
  return tokens;
}

const TOKENS = tokenize(TRANSCRIPT);
const PLAIN = TRANSCRIPT.replace(/`[^`]*`/g, ' ');
const CODE_SPANS = (TRANSCRIPT.match(/`[^`]*`/g) ?? []).map((s) =>
  s.slice(1, -1)
);
const HITS: Record<DetectorId, number> = Object.fromEntries(
  DETECTORS.map((d) => {
    let count = (PLAIN.match(new RegExp(d.pattern, 'g')) ?? []).length;
    if (d.id === 'file') {
      const whole = new RegExp(`^(?:${INLINE_CODE_PATTERN})$`);
      count += CODE_SPANS.filter((span) => whole.test(span)).length;
    }
    return [d.id, count];
  })
) as Record<DetectorId, number>;
const ALL: DetectorId[] = DETECTORS.map((d) => d.id);
const VERB: Record<DetectorId, string> = {
  file: 'OPEN',
  skill: 'RUN',
  issue: 'ISSUE',
  person: 'DM',
  commit: 'DIFF',
};

function Cursor() {
  const opacity = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 0,
          duration: 400,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 1,
          duration: 400,
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [opacity]);
  return <Animated.View style={[styles.cursor, { opacity }]} />;
}

function WorkingBadge({ working }: { working: boolean }) {
  const pulse = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    if (!working) {
      pulse.setValue(1);
      return;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 0.2,
          duration: 600,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 600,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [pulse, working]);
  const color = working ? COLORS.ember : COLORS.mint;
  return (
    <View style={[styles.badge, { borderColor: `${color}88` }]}>
      <Animated.View
        style={[styles.badgeDot, { backgroundColor: color, opacity: pulse }]}
      />
      <Text style={[styles.badgeText, { color }]}>
        {working ? 'AGENT · WORKING' : 'TURN COMPLETE'}
      </Text>
    </View>
  );
}

/** Tokens and seconds, counting while the agent writes. */
function Meter({ working, shown }: { working: boolean; shown: number }) {
  const [seconds, setSeconds] = useState(0);
  useEffect(() => {
    if (!working) return;
    const timer = setInterval(() => setSeconds((v) => v + 1), 1000);
    return () => clearInterval(timer);
  }, [working]);
  return (
    <View style={styles.meter}>
      <Text style={styles.meterLabel}>TOKENS · TIME</Text>
      <Text style={styles.meterValue}>
        {(2860 + shown * 3).toLocaleString()} · {seconds}s
      </Text>
    </View>
  );
}

function Segment({
  value,
  onChange,
}: {
  value: boolean;
  onChange: (pills: boolean) => void;
}) {
  const [width, setWidth] = useState(0);
  const offset = useRef(new Animated.Value(0)).current;
  const half = width / 2;
  useEffect(() => {
    Animated.spring(offset, {
      toValue: value ? half : 0,
      damping: 18,
      stiffness: 190,
      useNativeDriver: true,
    }).start();
  }, [half, offset, value]);
  const onLayout = (e: LayoutChangeEvent) =>
    setWidth(e.nativeEvent.layout.width - 6);
  return (
    <View style={styles.segment} onLayout={onLayout}>
      {width > 0 ? (
        <Animated.View
          style={[
            styles.segmentThumb,
            { width: half, transform: [{ translateX: offset }] },
          ]}
        />
      ) : null}
      {[false, true].map((pills) => {
        const selected = pills === value;
        return (
          <Pressable
            key={String(pills)}
            style={styles.segmentItem}
            onPress={() => onChange(pills)}
            testID={pills ? 'agent-pills' : 'agent-raw'}
          >
            <Text
              style={[
                styles.segmentLabel,
                selected && styles.segmentLabelSelected,
              ]}
            >
              {pills ? 'RECOGNIZED' : 'RAW OUTPUT'}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** One segment of a terminal status line: `files 5`. */
function StatusSegment({
  detector,
  armed,
  enabled,
  onToggle,
}: {
  detector: Detector;
  armed: boolean;
  enabled: boolean;
  onToggle: (id: DetectorId) => void;
}) {
  const on = armed && enabled;
  return (
    <Pressable
      onPress={() => onToggle(detector.id)}
      disabled={!enabled}
      style={[
        styles.status,
        on && { backgroundColor: `${detector.color}1A` },
        !enabled && styles.statusDisabled,
      ]}
      testID={`agent-detector-${detector.id}`}
    >
      <Image
        source={{ uri: detector.icon }}
        style={[
          styles.statusIcon,
          { tintColor: on ? detector.color : COLORS.faint },
        ]}
      />
      <Text style={[styles.statusLabel, on && { color: detector.color }]}>
        {detector.label}
      </Text>
      <Text style={[styles.statusCount, on && { color: detector.color }]}>
        {HITS[detector.id]}
      </Text>
    </Pressable>
  );
}

type Toast = { id: number; verb: string; target: string; color: string };

function ToastView({
  toast,
  bottom,
  onDone,
}: {
  toast: Toast;
  bottom: number;
  onDone: (id: number) => void;
}) {
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const run = Animated.sequence([
      Animated.timing(progress, {
        toValue: 1,
        duration: 220,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.delay(2000),
      Animated.timing(progress, {
        toValue: 0,
        duration: 200,
        easing: Easing.in(Easing.cubic),
        useNativeDriver: true,
      }),
    ]);
    run.start(({ finished }) => finished && onDone(toast.id));
    return () => run.stop();
  }, [onDone, progress, toast.id]);
  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.toast,
        {
          bottom,
          opacity: progress,
          transform: [
            {
              translateY: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [14, 0],
              }),
            },
          ],
        },
      ]}
    >
      <Text style={[styles.toastVerb, { color: toast.color }]}>
        {'$ '}
        {toast.verb.toLowerCase()}
      </Text>
      <Text style={styles.toastTarget} numberOfLines={1}>
        {toast.target}
      </Text>
    </Animated.View>
  );
}

export default function AgentScreen({ navigation }: Props) {
  const insets = useSafeAreaInsets();
  const [pills, setPills] = useState(false);
  const [armed, setArmed] = useState<DetectorId[]>(ALL);
  const [shown, setShown] = useState(0);
  const [toast, setToast] = useState<Toast | null>(null);
  const toastId = useRef(0);
  const scrollRef = useRef<ScrollView>(null);
  const viewportHeight = useRef(0);
  const controlsHeight = useRef(0);
  const scrolledTo = useRef(0);
  const userScrolled = useRef(false);

  useEffect(() => {
    Appearance.setColorScheme('dark');
    return () => Appearance.setColorScheme(null);
  }, []);

  useEffect(() => {
    let ticker: ReturnType<typeof setInterval> | undefined;
    const delay = setTimeout(() => {
      ticker = setInterval(() => {
        setShown((value) => {
          if (value >= TOKENS.length) {
            clearInterval(ticker);
            return value;
          }
          return value + 1;
        });
      }, 52);
    }, 2000);
    return () => {
      clearTimeout(delay);
      clearInterval(ticker);
    };
  }, []);

  const toggle = useCallback((id: DetectorId) => {
    setArmed((current) =>
      current.includes(id) ? current.filter((x) => x !== id) : [...current, id]
    );
  }, []);

  const pattern = useMemo(
    () =>
      DETECTORS.filter((d) => armed.includes(d.id))
        .map((d) => d.pattern)
        .join('|'),
    [armed]
  );
  const filesArmed = armed.includes('file');
  const linkRecognition = useMemo<LinkRecognition | undefined>(() => {
    if (!pills || !pattern) return undefined;
    return {
      text: new RegExp(pattern),
      inlineCode: filesArmed ? new RegExp(INLINE_CODE_PATTERN) : undefined,
    };
  }, [pills, pattern, filesArmed]);

  const report = useCallback((verb: string, url: string) => {
    toastId.current += 1;
    setToast({
      id: toastId.current,
      verb,
      target: url,
      color: detectorFor(url)?.color ?? COLORS.text,
    });
  }, []);
  const dismiss = useCallback((id: number) => {
    setToast((current) => (current?.id === id ? null : current));
  }, []);

  const menus = useMemo<Record<string, LinkContextMenuItem[]>>(() => {
    const act = (verb: string) => (e: { url: string }) => report(verb, e.url);
    return {
      '\\.(?:tsx?|jsx?|json|md)(?::\\d+)?$': [
        {
          text: 'Open in editor',
          icon: 'chevron.left.forwardslash.chevron.right',
          onPress: act('OPEN'),
        },
        { text: 'Reveal in tree', icon: 'folder', onPress: act('REVEAL') },
        { text: 'Copy path', icon: 'doc.on.doc', onPress: act('COPIED') },
      ],
      '^\\$': [
        { text: 'Run skill', icon: 'play', onPress: act('RUN') },
        {
          text: 'Show definition',
          icon: 'doc.text.magnifyingglass',
          onPress: act('SHOW'),
        },
      ],
      '^#\\d+$': [
        {
          text: 'Open issue',
          icon: 'arrow.up.right.square',
          onPress: act('ISSUE'),
        },
        { text: 'Link to this PR', icon: 'link', onPress: act('LINKED') },
      ],
      '^@': [
        {
          text: 'Request review',
          icon: 'person.badge.clock',
          onPress: act('REVIEW'),
        },
        { text: 'Open DM', icon: 'bubble.left', onPress: act('DM') },
      ],
      '^[0-9a-f]{7}$': [
        {
          text: 'Show diff',
          icon: 'plus.forwardslash.minus',
          onPress: act('DIFF'),
        },
        {
          text: 'Revert',
          icon: 'arrow.uturn.backward',
          destructive: true,
          onPress: act('REVERT'),
        },
      ],
    };
  }, [report]);

  const markdown = TOKENS.slice(0, shown).join('');
  const working = shown < TOKENS.length;

  // Follow the terminal as it grows so its newest line and the controls under it stay on screen.
  const followTerminal = useCallback(
    (e: LayoutChangeEvent) => {
      if (!working || userScrolled.current) return;
      const { y, height } = e.nativeEvent.layout;
      const target =
        y +
        height +
        controlsHeight.current +
        insets.bottom +
        12 -
        viewportHeight.current;
      if (target <= scrolledTo.current) return;
      scrolledTo.current = target;
      scrollRef.current?.scrollTo({ y: target, animated: true });
    },
    [insets.bottom, working]
  );

  return (
    <View style={styles.screen} testID="agent-screen">
      <StatusBar barStyle="light-content" />
      <TerminalBackdrop />

      <ScrollView
        ref={scrollRef}
        contentContainerStyle={[
          styles.content,
          { paddingTop: insets.top + 8, paddingBottom: insets.bottom + 84 },
        ]}
        showsVerticalScrollIndicator={false}
        onLayout={(e) => {
          viewportHeight.current = e.nativeEvent.layout.height;
        }}
        onScrollBeginDrag={() => {
          userScrolled.current = true;
        }}
      >
        <View style={styles.topRow}>
          <Pressable
            style={styles.back}
            onPress={navigation.goBack}
            hitSlop={12}
            testID="agent-back"
          >
            <Text style={styles.backGlyph}>{'‹'}</Text>
          </Pressable>
          <WorkingBadge working={working} />
          <View style={styles.spacer} />
          <Meter working={working} shown={shown} />
        </View>

        <Text style={styles.kicker}>CODING AGENT · SESSION 3F2A</Text>
        <Text style={styles.title}>
          <Text style={styles.prompt}>{'› '}</Text>
          {PROMPT}
        </Text>
        <Text style={styles.subtitle}>
          turn 3 of 3 {'·'} chat-mobile {'·'} fix/stream-retry
        </Text>

        <View style={styles.window} onLayout={followTerminal}>
          <View style={styles.chrome}>
            <View style={[styles.light, { backgroundColor: COLORS.rose }]} />
            <View style={[styles.light, { backgroundColor: COLORS.gold }]} />
            <View style={[styles.light, { backgroundColor: COLORS.mint }]} />
            <Text style={styles.chromeTitle}>agent — zsh — 80×24</Text>
            <View style={styles.spacer} />
            <Text style={styles.chromeMeta}>{pills ? 'pills' : 'raw'}</Text>
          </View>
          <View style={styles.body}>
            <EnrichedMarkdownText
              markdown={markdown}
              markdownStyle={pills ? STYLE_PILLS : STYLE_RAW}
              linkRecognition={linkRecognition}
              linkContextMenuItems={menus}
              streamingAnimation={working}
              onLinkPress={({ url }) =>
                report(VERB[detectorFor(url)?.id ?? 'file'], url)
              }
              onLinkLongPress={({ url }) => report('HOLD', url)}
            />
          </View>
          <View style={styles.statusLine}>
            {working ? (
              <>
                <Text style={[styles.statusText, { color: COLORS.ember }]}>
                  writing
                </Text>
                <Cursor />
              </>
            ) : (
              <Text style={[styles.statusText, { color: COLORS.mint }]}>
                ✓ turn complete · 48 tests green
              </Text>
            )}
            <View style={styles.spacer} />
            <Text style={styles.statusText} numberOfLines={1}>
              {pills ? '0 source links' : 'raw text'}
            </Text>
          </View>
        </View>

        <View
          onLayout={(e) => {
            controlsHeight.current = e.nativeEvent.layout.height;
          }}
        >
          <Segment value={pills} onChange={setPills} />

          <View style={styles.statusRow}>
            {DETECTORS.map((detector) => (
              <StatusSegment
                key={detector.id}
                detector={detector}
                armed={armed.includes(detector.id)}
                enabled={pills}
                onToggle={toggle}
              />
            ))}
          </View>

          <View style={styles.readout}>
            <Text style={styles.readoutLine} numberOfLines={1}>
              <Text style={styles.readoutKey}>text </Text>
              <Text style={styles.readoutValue}>
                {linkRecognition ? `/${pattern}/` : 'undefined'}
              </Text>
            </Text>
            <Text style={styles.readoutLine} numberOfLines={1}>
              <Text style={styles.readoutKey}>inlineCode </Text>
              <Text style={styles.readoutValue}>
                {linkRecognition?.inlineCode
                  ? `/${INLINE_CODE_PATTERN}/`
                  : 'undefined'}
              </Text>
            </Text>
          </View>
        </View>

        <Text style={styles.hint}>
          {Platform.OS === 'ios'
            ? 'TAP A PILL TO ACT · HOLD FOR ITS MENU'
            : 'TAP A PILL TO ACT · MENUS ARE IOS 17+'}
        </Text>
      </ScrollView>

      {toast ? (
        <ToastView
          key={toast.id}
          toast={toast}
          bottom={insets.bottom + 18}
          onDone={dismiss}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: COLORS.bg },
  content: { paddingHorizontal: 18 },
  spacer: { flex: 1 },

  topRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  back: {
    width: 38,
    height: 38,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(148, 163, 184, 0.1)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
    marginRight: 12,
  },
  backGlyph: {
    color: COLORS.text,
    fontSize: 26,
    lineHeight: 28,
    marginTop: -2,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  badgeDot: { width: 6, height: 6, borderRadius: 3 },
  badgeText: { fontFamily: FONT.semiBold, fontSize: 10.5, letterSpacing: 2 },
  meter: { alignItems: 'flex-end' },
  meterLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 9.5,
    letterSpacing: 2.5,
    color: COLORS.faint,
  },
  meterValue: { fontFamily: FONT.mono, fontSize: 13, color: COLORS.text },

  kicker: {
    fontFamily: FONT.semiBold,
    fontSize: 11,
    letterSpacing: 4,
    color: COLORS.ember,
  },
  title: {
    fontFamily: FONT.bold,
    fontSize: 25,
    lineHeight: 32,
    color: '#F9FAFB',
    marginTop: 6,
  },
  prompt: { fontFamily: FONT.monoBold, color: COLORS.ember },
  subtitle: {
    fontFamily: FONT.mono,
    fontSize: 13,
    color: COLORS.muted,
    marginTop: 6,
  },

  window: {
    marginTop: 18,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: COLORS.line,
    backgroundColor: COLORS.panel,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOpacity: 0.6,
    shadowRadius: 30,
    shadowOffset: { width: 0, height: 18 },
    elevation: 12,
  },
  chrome: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    paddingHorizontal: 14,
    paddingVertical: 10,
    backgroundColor: COLORS.chrome,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: COLORS.line,
  },
  light: { width: 11, height: 11, borderRadius: 6 },
  chromeTitle: {
    fontFamily: FONT.mono,
    fontSize: 11,
    color: COLORS.muted,
    marginLeft: 8,
  },
  chromeMeta: { fontFamily: FONT.mono, fontSize: 11, color: COLORS.faint },
  body: {
    minHeight: 330,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 14,
  },
  statusLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: COLORS.chrome,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: COLORS.line,
  },
  statusText: {
    flexShrink: 1,
    fontFamily: FONT.mono,
    fontSize: 11,
    color: COLORS.faint,
  },
  cursor: { width: 7, height: 13, backgroundColor: COLORS.ember },

  segment: {
    flexDirection: 'row',
    marginTop: 12,
    padding: 3,
    borderRadius: 12,
    backgroundColor: 'rgba(17, 16, 24, 0.85)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
  },
  segmentThumb: {
    position: 'absolute',
    top: 3,
    bottom: 3,
    left: 3,
    borderRadius: 9,
    backgroundColor: COLORS.ember,
    shadowColor: COLORS.ember,
    shadowOpacity: 0.7,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 0 },
  },
  segmentItem: { flex: 1, alignItems: 'center', paddingVertical: 10 },
  segmentLabel: {
    fontFamily: FONT.bold,
    fontSize: 11.5,
    letterSpacing: 1.6,
    color: COLORS.muted,
  },
  segmentLabelSelected: { color: '#1A0B02' },

  statusRow: {
    flexDirection: 'row',
    marginTop: 12,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
    backgroundColor: 'rgba(17, 16, 24, 0.85)',
    overflow: 'hidden',
  },
  status: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    paddingVertical: 9,
    borderRightWidth: StyleSheet.hairlineWidth,
    borderRightColor: COLORS.line,
  },
  statusDisabled: { opacity: 0.35 },
  statusIcon: { width: 11, height: 11 },
  statusLabel: { fontFamily: FONT.mono, fontSize: 10.5, color: COLORS.muted },
  statusCount: {
    fontFamily: FONT.monoBold,
    fontSize: 10.5,
    color: COLORS.faint,
  },

  readout: {
    marginTop: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
    backgroundColor: 'rgba(11, 10, 15, 0.75)',
    gap: 2,
  },
  readoutLine: { fontFamily: FONT.mono, fontSize: 11 },
  readoutKey: { color: COLORS.faint },
  readoutValue: { color: COLORS.ember },

  hint: {
    textAlign: 'center',
    fontFamily: FONT.semiBold,
    fontSize: 10.5,
    letterSpacing: 2,
    color: COLORS.faint,
    marginTop: 14,
  },

  toast: {
    position: 'absolute',
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    maxWidth: '88%',
    paddingHorizontal: 16,
    paddingVertical: 11,
    borderRadius: 10,
    backgroundColor: 'rgba(11, 10, 15, 0.95)',
    borderWidth: 1,
    borderColor: COLORS.line,
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  toastVerb: { fontFamily: FONT.monoBold, fontSize: 12 },
  toastTarget: {
    flexShrink: 1,
    fontFamily: FONT.mono,
    fontSize: 12,
    color: COLORS.text,
  },
});
