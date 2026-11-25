import { memo, useCallback, useEffect, useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  FadeInDown,
  FadeOutDown,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, {
  Circle,
  Defs,
  LinearGradient,
  Rect,
  Stop,
} from 'react-native-svg';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useHinge } from '../shared/hinge';
import { useDemoStream } from '../shared/useDemoStream';
import { DuoJournal } from './duo/DuoJournal';
import { JOURNAL_MARKDOWN, PROMPT } from './journalMarkdown';
import { LOOPS, loopPlayer, usePlaying } from './loops';
import { journalRenderers } from './renderers';
import {
  AMBER,
  EL,
  FONTS,
  PANEL,
  PANEL_EDGE,
  PAPER,
  PAPER_SOFT,
  SPACE,
  STAR,
  journalMarkdownStyle,
  journalSelection,
} from './theme';

export default function FlightJournalScreen() {
  const hinge = useHinge();
  // Leaving the journal lifts the headset, whatever was playing.
  useEffect(() => {
    loopPlayer.prefetch();
    return () => loopPlayer.stop();
  }, []);
  if (!hinge.known) return <View style={styles.root} />;
  return hinge.available ? <DuoJournal hinge={hinge} /> : <FlightJournal />;
}

// The latest Ground Elapsed Time the answer has reached, `102:45:40`.
export function missionTime(markdown: string) {
  const times = markdown.match(/\b1\d\d:\d\d(?::\d\d)?\b/g);
  const last = times?.[times.length - 1];
  if (!last) return null;
  return last.length === 6 ? `${last}:00` : last;
}

// Streams the journal and cues the landing call as its card lands. A replay
// writes it again and cues it again.
export function useJournal(startDelay?: number) {
  const stream = useDemoStream(JOURNAL_MARKDOWN, startDelay);
  const { replay: replayStream } = stream;
  useEffect(() => {
    loopPlayer.autoCue = stream.streaming;
  }, [stream.streaming, stream.run]);
  const replay = useCallback(() => {
    loopPlayer.stop();
    loopPlayer.cued.clear();
    replayStream();
  }, [replayStream]);
  return { ...stream, replay };
}

export function FlightJournal() {
  const insets = useSafeAreaInsets();
  const stream = useJournal();
  const contentStyle = useMemo(
    () => [styles.content, { paddingBottom: insets.bottom + 140 }],
    [insets.bottom]
  );
  return (
    <View style={styles.root}>
      <Starfield />
      <Header
        top={insets.top}
        writing={stream.writing}
        time={missionTime(stream.markdown)}
        onReplay={stream.replay}
      />
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={contentStyle}
      >
        <Prompt />
        <Journal stream={stream} />
      </Animated.ScrollView>
      <Dock
        bottom={insets.bottom + 16}
        writingBelow={stream.streaming && stream.detached}
        onFollow={stream.follow}
      />
    </View>
  );
}

export function Journal({ stream }: { stream: ReturnType<typeof useJournal> }) {
  return (
    <>
      <EnrichedMarkdownText
        key={stream.run}
        flavor="github"
        markdown={stream.markdown}
        markdownStyle={journalMarkdownStyle}
        {...journalSelection}
        renderers={journalRenderers}
        streamingAnimation={stream.streaming}
      />
      {!stream.streaming && <EndMark />}
    </>
  );
}

export const Header = memo(function Header({
  top,
  writing,
  time,
  onReplay,
}: {
  top: number;
  writing: boolean;
  time: string | null;
  onReplay: () => void;
}) {
  return (
    <View style={[styles.header, { paddingTop: top + 8 }]}>
      <View style={styles.headerTitles}>
        <Text style={styles.headerTitle}>FLIGHT JOURNAL</Text>
        <Text style={styles.headerSub}>
          {writing ? 'APOLLO 11 · WRITING…' : 'APOLLO 11 · THE LANDING'}
        </Text>
      </View>
      <View style={styles.clock}>
        <Text style={styles.clockLabel}>GET</Text>
        <Text style={styles.clockTime}>{time ?? '---:--:--'}</Text>
      </View>
      <Pressable
        onPress={onReplay}
        hitSlop={12}
        accessibilityRole="button"
        accessibilityLabel="Replay the answer"
        testID="flight-journal-replay"
      >
        <Text style={styles.replay}>↻</Text>
      </Pressable>
    </View>
  );
});

export const Prompt = memo(function Prompt() {
  return (
    <View style={styles.prompt}>
      <Text style={styles.promptLabel}>YOU</Text>
      <Text style={styles.promptText}>{PROMPT}</Text>
    </View>
  );
});

