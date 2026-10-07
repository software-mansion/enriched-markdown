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
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownText,
  type LinkContextMenuItem,
  type LinkPressEvent,
} from 'react-native-enriched-markdown';
import type { RootStackScreenProps } from '../../navigation/types';
import { SpaceBackdrop } from './SpaceBackdrop';
import {
  COLORS,
  CONTENT,
  FONT,
  MARKDOWN,
  STYLE_PILLS,
  STYLE_RAW,
  type Page,
  type Weather,
} from './missionTheme';

type Props = RootStackScreenProps<'Mission'>;

const PAGES: { id: Page; label: string; icon: number }[] = [
  {
    id: 'log',
    label: 'LOG',
    icon: require('../../assets/mission/icons/broadcast.png'),
  },
  {
    id: 'systems',
    label: 'SYSTEMS',
    icon: require('../../assets/mission/icons/cpu.png'),
  },
  {
    id: 'crew',
    label: 'CREW',
    icon: require('../../assets/mission/icons/heartbeat.png'),
  },
];

const WARNING_ICON = require('../../assets/mission/icons/warning.png');
const SHIELD_ICON = require('../../assets/mission/icons/shield-check.png');

/**
 * Splits Markdown into pieces that are safe to reveal one at a time: a link is
 * one piece, and a block marker travels with the word that follows it, so a
 * half-written link or a bare `##` never reaches the renderer.
 */
function tokenize(markdown: string): string[] {
  const atoms = markdown.match(/\[[^\]]*\]\([^)]*\)|\s+|[^\s[]+/g) ?? [];
  const tokens: string[] = [];
  let carry = '';
  for (const atom of atoms) {
    if (/^\s+$/.test(atom)) {
      if (carry) carry += atom;
      else if (tokens.length) tokens[tokens.length - 1] += atom;
      continue;
    }
    if (/^(#{1,6}|>|-)$/.test(atom)) {
      carry += atom;
      continue;
    }
    tokens.push(carry + atom);
    carry = '';
  }
  return tokens;
}

const LOG_TOKENS = tokenize(MARKDOWN.log);

/** `crew:vega` -> `VEGA`, a file URL -> its file name. */
function nameOf(url: string): string {
  const tail = url.includes('/')
    ? url.slice(url.lastIndexOf('/') + 1)
    : url.slice(url.indexOf(':') + 1);
  return tail.toUpperCase();
}

function pad(n: number): string {
  return String(n).padStart(2, '0');
}

/** Fades its children in, rising by `rise` points, each time it mounts. */
function Appear({
  rise = 0,
  duration = 320,
  style,
  children,
}: {
  rise?: number;
  duration?: number;
  style?: StyleProp<ViewStyle>;
  children: React.ReactNode;
}) {
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(progress, {
      toValue: 1,
      duration,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [duration, progress]);
  return (
    <Animated.View
      style={[
        style,
        {
          opacity: progress,
          transform: [
            {
              translateY: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [rise, 0],
              }),
            },
          ],
        },
      ]}
    >
      {children}
    </Animated.View>
  );
}

/** Mission elapsed time, ticking once a second. */
function MissionClock() {
  const [elapsed, setElapsed] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setElapsed((value) => value + 1), 1000);
    return () => clearInterval(timer);
  }, []);
  // Sol 214, a little before seven in the morning.
  const total = 214 * 88775 + 24120 + elapsed;
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  return (
    <View style={styles.clock}>
      <Text style={styles.clockLabel}>MET</Text>
      <Text style={styles.clockValue}>
        {hours}:{pad(minutes)}:{pad(total % 60)}
      </Text>
    </View>
  );
}

function LiveBadge({ color }: { color: string }) {
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
    <View style={[styles.live, { borderColor: color }]}>
      <Animated.View
        style={[styles.liveDot, { backgroundColor: color, opacity: pulse }]}
      />
      <Text style={[styles.liveText, { color }]}>LIVE</Text>
    </View>
  );
}

