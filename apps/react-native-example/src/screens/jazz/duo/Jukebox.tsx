import { memo, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  FadeIn,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
  ZoomIn,
} from 'react-native-reanimated';
import Svg, { Rect } from 'react-native-svg';
import { jazzEngine } from '../audio/engine';
import type { TrackId } from '../audio/harmony';
import type { Hinge } from '../../shared/hinge';
import { Bars, NOW_PLAYING } from '../LinerNotesScreen';
import { usePlayer, usePlayerState } from '../player';
import { SETTLE, formatTime } from '../renderers/motion';
import {
  BLUE,
  BRASS,
  CREAM,
  CREAM_SOFT,
  FONTS,
  NEON,
  NIGHT,
  ORANGE,
  RED,
  SMOKE,
  SMOKE_EDGE,
} from '../theme';

interface Selection {
  track: TrackId;
  code: string;
  title: string;
  credit: string;
  color: string;
  // Where the notes reach this record.
  marker: string;
}

// In the order the notes write them.
export const SELECTIONS: Selection[] = [
  {
    code: 'A1',
    title: 'Blue Train',
    credit: '1957 · BLUE NOTE 1577',
    color: BLUE,
    marker: 'coltrane.app/blue-train',
    track: 'blueTrain',
  },
  {
    code: 'A2',
    title: 'Giant Steps',
    credit: '1959 · ATLANTIC 1311',
    color: RED,
    marker: 'coltrane.app/giant-steps',
    track: 'giantSteps',
  },
  {
    code: 'B1',
    title: 'A Love Supreme',
    credit: '1964 · IMPULSE! A-77',
    color: ORANGE,
    marker: 'coltrane.app/a-love-supreme',
    track: 'loveSupreme',
  },
];

// The right page: title strips like a jukebox's, inked in as the notes reach
// each record, over the one playing now.
export const Jukebox = memo(function Jukebox({
  top,
  bottom,
  written,
  open,
  onSelect,
  onReplay,
  source,
  onToggleSource,
}: {
  top: number;
  bottom: number;
  written: number;
  open: Hinge['open'];
  onSelect: (track: TrackId) => void;
  onReplay: () => void;
  // The source page, shown in place of the strips while it is open.
  source: ReactNode | null;
  onToggleSource: () => void;
}) {
  // The strips slide in from the fold as the hinge opens.
  const stripsStyle = useAnimatedStyle(() => ({
    opacity: interpolate(open.value, [0, 0.6], [0, 1], 'clamp'),
    transform: [{ translateX: interpolate(open.value, [0, 1], [48, 0]) }],
  }));

  return (
    <View style={[styles.root, { paddingTop: top + 14 }]}>
      <View style={styles.heading}>
        <View style={styles.headingTitles}>
          <NeonTitle key={source ? 'source' : 'selections'}>
            {source ? 'Markdown' : 'Selections'}
          </NeonTitle>
          <Text style={styles.hint}>
            {source
              ? 'what was written, before it renders'
              : 'pick a record, the notes follow'}
          </Text>
        </View>
        <Pressable
          onPress={onToggleSource}
          hitSlop={10}
          accessibilityRole="button"
          accessibilityLabel={source ? 'Show the records' : 'Show the markdown'}
          testID="liner-notes-source"
          style={styles.toggle}
        >
          <Text style={styles.toggleText}>
            {source ? '♪ RECORDS' : '</> SOURCE'}
          </Text>
        </Pressable>
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
      {source ?? (
        <>
          <Animated.View style={[styles.strips, stripsStyle]}>
            {SELECTIONS.map((selection, i) => (
              <Strip
                key={selection.track}
                selection={selection}
                written={i < written}
                onSelect={onSelect}
              />
            ))}
          </Animated.View>
          <NowPlaying bottom={bottom} />
        </>
      )}
    </View>
  );
});