const Dock = memo(function Dock({
  bottom,
  writingBelow,
  onFollow,
}: {
  bottom: number;
  writingBelow: boolean;
  onFollow: () => void;
}) {
  return (
    <View style={[styles.dock, { bottom }]} pointerEvents="box-none">
      {writingBelow && <FollowPill onFollow={onFollow} />}
      <OnTheLoop />
    </View>
  );
});

export function FollowPill({ onFollow }: { onFollow: () => void }) {
  return (
    <Animated.View
      entering={FadeInDown.duration(220)}
      exiting={FadeOutDown.duration(180)}
    >
      <Pressable
        onPress={onFollow}
        hitSlop={8}
        accessibilityRole="button"
        accessibilityLabel="Follow the answer"
        style={styles.pill}
      >
        <Text style={styles.pillText}>↓ still writing</Text>
      </Pressable>
    </Animated.View>
  );
}

// What is on the speaker, wherever its card has scrolled to.
export function OnTheLoop() {
  const playing = usePlaying();
  const loop = LOOPS.find(({ url }) => url === playing?.url);
  if (!loop) return null;
  return (
    <Animated.View
      entering={FadeInDown.duration(260)}
      exiting={FadeOutDown.duration(200)}
      style={styles.onLoop}
    >
      <Beacon />
      <View style={styles.onLoopTitles}>
        <Text style={styles.onLoopKicker}>{`ON THE LOOP · ${loop.loop}`}</Text>
        <Text style={styles.onLoopTitle} numberOfLines={1}>
          {loop.lines[0]?.words.map(([, word]) => word).join(' ')}
        </Text>
      </View>
      <Pressable
        onPress={() => loopPlayer.stop()}
        hitSlop={10}
        accessibilityRole="button"
        accessibilityLabel="Stop the transmission"
        style={styles.onLoopStop}
      >
        <View style={styles.onLoopStopGlyph} />
      </Pressable>
    </Animated.View>
  );
}

function Beacon() {
  const ping = useSharedValue(0);
  useEffect(() => {
    ping.value = withRepeat(withTiming(1, { duration: 1400 }), -1);
  }, [ping]);
  const ring = useAnimatedStyle(() => ({
    opacity: 1 - ping.value,
    transform: [{ scale: 0.6 + ping.value * 1.4 }],
  }));
  return (
    <View style={styles.beacon}>
      <Animated.View style={[styles.beaconRing, ring]} />
      <View style={styles.beaconDot} />
    </View>
  );
}

// The sign-off under a finished answer.
export function EndMark() {
  const show = useSharedValue(0);
  useEffect(() => {
    show.value = withDelay(200, withTiming(1, { duration: 700 }));
  }, [show]);
  const style = useAnimatedStyle(() => ({
    opacity: show.value,
    transform: [{ translateY: interpolate(show.value, [0, 1], [10, 0]) }],
  }));
  return (
    <Animated.View style={[styles.end, style]}>
      <View style={styles.endLine} />
      <Text style={styles.endText}>TRANQUILITY BASE</Text>
      <Text style={styles.endSub}>
        0.674° N · 23.473° E · SEA OF TRANQUILITY
      </Text>
    </Animated.View>
  );
}

// A fixed sky: the same stars every time, a few of them twinkling.
const STARS = (() => {
  let seed = 11;
  const random = () => {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  };
  return Array.from({ length: 90 }, (_, i) => ({
    x: random() * 100,
    y: random() * 100,
    r: random() < 0.85 ? 0.6 + random() * 0.5 : 1.2 + random() * 0.6,
    o: 0.25 + random() * 0.6,
    twinkle: i % 15 === 0,
  }));
})();

export const Starfield = memo(function Starfield({
  veiled = true,
}: {
  veiled?: boolean;
}) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Svg style={StyleSheet.absoluteFill}>
        {STARS.filter((s) => !s.twinkle).map((s, i) => (
          <Circle
            key={i}
            cx={`${s.x}%`}
            cy={`${s.y}%`}
            r={s.r}
            fill={STAR}
            fillOpacity={s.o}
          />
        ))}
      </Svg>
      {STARS.filter((s) => s.twinkle).map((s, i) => (
        <Twinkle key={i} x={s.x} y={s.y} index={i} />
      ))}
      {veiled && <Veil />}
    </View>
  );
});