function Tabs({
  page,
  onChange,
}: {
  page: Page;
  onChange: (page: Page) => void;
}) {
  const [width, setWidth] = useState(0);
  const index = PAGES.findIndex((item) => item.id === page);
  const offset = useRef(new Animated.Value(0)).current;
  const tabWidth = width / PAGES.length;

  useEffect(() => {
    Animated.spring(offset, {
      toValue: index * tabWidth,
      damping: 18,
      stiffness: 190,
      mass: 1,
      useNativeDriver: true,
    }).start();
  }, [index, tabWidth, offset]);

  const onLayout = (event: LayoutChangeEvent) =>
    setWidth(event.nativeEvent.layout.width - 8);

  return (
    <View style={styles.tabs} onLayout={onLayout}>
      {width > 0 ? (
        <Animated.View
          style={[
            styles.tabThumb,
            { width: tabWidth, transform: [{ translateX: offset }] },
          ]}
        />
      ) : null}
      {PAGES.map((item) => {
        const selected = item.id === page;
        return (
          <Pressable
            key={item.id}
            style={styles.tab}
            onPress={() => onChange(item.id)}
            testID={`mission-tab-${item.id}`}
          >
            <Image
              source={item.icon}
              style={[styles.tabIcon, selected && styles.tabIconSelected]}
            />
            <Text
              style={[styles.tabLabel, selected && styles.tabLabelSelected]}
            >
              {item.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Four corner brackets, the frame of a head-up display. */
function Brackets({ color }: { color: string }) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <View
        style={[styles.bracket, styles.bracketTL, { borderColor: color }]}
      />
      <View
        style={[styles.bracket, styles.bracketTR, { borderColor: color }]}
      />
      <View
        style={[styles.bracket, styles.bracketBL, { borderColor: color }]}
      />
      <View
        style={[styles.bracket, styles.bracketBR, { borderColor: color }]}
      />
    </View>
  );
}

function SignalBars({ color }: { color: string }) {
  return (
    <View style={styles.bars}>
      {[5, 8, 11, 14].map((height, i) => (
        <View
          key={height}
          style={[
            styles.bar,
            { height, backgroundColor: color },
            i === 3 && styles.barFaint,
          ]}
        />
      ))}
    </View>
  );
}

type MissionEvent = { id: number; verb: string; target: string };

const TICKER_VISIBLE_MS = 2200;

/** Confirms an action, then leaves on its own so the next one has room. */
function Ticker({
  event,
  color,
  bottom,
  onDone,
}: {
  event: MissionEvent;
  color: string;
  bottom: number;
  onDone: (id: number) => void;
}) {
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const show = Animated.sequence([
      Animated.timing(progress, {
        toValue: 1,
        duration: 240,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.delay(TICKER_VISIBLE_MS),
      Animated.timing(progress, {
        toValue: 0,
        duration: 220,
        easing: Easing.in(Easing.cubic),
        useNativeDriver: true,
      }),
    ]);
    show.start(({ finished }) => {
      if (finished) onDone(event.id);
    });
    return () => show.stop();
  }, [event.id, onDone, progress]);

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.ticker,
        {
          bottom,
          opacity: progress,
          transform: [
            {
              translateY: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [16, 0],
              }),
            },
          ],
        },
      ]}
    >
      <View style={[styles.tickerDot, { backgroundColor: color }]} />
      <Text style={[styles.tickerVerb, { color }]}>{event.verb}</Text>
      <Text style={styles.tickerTarget} numberOfLines={1}>
        {event.target}
      </Text>
    </Animated.View>
  );
}