function Strip({
  selection,
  written,
  onSelect,
}: {
  selection: Selection;
  written: boolean;
  onSelect: (track: TrackId) => void;
}) {
  const { track, code, title, credit, color } = selection;
  const playing = usePlayerState((s) => s.track === track);
  const loading = usePlayerState((s) => s.loading === track);

  if (!written) {
    return (
      <View style={[styles.strip, styles.blank]}>
        <Text style={[styles.code, styles.blankText]}>{code}</Text>
        <View style={styles.blankRule} />
      </View>
    );
  }

  return (
    <Animated.View entering={FadeIn.duration(450)}>
      <Pressable
        onPress={() => onSelect(track)}
        accessibilityRole="button"
        accessibilityLabel={`Play ${title}`}
        accessibilityState={{ selected: playing }}
        testID={`liner-notes-strip-${track}`}
        style={[styles.strip, playing && { borderColor: color }]}
      >
        <View
          style={[styles.band, styles.bandTop, { backgroundColor: color }]}
        />
        <View
          style={[styles.band, styles.bandBottom, { backgroundColor: color }]}
        />
        <Text style={[styles.code, { color }]}>{code}</Text>
        <View style={styles.stripTitles}>
          <Text style={styles.stripTitle} numberOfLines={1}>
            {title}
          </Text>
          <Text style={styles.credit} numberOfLines={1}>
            {credit}
          </Text>
        </View>
        {playing ? (
          <Animated.View entering={ZoomIn.duration(250)}>
            <Bars />
          </Animated.View>
        ) : (
          <View style={[styles.go, { borderColor: color }]}>
            <Text style={[styles.goGlyph, { color }]}>
              {loading ? '…' : '▶'}
            </Text>
          </View>
        )}
      </Pressable>
    </Animated.View>
  );
}

const BARS = 64;
const FLAT = Array<number>(BARS).fill(0.06);
const WAVE_HEIGHT = 84;

// The foot of the page: the record on now, and its preview drawn as a
// waveform the playhead crosses.
function NowPlaying({ bottom }: { bottom: number }) {
  const track = usePlayerState((s) => s.track);
  return (
    <View style={[styles.stage, { paddingBottom: bottom + 18 }]}>
      {track ? (
        <Animated.View
          key={track}
          entering={FadeIn.duration(300)}
          style={styles.nowStack}
        >
          <NowCard track={track} />
          <Waveform track={track} />
        </Animated.View>
      ) : (
        <View style={styles.nowStack}>
          <Text style={styles.idle}>the platter's waiting</Text>
          <IdleGroove />
        </View>
      )}
    </View>
  );
}

// A flat groove with a dim playhead drifting across it, until a record goes on.
function IdleGroove() {
  const [width, setWidth] = useState(0);
  const drift = useSharedValue(0);
  useEffect(() => {
    drift.value = withRepeat(
      withTiming(1, { duration: 3200, easing: Easing.inOut(Easing.sin) }),
      -1,
      true
    );
  }, [drift]);
  const headStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: drift.value * width }],
  }));
  return (
    <View
      style={styles.wave}
      onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
    >
      {width > 0 && (
        <>
          <Bands heights={FLAT} width={width} fill="#2A2520" />
          <Animated.View style={[styles.head, styles.idleHead, headStyle]}>
            <View style={[styles.headLine, styles.idleLine]} />
            <View style={[styles.headDot, styles.idleDot]} />
          </Animated.View>
        </>
      )}
    </View>
  );
}

// A neon tube warming up: a few stutters, then a slow glow.
function NeonTitle({ children }: { children: string }) {
  const glow = useSharedValue(0);
  useEffect(() => {
    glow.value = withSequence(
      withTiming(1, { duration: 90 }),
      withTiming(0.25, { duration: 70 }),
      withTiming(1, { duration: 60 }),
      withTiming(0.5, { duration: 110 }),
      withTiming(1, { duration: 140 }),
      withRepeat(
        withSequence(
          withTiming(0.82, { duration: 1600 }),
          withTiming(1, { duration: 1600 })
        ),
        -1
      )
    );
  }, [glow]);
  const style = useAnimatedStyle(() => ({ opacity: glow.value }));
  return <Animated.Text style={[styles.neon, style]}>{children}</Animated.Text>;
}