// Dims the sky under the text column, so the stars stay at the edges and the
// copy stays crisp.
const Veil = memo(function Veil() {
  return (
    <Svg style={StyleSheet.absoluteFill}>
      <Defs>
        <LinearGradient id="veil" x1="0" y1="0" x2="1" y2="0">
          <Stop offset="0" stopColor={SPACE} stopOpacity={0.15} />
          <Stop offset="0.5" stopColor={SPACE} stopOpacity={0.7} />
          <Stop offset="1" stopColor={SPACE} stopOpacity={0.15} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#veil)" />
    </Svg>
  );
});

function Twinkle({ x, y, index }: { x: number; y: number; index: number }) {
  const glow = useSharedValue(0.2);
  useEffect(() => {
    glow.value = withDelay(
      index * 700,
      withRepeat(
        withSequence(
          withTiming(1, { duration: 900 }),
          withTiming(0.2, { duration: 1300 })
        ),
        -1
      )
    );
  }, [glow, index]);
  const style = useAnimatedStyle(() => ({ opacity: glow.value }));
  return (
    <Animated.View
      style={[styles.twinkle, { left: `${x}%`, top: `${y}%` }, style]}
    />
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: SPACE,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: 20,
    paddingBottom: 12,
    backgroundColor: 'rgba(7, 9, 13, 0.9)',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: PANEL_EDGE,
    zIndex: 1,
  },
  headerTitles: {
    flex: 1,
  },
  headerTitle: {
    fontFamily: FONTS.display,
    fontSize: 26,
    lineHeight: 28,
    letterSpacing: 2,
    color: STAR,
  },
  headerSub: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    letterSpacing: 1.2,
    color: PAPER_SOFT,
  },
  clock: {
    alignItems: 'flex-end',
  },
  clockLabel: {
    fontFamily: FONTS.label,
    fontSize: 8,
    letterSpacing: 1.4,
    color: PAPER_SOFT,
  },
  clockTime: {
    fontFamily: FONTS.monoMedium,
    fontSize: 15,
    color: EL,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: STAR,
  },
  content: {
    paddingHorizontal: 22,
    paddingTop: 20,
  },
  prompt: {
    alignSelf: 'flex-end',
    maxWidth: '84%',
    backgroundColor: PANEL,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: PANEL_EDGE,
    borderRadius: 18,
    borderBottomRightRadius: 4,
    paddingHorizontal: 16,
    paddingVertical: 12,
    marginBottom: 26,
  },
  promptLabel: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    letterSpacing: 1.2,
    color: PAPER_SOFT,
    marginBottom: 4,
  },
  promptText: {
    fontFamily: FONTS.body,
    fontSize: 17,
    lineHeight: 23,
    color: PAPER,
  },
  dock: {
    position: 'absolute',
    left: 16,
    right: 16,
    alignItems: 'center',
    gap: 10,
  },
  pill: {
    backgroundColor: STAR,
    borderRadius: 20,
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  pillText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    letterSpacing: 1,
    color: SPACE,
  },
  onLoop: {
    alignSelf: 'stretch',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: '#161B23',
    borderRadius: 26,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#2E3744',
    paddingVertical: 10,
    paddingLeft: 16,
    paddingRight: 12,
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
    elevation: 8,
  },
  onLoopTitles: {
    flex: 1,
  },
  onLoopKicker: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.4,
    color: AMBER,
  },
  onLoopTitle: {
    fontFamily: FONTS.bodyBold,
    fontSize: 16,
    color: STAR,
  },
  onLoopStop: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: STAR,
    alignItems: 'center',
    justifyContent: 'center',
  },
  onLoopStopGlyph: {
    width: 11,
    height: 11,
    borderRadius: 2,
    backgroundColor: SPACE,
  },
  beacon: {
    width: 14,
    height: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  beaconRing: {
    position: 'absolute',
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 1.5,
    borderColor: AMBER,
  },
  beaconDot: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
    backgroundColor: AMBER,
  },
  end: {
    alignItems: 'center',
    marginTop: 18,
  },
  endLine: {
    width: 64,
    height: 2,
    borderRadius: 1,
    backgroundColor: AMBER,
    marginBottom: 14,
  },
  endText: {
    fontFamily: FONTS.display,
    fontSize: 30,
    letterSpacing: 4,
    color: STAR,
  },
  endSub: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    letterSpacing: 1.6,
    color: PAPER_SOFT,
    marginTop: 4,
  },
  twinkle: {
    position: 'absolute',
    width: 3,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: STAR,
  },
});