export default function MissionControlScreen({ navigation }: Props) {
  const insets = useSafeAreaInsets();
  const [page, setPage] = useState<Page>('log');
  const [pills, setPills] = useState(true);
  const [weather, setWeather] = useState<Weather>('nominal');
  const [shown, setShown] = useState(0);
  const [event, setEvent] = useState<MissionEvent | null>(null);
  const eventId = useRef(0);

  // Native menus and their previews follow the system appearance; this screen
  // is always night.
  useEffect(() => {
    Appearance.setColorScheme('dark');
    return () => Appearance.setColorScheme(null);
  }, []);

  // The log arrives like a transmission, a few words at a time.
  useEffect(() => {
    const timer = setInterval(() => {
      setShown((value) => {
        if (value >= LOG_TOKENS.length) {
          clearInterval(timer);
          return value;
        }
        return value + 1;
      });
    }, 55);
    return () => clearInterval(timer);
  }, []);

  const report = useCallback((verb: string, url: string) => {
    eventId.current += 1;
    setEvent({ id: eventId.current, verb, target: nameOf(url) });
  }, []);
  // A newer event may already be showing; only the one that finished leaves.
  const dismissEvent = useCallback((id: number) => {
    setEvent((current) => (current?.id === id ? null : current));
  }, []);

  const storm = weather === 'storm';
  const accent = storm ? COLORS.amber : COLORS.cyan;

  // Keyed by URL pattern, like the pill variants: one entry per kind of link.
  const menus = useMemo<Record<string, LinkContextMenuItem[]>>(() => {
    const act = (verb: string) => (pressed: LinkPressEvent) =>
      report(verb, pressed.url);
    return {
      '^crew:': [
        {
          text: 'Hail on comms',
          icon: 'dot.radiowaves.left.and.right',
          onPress: act('HAILING'),
        },
        {
          text: 'Request vitals',
          icon: 'waveform.path.ecg',
          onPress: act('VITALS FROM'),
        },
        { text: 'Assign to EVA', icon: 'figure.walk', onPress: act('EVA FOR') },
        {
          text: 'Recall to base',
          icon: 'arrow.uturn.backward.circle',
          destructive: true,
          onPress: act('RECALLING'),
        },
      ],
      '^module:': [
        {
          text: 'Open hatch',
          icon: 'door.left.hand.open',
          onPress: act('HATCH OPEN ON'),
        },
        {
          text: 'Run diagnostics',
          icon: 'stethoscope',
          onPress: act('DIAGNOSING'),
        },
        {
          text: 'Depressurize',
          icon: 'wind',
          destructive: true,
          onPress: act('VENTING'),
        },
      ],
      '^sys:': [
        {
          text: 'Run diagnostics',
          icon: 'stethoscope',
          onPress: act('DIAGNOSING'),
        },
        { text: 'Reroute power', icon: 'bolt', onPress: act('REROUTING') },
        {
          text: 'Silence alarm',
          icon: 'bell.slash',
          disabled: !storm,
          onPress: act('SILENCED'),
        },
      ],
      '^https://ares\\.space/files/': [
        {
          text: 'Downlink to Earth',
          icon: 'arrow.down.circle',
          onPress: act('DOWNLINK'),
        },
        { text: 'Copy path', icon: 'doc.on.doc', onPress: act('COPIED') },
      ],
    };
  }, [report, storm]);

  const markdown =
    page === 'log' ? LOG_TOKENS.slice(0, shown).join('') : MARKDOWN[page];
  const streaming = page === 'log' && shown < LOG_TOKENS.length;

  return (
    <View style={styles.screen} testID="mission-screen">
      <StatusBar barStyle="light-content" />
      <SpaceBackdrop />

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
            testID="mission-back"
          >
            <Text style={styles.backGlyph}>{'‹'}</Text>
          </Pressable>
          <LiveBadge color={storm ? COLORS.red : COLORS.green} />
          <View style={styles.spacer} />
          <MissionClock />
        </View>

        <Appear rise={14} duration={500}>
          <Text style={[styles.kicker, { color: accent }]}>
            MISSION CONTROL
          </Text>
          <Text style={styles.title}>ARES VII</Text>
          <Text style={styles.subtitle}>
            Mars surface operations {'·'} Gale crater
          </Text>
        </Appear>

        <Tabs page={page} onChange={setPage} />

        <View style={[styles.console, { borderColor: `${accent}55` }]}>
          <Brackets color={accent} />
          <View style={styles.consoleHeader}>
            <View style={[styles.consoleDot, { backgroundColor: accent }]} />
            <Text style={[styles.consoleLabel, { color: accent }]}>
              {storm ? 'DUST STORM · DEGRADED' : 'DOWNLINK · SECURE'}
            </Text>
            <View style={styles.spacer} />
            <SignalBars color={accent} />
          </View>

          <Appear
            key={`${page}-${pills ? 'pills' : 'raw'}`}
            duration={260}
            style={styles.consoleBody}
          >
            <EnrichedMarkdownText
              flavor={page === 'systems' ? 'github' : 'commonmark'}
              markdown={markdown}
              markdownStyle={pills ? STYLE_PILLS : STYLE_RAW}
              linkPillContent={CONTENT[weather]}
              linkContextMenuItems={menus}
              streamingAnimation={streaming}
              onLinkPress={({ url }) => report('OPEN', url)}
              onLinkLongPress={({ url }) => report('HOLD', url)}
            />
          </Appear>
        </View>

        <View style={styles.controls}>
          {page === 'log' ? (
            <View style={styles.segment}>
              {[false, true].map((value) => {
                const selected = pills === value;
                return (
                  <Pressable
                    key={String(value)}
                    style={[
                      styles.segmentItem,
                      selected && styles.segmentItemSelected,
                    ]}
                    onPress={() => setPills(value)}
                    testID={value ? 'mission-pills' : 'mission-raw'}
                  >
                    <Text
                      style={[
                        styles.segmentLabel,
                        selected && styles.segmentLabelSelected,
                      ]}
                    >
                      {value ? 'PILLS' : 'RAW LINKS'}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          ) : null}

          {page === 'systems' ? (
            <Pressable
              style={[styles.alertButton, storm && styles.alertButtonActive]}
              onPress={() => setWeather(storm ? 'nominal' : 'storm')}
              testID="mission-storm"
            >
              <Image
                source={storm ? SHIELD_ICON : WARNING_ICON}
                style={[styles.alertIcon, storm && styles.alertIconActive]}
              />
              <Text
                style={[styles.alertLabel, storm && styles.alertLabelActive]}
              >
                {storm ? 'CLEAR THE STORM' : 'SIMULATE DUST STORM'}
              </Text>
            </Pressable>
          ) : null}

          {page === 'crew' ? (
            <Text style={styles.hint}>
              {Platform.OS === 'ios'
                ? 'HOLD A PILL · NATIVE MENU PER KIND OF LINK'
                : 'HOLD A PILL · MENUS ARE IOS 17+'}
            </Text>
          ) : null}
        </View>
      </ScrollView>

      {event ? (
        <Ticker
          key={event.id}
          event={event}
          color={accent}
          bottom={insets.bottom + 18}
          onDone={dismissEvent}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: COLORS.space },
  content: { paddingHorizontal: 18 },
  spacer: { flex: 1 },

  topRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  back: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(148, 163, 184, 0.12)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(148, 163, 184, 0.35)',
    marginRight: 12,
  },
  backGlyph: {
    color: COLORS.text,
    fontSize: 26,
    lineHeight: 28,
    marginTop: -2,
  },
  live: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  liveDot: { width: 6, height: 6, borderRadius: 3 },
  liveText: { fontFamily: FONT.semiBold, fontSize: 10.5, letterSpacing: 2 },
  clock: { alignItems: 'flex-end' },
  clockLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 9.5,
    letterSpacing: 2.5,
    color: COLORS.faint,
  },
  clockValue: { fontFamily: FONT.mono, fontSize: 13, color: COLORS.text },

  kicker: { fontFamily: FONT.semiBold, fontSize: 11, letterSpacing: 4.5 },
  title: {
    fontFamily: FONT.display,
    fontSize: 30,
    color: '#F8FAFC',
    marginTop: 5,
  },
  subtitle: {
    fontFamily: FONT.bodyItalic,
    fontSize: 15.5,
    color: COLORS.muted,
    marginTop: 6,
  },

  tabs: {
    flexDirection: 'row',
    marginTop: 14,
    padding: 4,
    borderRadius: 14,
    backgroundColor: 'rgba(15, 23, 42, 0.7)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(148, 163, 184, 0.3)',
  },
  tabThumb: {
    position: 'absolute',
    top: 4,
    bottom: 4,
    left: 4,
    borderRadius: 10,
    backgroundColor: COLORS.cyan,
    shadowColor: COLORS.cyan,
    shadowOpacity: 0.7,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 0 },
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 9,
  },
  tabIcon: { width: 15, height: 15, tintColor: COLORS.muted },
  tabIconSelected: { tintColor: '#04121A' },
  tabLabel: {
    fontFamily: FONT.bold,
    fontSize: 11.5,
    letterSpacing: 1.6,
    color: COLORS.muted,
  },
  tabLabelSelected: { color: '#04121A' },

  console: {
    marginTop: 12,
    borderRadius: 16,
    borderWidth: 1,
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
    borderBottomColor: 'rgba(148, 163, 184, 0.25)',
  },
  consoleDot: { width: 6, height: 6, borderRadius: 3 },
  consoleLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 10.5,
    letterSpacing: 2.2,
  },
  consoleBody: { minHeight: 296 },
  bars: { flexDirection: 'row', alignItems: 'flex-end', gap: 2.5 },
  bar: { width: 3, borderRadius: 1 },
  barFaint: { opacity: 0.35 },
  bracket: { position: 'absolute', width: 14, height: 14 },
  bracketTL: {
    top: -1,
    left: -1,
    borderTopWidth: 2,
    borderLeftWidth: 2,
    borderTopLeftRadius: 16,
  },
  bracketTR: {
    top: -1,
    right: -1,
    borderTopWidth: 2,
    borderRightWidth: 2,
    borderTopRightRadius: 16,
  },
  bracketBL: {
    bottom: -1,
    left: -1,
    borderBottomWidth: 2,
    borderLeftWidth: 2,
    borderBottomLeftRadius: 16,
  },
  bracketBR: {
    bottom: -1,
    right: -1,
    borderBottomWidth: 2,
    borderRightWidth: 2,
    borderBottomRightRadius: 16,
  },

  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    minHeight: 44,
    marginTop: 12,
  },
  segment: {
    flex: 1,
    flexDirection: 'row',
    padding: 3,
    borderRadius: 12,
    backgroundColor: 'rgba(15, 23, 42, 0.7)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(148, 163, 184, 0.3)',
  },
  segmentItem: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 9,
    borderRadius: 9,
  },
  segmentItemSelected: { backgroundColor: 'rgba(94, 234, 212, 0.18)' },
  segmentLabel: {
    fontFamily: FONT.semiBold,
    fontSize: 11.5,
    letterSpacing: 1.6,
    color: COLORS.faint,
  },
  segmentLabelSelected: { color: COLORS.cyan },
  alertButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(251, 191, 36, 0.6)',
    backgroundColor: 'rgba(251, 191, 36, 0.1)',
  },
  alertButtonActive: {
    backgroundColor: COLORS.amber,
    borderColor: COLORS.amber,
    shadowColor: COLORS.amber,
    shadowOpacity: 0.7,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 0 },
  },
  alertIcon: { width: 16, height: 16, tintColor: COLORS.amber },
  alertIconActive: { tintColor: '#04121A' },
  alertLabel: {
    fontFamily: FONT.bold,
    fontSize: 12,
    letterSpacing: 1.8,
    color: COLORS.amber,
  },
  alertLabelActive: { color: '#04121A' },
  hint: {
    flex: 1,
    textAlign: 'center',
    fontFamily: FONT.semiBold,
    fontSize: 11,
    letterSpacing: 2,
    color: COLORS.muted,
  },

  ticker: {
    position: 'absolute',
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    maxWidth: '88%',
    paddingHorizontal: 16,
    paddingVertical: 11,
    borderRadius: 999,
    backgroundColor: 'rgba(2, 6, 23, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(148, 163, 184, 0.35)',
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  tickerDot: { width: 6, height: 6, borderRadius: 3 },
  tickerVerb: { fontFamily: FONT.bold, fontSize: 11.5, letterSpacing: 1.8 },
  tickerTarget: {
    flexShrink: 1,
    fontFamily: FONT.mono,
    fontSize: 12,
    color: COLORS.text,
  },
});
