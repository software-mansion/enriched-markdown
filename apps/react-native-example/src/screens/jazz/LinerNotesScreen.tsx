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
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, {
  Circle,
  Defs,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useDemoStream } from '../shared/useDemoStream';
import type { TrackId } from './audio/harmony';
import { DuoLinerNotes } from './duo/DuoLinerNotes';
import { useHinge } from '../shared/hinge';
import { LINER_NOTES_MARKDOWN, PROMPT } from './linerNotesMarkdown';
import { PlayerProvider, usePlayer, usePlayerState } from './player';
import { linerNotesRenderers } from './renderers';
import {
  BLUE,
  BRASS,
  CREAM,
  CREAM_SOFT,
  FONTS,
  NIGHT,
  ORANGE,
  RED,
  SMOKE,
  SMOKE_EDGE,
  linerMarkdownStyle,
  linerSelection,
} from './theme';

export const NOW_PLAYING: Record<TrackId, { title: string; color: string }> = {
  blueTrain: { title: 'Blue Train', color: BLUE },
  giantSteps: { title: 'Giant Steps', color: RED },
  loveSupreme: { title: 'A Love Supreme', color: ORANGE },
};

export default function LinerNotesScreen() {
  const hinge = useHinge();
  return (
    <PlayerProvider>
      {!hinge.known ? (
        <View style={styles.root} />
      ) : hinge.available ? (
        <DuoLinerNotes hinge={hinge} />
      ) : (
        <LinerNotes />
      )}
    </PlayerProvider>
  );
}

export function LinerNotes() {
  const insets = useSafeAreaInsets();
  const player = usePlayer();
  const stream = useDemoStream(LINER_NOTES_MARKDOWN);
  const { setAutoCue, stop } = player;
  const { replay: replayStream } = stream;
  // A replay cues its first record again.
  useEffect(
    () => setAutoCue(stream.streaming),
    [setAutoCue, stream.streaming, stream.run]
  );
  const replay = useCallback(() => {
    stop();
    replayStream();
  }, [stop, replayStream]);
  const contentStyle = useMemo(
    () => [styles.content, { paddingBottom: insets.bottom + 140 }],
    [insets.bottom]
  );

  // Only the markdown changes on a stream tick; the header and the dock are
  // memoised and read the player state they show themselves.
  return (
    <View style={styles.root}>
      <Spotlight />
      <Header top={insets.top} writing={stream.writing} onReplay={replay} />
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={contentStyle}
      >
        <Prompt />
        <EnrichedMarkdownText
          key={stream.run}
          flavor="github"
          markdown={stream.markdown}
          markdownStyle={linerMarkdownStyle}
          {...linerSelection}
          renderers={linerNotesRenderers}
          streamingAnimation={stream.streaming}
        />
        {!stream.streaming && <RunOut />}
      </Animated.ScrollView>
      <Dock
        bottom={insets.bottom + 16}
        writingBelow={stream.streaming && stream.detached}
        onFollow={stream.follow}
      />
    </View>
  );
}

export const Header = memo(function Header({
  top,
  writing,
  onReplay,
}: {
  top: number;
  writing: boolean;
  onReplay: () => void;
}) {
  return (
    <View style={[styles.header, { paddingTop: top + 8 }]}>
      <HeaderDisc />
      <View style={styles.headerTitles}>
        <Text style={styles.headerTitle}>LINER NOTES</Text>
        <Text style={styles.headerSub}>
          {writing ? 'writing…' : 'a life in records'}
        </Text>
      </View>
      <Pressable
        onPress={onReplay}
        hitSlop={12}
        accessibilityRole="button"
        accessibilityLabel="Replay the answer"
        testID="liner-notes-replay"
      >
        <Text style={styles.replay}>↻</Text>
      </Pressable>
    </View>
  );
});

