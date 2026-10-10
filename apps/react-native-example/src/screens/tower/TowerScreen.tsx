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
import { RadarBackdrop } from './RadarBackdrop';
import {
  COLORS,
  DETECTORS,
  FONT,
  STYLE_PILLS,
  STYLE_RAW,
  TRANSCRIPT,
  detectorFor,
  type Detector,
  type DetectorId,
} from './towerTheme';

type Props = RootStackScreenProps<'Tower'>;

/** Pieces safe to reveal one at a time: block markers travel with the next word. */
function tokenize(markdown: string): string[] {
  const atoms = markdown.match(/\s+|[^\s]+/g) ?? [];
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
const ALL: DetectorId[] = DETECTORS.map((d) => d.id);
const VERB: Record<DetectorId, string> = {
  flight: 'TRACKING',
  runway: 'RUNWAY',
  level: 'LEVEL',
  frequency: 'TUNED',
  stand: 'STAND',
  squawk: 'IDENT',
};

function pad(n: number): string {
  return String(n).padStart(2, '0');
}

/** Zulu clock, ticking. */
function ZuluClock() {
  const [seconds, setSeconds] = useState(22 * 3600 + 43 * 60 + 51);
  useEffect(() => {
    const timer = setInterval(() => setSeconds((v) => v + 1), 1000);
    return () => clearInterval(timer);
  }, []);
  return (
    <View style={styles.clock}>
      <Text style={styles.clockLabel}>UTC</Text>
      <Text style={styles.clockValue}>
        {pad(Math.floor(seconds / 3600) % 24)}:
        {pad(Math.floor(seconds / 60) % 60)}:{pad(seconds % 60)}Z
      </Text>
    </View>
  );
}

function PositionBadge() {
  const pulse = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 0.25,
          duration: 900,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 900,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <View style={styles.badge}>
      <Animated.View style={[styles.badgeDot, { opacity: pulse }]} />
      <Text style={styles.badgeText}>ON POSITION</Text>
    </View>
  );
}

/** Four corner ticks, the frame of a scope. */
function Corners({ color }: { color: string }) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      {(['tl', 'tr', 'bl', 'br'] as const).map((corner) => (
        <View
          key={corner}
          style={[styles.corner, styles[corner], { borderColor: color }]}
        />
      ))}
    </View>
  );
}