function NowCard({ track }: { track: TrackId }) {
  const player = usePlayer();
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setElapsed(player.elapsed.value), 500);
    return () => clearInterval(timer);
  }, [player]);

  return (
    <View style={styles.nowCard}>
      <Text style={styles.nowKicker}>ON THE PLATTER · PREVIEW</Text>
      <Text style={styles.nowTitle}>{NOW_PLAYING[track].title}</Text>
      <View style={styles.nowRow}>
        <Text style={styles.nowTime}>{formatTime(elapsed)}</Text>
        <Pressable
          onPress={player.stop}
          hitSlop={10}
          accessibilityRole="button"
          accessibilityLabel="Lift the needle"
          style={styles.lift}
        >
          <Text style={styles.liftText}>LIFT</Text>
        </Pressable>
      </View>
    </View>
  );
}

// The loudest moment of each slice of the preview, stretched between the
// quietest and loudest slices so the dynamics read at a glance.
function peaksOf(envelope: number[]) {
  const size = envelope.length / BARS;
  const peaks = Array.from({ length: BARS }, (_, i) =>
    Math.max(
      0,
      ...envelope.slice(Math.floor(i * size), Math.floor((i + 1) * size))
    )
  );
  const quietest = Math.min(...peaks);
  const range = Math.max(...peaks) - quietest || 1;
  return peaks.map((peak) => 0.12 + 0.88 * ((peak - quietest) / range) ** 1.4);
}

function Waveform({ track }: { track: TrackId }) {
  const player = usePlayer();
  const { color } = NOW_PLAYING[track];
  const [width, setWidth] = useState(0);
  const [timeline] = useState(() => jazzEngine.timeline);
  const peaks = useMemo(() => peaksOf(timeline?.envelope ?? []), [timeline]);
  const grow = useSharedValue(0);

  useEffect(() => {
    grow.value = withTiming(1, { duration: 700, easing: SETTLE });
  }, [grow]);

  const bandStyle = useAnimatedStyle(() => ({
    transform: [{ scaleY: grow.value }],
  }));
  const playedStyle = useAnimatedStyle(() => ({
    width: player.progress.value * width,
  }));
  const headStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: player.progress.value * width }],
  }));
  const dotStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 1 + Math.min(1, player.level.value) * 0.9 }],
  }));

  return (
    <View>
      <View
        style={styles.wave}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 && (
          <>
            <Animated.View style={[StyleSheet.absoluteFill, bandStyle]}>
              <Bands heights={peaks} width={width} fill="#3A342C" />
              <Animated.View style={[styles.played, playedStyle]}>
                <Bands heights={peaks} width={width} fill={color} />
              </Animated.View>
            </Animated.View>
            <Animated.View style={[styles.head, headStyle]}>
              <View style={styles.headLine} />
              <Animated.View
                style={[styles.headDot, { backgroundColor: color }, dotStyle]}
              />
            </Animated.View>
          </>
        )}
      </View>
      <View style={styles.ticks}>
        <Text style={styles.tick}>0:00</Text>
        <Text style={styles.tick}>{formatTime(timeline?.length ?? 0)}</Text>
      </View>
    </View>
  );
}