function HeaderDisc() {
  const spinning = usePlayerState((s) => s.track !== null);
  return <MiniDisc color={ORANGE} spinning={spinning} size={38} />;
}

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
  const track = usePlayerState((s) => s.track);
  return (
    <View style={[styles.dock, { bottom }]} pointerEvents="box-none">
      {writingBelow && <FollowPill onFollow={onFollow} />}
      {track && <NowPlaying track={track} />}
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

function NowPlaying({ track }: { track: TrackId }) {
  const player = usePlayer();
  const { title, color } = NOW_PLAYING[track];
  return (
    <Animated.View
      entering={FadeInDown.duration(260)}
      exiting={FadeOutDown.duration(200)}
      style={styles.nowPlaying}
    >
      <MiniDisc color={color} spinning size={34} />
      <View style={styles.nowTitles}>
        <Text style={styles.nowKicker}>NOW PLAYING · PREVIEW</Text>
        <Text style={styles.nowTitle} numberOfLines={1}>
          {`${title} · John Coltrane`}
        </Text>
      </View>
      <Bars />
      <Pressable
        onPress={player.stop}
        hitSlop={10}
        accessibilityRole="button"
        accessibilityLabel="Stop the record"
        style={styles.nowStop}
      >
        <View style={styles.nowStopGlyph} />
      </Pressable>
    </Animated.View>
  );
}

const BAR_GAINS = [0.7, 1, 0.55, 0.85];

// Level bars driven by the master output, each with its own gain and wobble.
export function Bars() {
  const { level } = usePlayer();
  return (
    <View style={styles.bars}>
      {BAR_GAINS.map((gain, i) => (
        <Bar key={i} gain={gain} phase={i} level={level} />
      ))}
    </View>
  );
}

function Bar({
  gain,
  phase,
  level,
}: {
  gain: number;
  phase: number;
  level: ReturnType<typeof usePlayer>['level'];
}) {
  const style = useAnimatedStyle(() => {
    const wobble = 0.75 + 0.25 * Math.sin(Date.now() / (90 + phase * 37));
    return {
      transform: [
        { scaleY: (4 + Math.min(1, level.value * gain * wobble) * 18) / 22 },
      ],
    };
  });
  return <Animated.View style={[styles.bar, style]} />;
}

export const MiniDisc = memo(function MiniDisc({
  color,
  spinning,
  size,
}: {
  color: string;
  spinning: boolean;
  size: number;
}) {
  const spin = useSharedValue(0);
  useEffect(() => {
    spin.value = spinning
      ? withRepeat(
          withTiming(spin.value + 360, {
            duration: 1800,
            easing: Easing.linear,
          }),
          -1
        )
      : withTiming(spin.value + 40, {
          duration: 700,
          easing: Easing.out(Easing.quad),
        });
  }, [spin, spinning]);
  const style = useAnimatedStyle(() => ({
    transform: [{ rotate: `${spin.value}deg` }],
  }));
  return (
    <Animated.View style={[{ width: size, height: size }, style]}>
      <Svg width="100%" height="100%" viewBox="0 0 40 40">
        <Circle cx={20} cy={20} r={20} fill="#0B0A09" />
        {[17, 14.5, 12].map((r) => (
          <Circle
            key={r}
            cx={20}
            cy={20}
            r={r}
            fill="none"
            stroke="#2A2622"
            strokeWidth={0.6}
          />
        ))}
        <Circle cx={20} cy={20} r={7.5} fill={color} />
        <Circle cx={20} cy={14.5} r={1.4} fill={CREAM} fillOpacity={0.8} />
        <Circle cx={20} cy={20} r={1.4} fill={NIGHT} />
      </Svg>
    </Animated.View>
  );
});

// The run-out groove at the end of the side, with the matrix scratched in.
export function RunOut() {
  const show = useSharedValue(0);
  useEffect(() => {
    show.value = withDelay(200, withTiming(1, { duration: 700 }));
  }, [show]);
  const style = useAnimatedStyle(() => ({
    opacity: show.value,
    transform: [{ translateY: interpolate(show.value, [0, 1], [10, 0]) }],
  }));
  return (
    <Animated.View style={[styles.runOut, style]}>
      <View style={styles.runOutLine} />
      <Text style={styles.runOutText}>END OF SIDE A</Text>
      <Text style={styles.runOutHand}>turn it over</Text>
      <Text style={styles.matrix}>JC · 1926–1967 · RVG</Text>
    </Animated.View>
  );
}

export const Spotlight = memo(function Spotlight() {
  return (
    <Svg style={StyleSheet.absoluteFill} pointerEvents="none">
      <Defs>
        <RadialGradient id="spot" cx="50%" cy="0%" r="85%">
          <Stop offset="0" stopColor={BRASS} stopOpacity={0.16} />
          <Stop offset="0.55" stopColor={BRASS} stopOpacity={0.03} />
          <Stop offset="1" stopColor={BRASS} stopOpacity={0} />
        </RadialGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#spot)" />
    </Svg>
  );
});

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: NIGHT,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 20,
    paddingBottom: 12,
    backgroundColor: 'rgba(16, 14, 11, 0.92)',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: SMOKE_EDGE,
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
    color: CREAM,
  },
  headerSub: {
    fontFamily: FONTS.hand,
    fontSize: 18,
    lineHeight: 20,
    color: BRASS,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: BRASS,
  },
  content: {
    paddingHorizontal: 22,
    paddingTop: 20,
  },
  prompt: {
    alignSelf: 'flex-end',
    maxWidth: '82%',
    backgroundColor: SMOKE,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: SMOKE_EDGE,
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
    color: CREAM_SOFT,
    marginBottom: 4,
  },
  promptText: {
    fontFamily: FONTS.body,
    fontSize: 17,
    lineHeight: 23,
    color: CREAM,
  },
  dock: {
    position: 'absolute',
    left: 16,
    right: 16,
    alignItems: 'center',
    gap: 10,
  },
  pill: {
    backgroundColor: CREAM,
    borderRadius: 20,
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  pillText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    letterSpacing: 1,
    color: NIGHT,
  },
  nowPlaying: {
    alignSelf: 'stretch',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: '#1E1B17',
    borderRadius: 26,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#3D372F',
    paddingVertical: 9,
    paddingLeft: 10,
    paddingRight: 14,
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
    elevation: 8,
  },
  nowTitles: {
    flex: 1,
  },
  nowKicker: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.4,
    color: BRASS,
  },
  nowTitle: {
    fontFamily: FONTS.bodyBold,
    fontSize: 16,
    color: CREAM,
  },
  bars: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 3,
    height: 22,
  },
  bar: {
    width: 3,
    height: 22,
    borderRadius: 2,
    backgroundColor: BRASS,
    transformOrigin: 'bottom',
  },
  nowStop: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: CREAM,
    alignItems: 'center',
    justifyContent: 'center',
  },
  nowStopGlyph: {
    width: 11,
    height: 11,
    borderRadius: 2,
    backgroundColor: NIGHT,
  },
  runOut: {
    alignItems: 'center',
    marginTop: 18,
  },
  runOutLine: {
    width: 64,
    height: 2,
    borderRadius: 1,
    backgroundColor: BRASS,
    marginBottom: 14,
  },
  runOutText: {
    fontFamily: FONTS.display,
    fontSize: 28,
    letterSpacing: 4,
    color: CREAM,
  },
  runOutHand: {
    fontFamily: FONTS.hand,
    fontSize: 24,
    color: BRASS,
    marginTop: -2,
    transform: [{ rotate: '-3deg' }],
  },
  matrix: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    letterSpacing: 2,
    color: '#6E6352',
    marginTop: 10,
  },
});