function Segment({
  value,
  onChange,
}: {
  value: boolean;
  onChange: (recognized: boolean) => void;
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
      {[false, true].map((recognized) => {
        const selected = recognized === value;
        return (
          <Pressable
            key={String(recognized)}
            style={styles.segmentItem}
            onPress={() => onChange(recognized)}
            testID={recognized ? 'tower-recognized' : 'tower-raw'}
          >
            <Text
              style={[
                styles.segmentLabel,
                selected && styles.segmentLabelSelected,
              ]}
            >
              {recognized ? 'RECOGNIZED' : 'RAW TRANSCRIPT'}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function Chip({
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
        styles.chip,
        on && {
          backgroundColor: `${detector.color}1F`,
          borderColor: `${detector.color}99`,
        },
        !enabled && styles.chipDisabled,
      ]}
      testID={`tower-detector-${detector.id}`}
    >
      <Image
        source={{ uri: detector.icon }}
        style={[
          styles.chipIcon,
          { tintColor: on ? detector.color : COLORS.faint },
        ]}
      />
      <Text style={[styles.chipLabel, on && { color: detector.color }]}>
        {detector.label}
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
      <View style={[styles.toastDot, { backgroundColor: toast.color }]} />
      <Text style={[styles.toastVerb, { color: toast.color }]}>
        {toast.verb}
      </Text>
      <Text style={styles.toastTarget} numberOfLines={1}>
        {toast.target}
      </Text>
    </Animated.View>
  );
}

export default function TowerScreen({ navigation }: Props) {
  const insets = useSafeAreaInsets();
  const [recognized, setRecognized] = useState(true);
  const [armed, setArmed] = useState<DetectorId[]>(ALL);
  const [shown, setShown] = useState(0);
  const [toast, setToast] = useState<Toast | null>(null);
  const toastId = useRef(0);

  useEffect(() => {
    Appearance.setColorScheme('dark');
    return () => Appearance.setColorScheme(null);
  }, []);

  // The transcript arrives a few words at a time; a match becomes a pill the moment it completes.
  useEffect(() => {
    const timer = setInterval(() => {
      setShown((value) => {
        if (value >= TOKENS.length) {
          clearInterval(timer);
          return value;
        }
        return value + 1;
      });
    }, 60);
    return () => clearInterval(timer);
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
  const linkRecognition = useMemo<LinkRecognition | undefined>(
    () => (recognized && pattern ? { text: new RegExp(pattern) } : undefined),
    [recognized, pattern]
  );

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
      '^[A-Z]{3}\\d': [
        { text: 'Show on scope', icon: 'scope', onPress: act('TRACKING') },
        {
          text: 'Hand off to ground',
          icon: 'arrow.turn.down.right',
          onPress: act('HANDED OFF'),
        },
        {
          text: 'Declare emergency',
          icon: 'exclamationmark.triangle',
          destructive: true,
          onPress: act('MAYDAY'),
        },
      ],
      '^\\d{2}[LRC]$': [
        { text: 'Runway status', icon: 'road.lanes', onPress: act('STATUS') },
        {
          text: 'Close runway',
          icon: 'xmark.octagon',
          destructive: true,
          onPress: act('CLOSED'),
        },
      ],
      '^FL\\d{3}$': [
        {
          text: 'Assign level',
          icon: 'arrow.up.arrow.down',
          onPress: act('ASSIGNED'),
        },
      ],
      '^1[1-3]\\d\\.': [
        { text: 'Tune', icon: 'dial.medium', onPress: act('TUNED') },
        { text: 'Monitor', icon: 'ear', onPress: act('MONITORING') },
      ],
      '^[A-Z]\\d{1,2}$': [
        { text: 'Assign stand', icon: 'parkingsign', onPress: act('ASSIGNED') },
      ],
      '^\\d{4}$': [
        {
          text: 'Request ident',
          icon: 'dot.radiowaves.left.and.right',
          onPress: act('IDENT'),
        },
      ],
    };
  }, [report]);

  const markdown = TOKENS.slice(0, shown).join('');
  const streaming = shown < TOKENS.length;

  return (
    <View style={styles.screen} testID="tower-screen">
      <StatusBar barStyle="light-content" />
      <RadarBackdrop />

      <ScrollView
        contentContainerStyle={[
          styles.content,
          { paddingTop: insets.top + 8, paddingBottom: insets.bottom + 84 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topRow}>
          <Pressable
            style={styles.back}
            onPress={navigation.goBack}
            hitSlop={12}
            testID="tower-back"
          >
            <Text style={styles.backGlyph}>{'‹'}</Text>
          </Pressable>
          <PositionBadge />
          <View style={styles.spacer} />
          <ZuluClock />
        </View>

        <Text style={styles.kicker}>APPROACH CONTROL</Text>
        <Text style={styles.title}>TOWER 27L</Text>
        <Text style={styles.subtitle}>
          Night ops {'·'} low visibility {'·'} crosswind 14 kt
        </Text>

        <View style={styles.console}>
          <Corners color={COLORS.green} />
          <View style={styles.consoleHeader}>
            <View style={styles.consoleDot} />
            <Text style={styles.consoleLabel}>
              {streaming ? 'RECEIVING · 118.5' : 'TRANSCRIPT · 118.5'}
            </Text>
            <View style={styles.spacer} />
            <Text style={styles.consoleMeta}>
              {recognized ? 'LINKS: RECOGNIZED' : 'LINKS: NONE IN SOURCE'}
            </Text>
          </View>
          <View style={styles.consoleBody}>
            <EnrichedMarkdownText
              markdown={markdown}
              markdownStyle={recognized ? STYLE_PILLS : STYLE_RAW}
              linkRecognition={linkRecognition}
              linkContextMenuItems={menus}
              streamingAnimation={streaming}
              onLinkPress={({ url }) =>
                report(VERB[detectorFor(url)?.id ?? 'flight'], url)
              }
              onLinkLongPress={({ url }) => report('HOLD', url)}
            />
          </View>
        </View>

        <Segment value={recognized} onChange={setRecognized} />

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chips}
        >
          {DETECTORS.map((detector) => (
            <Chip
              key={detector.id}
              detector={detector}
              armed={armed.includes(detector.id)}
              enabled={recognized}
              onToggle={toggle}
            />
          ))}
        </ScrollView>

        <View style={styles.readout}>
          <Text style={styles.readoutKey}>linkRecognition.text</Text>
          <Text style={styles.readoutValue} numberOfLines={1}>
            {linkRecognition ? `/${pattern}/` : 'undefined'}
          </Text>
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
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(74, 222, 128, 0.08)',
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
    borderColor: `${COLORS.green}88`,
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  badgeDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: COLORS.green,
  },
  badgeText: {
    fontFamily: FONT.semiBold,
    fontSize: 10.5,
    letterSpacing: 2,
    color: COLORS.green,
  },
  clock: { alignItems: 'flex-end' },
  clockLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 9.5,
    letterSpacing: 2.5,
    color: COLORS.faint,
  },
  clockValue: { fontFamily: FONT.mono, fontSize: 13, color: COLORS.text },

  kicker: {
    fontFamily: FONT.semiBold,
    fontSize: 11,
    letterSpacing: 4.5,
    color: COLORS.green,
  },
  title: {
    fontFamily: FONT.display,
    fontSize: 30,
    color: '#F0FDF4',
    marginTop: 5,
  },
  subtitle: {
    fontFamily: FONT.italic,
    fontSize: 15.5,
    color: COLORS.muted,
    marginTop: 6,
  },

  console: {
    marginTop: 18,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.line,
    backgroundColor: COLORS.panel,
    paddingHorizontal: 16,
    paddingBottom: 6,
  },
  consoleHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 10,
    marginBottom: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: COLORS.line,
  },
  consoleDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: COLORS.green,
  },
  consoleLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 10.5,
    letterSpacing: 2.2,
    color: COLORS.green,
  },
  consoleMeta: {
    fontFamily: FONT.mono,
    fontSize: 10,
    color: COLORS.faint,
  },
  consoleBody: { minHeight: 330 },
  corner: { position: 'absolute', width: 14, height: 14 },
  tl: {
    top: -1,
    left: -1,
    borderTopWidth: 2,
    borderLeftWidth: 2,
    borderTopLeftRadius: 16,
  },
  tr: {
    top: -1,
    right: -1,
    borderTopWidth: 2,
    borderRightWidth: 2,
    borderTopRightRadius: 16,
  },
  bl: {
    bottom: -1,
    left: -1,
    borderBottomWidth: 2,
    borderLeftWidth: 2,
    borderBottomLeftRadius: 16,
  },
  br: {
    bottom: -1,
    right: -1,
    borderBottomWidth: 2,
    borderRightWidth: 2,
    borderBottomRightRadius: 16,
  },

  segment: {
    flexDirection: 'row',
    marginTop: 12,
    padding: 3,
    borderRadius: 12,
    backgroundColor: 'rgba(4, 16, 12, 0.8)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
  },
  segmentThumb: {
    position: 'absolute',
    top: 3,
    bottom: 3,
    left: 3,
    borderRadius: 9,
    backgroundColor: COLORS.green,
    shadowColor: COLORS.green,
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
  segmentLabelSelected: { color: '#03140B' },

  chips: { gap: 8, paddingVertical: 12 },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 9,
    borderWidth: 1,
    borderColor: COLORS.line,
    backgroundColor: 'rgba(4, 16, 12, 0.8)',
  },
  chipDisabled: { opacity: 0.35 },
  chipIcon: { width: 13, height: 13 },
  chipLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 11,
    letterSpacing: 1.6,
    color: COLORS.muted,
  },

  readout: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: COLORS.line,
    backgroundColor: 'rgba(2, 7, 10, 0.7)',
  },
  readoutKey: { fontFamily: FONT.mono, fontSize: 10.5, color: COLORS.faint },
  readoutValue: {
    flex: 1,
    fontFamily: FONT.mono,
    fontSize: 11,
    color: COLORS.green,
  },

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
    borderRadius: 999,
    backgroundColor: 'rgba(2, 7, 10, 0.94)',
    borderWidth: 1,
    borderColor: COLORS.line,
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  toastDot: { width: 6, height: 6, borderRadius: 3 },
  toastVerb: { fontFamily: FONT.bold, fontSize: 11.5, letterSpacing: 1.8 },
  toastTarget: {
    flexShrink: 1,
    fontFamily: FONT.mono,
    fontSize: 12,
    color: COLORS.text,
  },
});