// Bars mirrored about the middle, like a groove seen side on.
const Bands = memo(function Bands({
  heights,
  width,
  fill,
}: {
  heights: number[];
  width: number;
  fill: string;
}) {
  const step = width / heights.length;
  const bar = step * 0.56;
  return (
    <Svg width={width} height={WAVE_HEIGHT}>
      {heights.map((h, i) => {
        const height = Math.max(2, h * WAVE_HEIGHT * 0.96);
        return (
          <Rect
            key={i}
            x={i * step + (step - bar) / 2}
            y={(WAVE_HEIGHT - height) / 2}
            width={bar}
            height={height}
            rx={bar / 2}
            fill={fill}
          />
        );
      })}
    </Svg>
  );
});

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingHorizontal: 24,
  },
  heading: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 14,
  },
  headingTitles: {
    flex: 1,
  },
  toggle: {
    borderWidth: 1,
    borderColor: BRASS,
    borderRadius: 12,
    paddingHorizontal: 9,
    paddingVertical: 4,
    marginTop: 8,
    marginRight: 14,
  },
  toggleText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1,
    color: BRASS,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: BRASS,
    paddingTop: 8,
  },
  neon: {
    fontFamily: FONTS.neon,
    fontSize: 30,
    lineHeight: 40,
    color: NEON,
    textShadowColor: NEON,
    textShadowRadius: 10,
  },
  hint: {
    fontFamily: FONTS.hand,
    fontSize: 19,
    lineHeight: 21,
    color: BRASS,
  },
  strips: {
    gap: 9,
    zIndex: 1,
  },
  strip: {
    height: 58,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    borderRadius: 4,
    backgroundColor: CREAM,
    borderWidth: 2,
    borderColor: 'transparent',
    overflow: 'hidden',
  },
  band: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 4,
  },
  bandTop: {
    top: 0,
  },
  bandBottom: {
    bottom: 0,
  },
  blank: {
    backgroundColor: SMOKE,
    borderColor: SMOKE_EDGE,
    borderWidth: StyleSheet.hairlineWidth,
    borderStyle: 'dashed',
  },
  blankText: {
    color: SMOKE_EDGE,
  },
  blankRule: {
    flex: 1,
    height: 2,
    borderRadius: 1,
    backgroundColor: SMOKE_EDGE,
  },
  code: {
    width: 34,
    fontFamily: FONTS.display,
    fontSize: 30,
    lineHeight: 32,
    paddingTop: 3,
  },
  stripTitles: {
    flex: 1,
  },
  stripTitle: {
    fontFamily: FONTS.display,
    fontSize: 25,
    lineHeight: 26,
    letterSpacing: 0.6,
    color: NIGHT,
    paddingTop: 3,
  },
  credit: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.3,
    color: '#6E6352',
  },
  go: {
    width: 30,
    height: 30,
    borderRadius: 15,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  goGlyph: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    marginLeft: 2,
  },
  stage: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  nowStack: {
    gap: 16,
  },
  wave: {
    height: WAVE_HEIGHT,
  },
  played: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    overflow: 'hidden',
  },
  head: {
    position: 'absolute',
    left: -5,
    top: -8,
    bottom: -8,
    width: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headLine: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 2,
    borderRadius: 1,
    backgroundColor: CREAM,
  },
  headDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    borderWidth: 2,
    borderColor: CREAM,
  },
  ticks: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 10,
  },
  tick: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.4,
    color: CREAM_SOFT,
  },
  nowCard: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(16, 14, 11, 0.86)',
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: SMOKE_EDGE,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  nowKicker: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.4,
    color: BRASS,
  },
  nowTitle: {
    fontFamily: FONTS.display,
    fontSize: 30,
    lineHeight: 32,
    color: CREAM,
    paddingTop: 3,
  },
  nowRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  nowTime: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    color: CREAM_SOFT,
  },
  lift: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: BRASS,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  liftText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.2,
    color: BRASS,
  },
  idleHead: {
    opacity: 0.55,
  },
  idleLine: {
    backgroundColor: BRASS,
    opacity: 0.5,
  },
  idleDot: {
    backgroundColor: BRASS,
    borderColor: BRASS,
  },
  idle: {
    fontFamily: FONTS.hand,
    fontSize: 22,
    color: CREAM_SOFT,
  },
});
