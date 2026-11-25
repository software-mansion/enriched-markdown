import { memo, useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  interpolate,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  withDelay,
  withRepeat,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, { Ellipse, Path, Polygon } from 'react-native-svg';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { FONTS, INK, INK_SOFT, PAPER, RIVER, VERMILION } from '../theme';
import { SETTLE, codeLines, diagramStyles, useEntrance } from './motion';
import { useInstant } from '../source/face';

const CANVAS_HEIGHT = 132;
const TRACK_Y = 70;
const INSET = 10;
const TRAIN_LENGTH = 52;
const TRAIN_HEIGHT = 13;
// How far past its end station the train may stand.
const BUFFER = 4;
const STRIPE = '#2B5DAA';

// The ride, sped up: the whole line in a few seconds, braking into each
// station and standing there a moment before pulling out again.
const LINE_MS = 3600;
const MIN_LEG_MS = 900;
const DWELL_MS = 700;
const BOARD_MS = 600;
const ARRIVED_MS = 1200;
const FADE_MS = 350;
const RIPPLE_MS = 800;
const DEPART_DELAY = 700;

interface Stop {
  time: string;
  minutes: number;
  name: string;
}

const STOP = String.raw`(\d{2}):(\d{2})\s+(.+?)`;
const ROUTE = new RegExp(String.raw`^${STOP}\s+-->\s+${STOP}$`);
const ALONG = /^(\d{2}):(\d{2})\s+(\^\s+)?(.+)$/;

function stop(h: string, m: string, name: string): Stop {
  return {
    time: `${h}:${m}`,
    minutes: Number(h) * 60 + Number(m),
    name: name.trim(),
  };
}

// `07:33 Tokyo --> 09:47 Kyoto` opens the line, then a line per stop on the
// way, `^` for something to see from the window rather than a station.
function parse(lines: string[]) {
  let route: { from: Stop; to: Stop } | null = null;
  const stops: Stop[] = [];
  const sights: Stop[] = [];
  for (const line of lines) {
    const ends = line.match(ROUTE);
    if (ends) {
      route = {
        from: stop(ends[1]!, ends[2]!, ends[3]!),
        to: stop(ends[4]!, ends[5]!, ends[6]!),
      };
      continue;
    }
    const along = line.match(ALONG);
    if (!along) continue;
    const point = stop(along[1]!, along[2]!, along[4]!);
    (along[3] ? sights : stops).push(point);
  }
  return { route, stops, sights };
}

function duration(minutes: number) {
  return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
}

interface Leg {
  start: number;
  end: number;
  from: number;
  to: number;
}

// When, on the loop's clock, the train runs each leg between stations at
// these fractions of the line, and when it reaches each one.
function timetable(stations: number[]) {
  const legs: Leg[] = [];
  const arrivals = [FADE_MS];
  let t = BOARD_MS;
  for (let i = 1; i < stations.length; i++) {
    const from = stations[i - 1]!;
    const to = stations[i]!;
    const end = t + Math.max(MIN_LEG_MS, (to - from) * LINE_MS);
    legs.push({ start: t, end, from, to });
    arrivals.push(end);
    t = end + (i < stations.length - 1 ? DWELL_MS : 0);
  }
  const leave = t + ARRIVED_MS;
  return { legs, arrivals, leave, loop: leave + FADE_MS * 2 };
}

function easeInOut(k: number) {
  'worklet';
  return k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
}

// Where the train is along the line at a time on the clock, and how fast it
// is going, from 0 standing to 1 at full speed.
function rideAt(t: number, legs: Leg[]) {
  'worklet';
  let at = 0;
  for (const leg of legs) {
    if (t < leg.start) break;
    if (t <= leg.end) {
      const k = (t - leg.start) / (leg.end - leg.start);
      return {
        at: leg.from + (leg.to - leg.from) * easeInOut(k),
        speed: 1 - (2 * k - 1) ** 2,
      };
    }
    at = leg.to;
  }
  return { at, speed: 0 };
}

// A ```rail block as the Tokaido line: the ends are drawn as the first line
// lands, each stop and sight as its line streams in, and once the block is
// complete a Shinkansen runs the timetable, inking the line behind it.
export function RailLine({ block }: { block: MarkdownCodeBlock }) {
  const { route, stops, sights } = useMemo(
    () => parse(codeLines(block.code)),
    [block.code]
  );
  const [width, setWidth] = useState(0);
  const entrance = useEntrance();
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));

  const from = route?.from.minutes ?? 0;
  const span = route ? route.to.minutes - from : 0;
  const at = (minutes: number) => (span > 0 ? (minutes - from) / span : 0);
  const x = (fraction: number) => INSET + fraction * (width - INSET * 2);

  const { legs, arrivals, leave, loop } = useMemo(() => {
    const along = stops.map((s) => (span > 0 ? (s.minutes - from) / span : 0));
    return timetable([0, ...along.sort((a, b) => a - b), 1]);
  }, [stops, from, span]);

  // One clock runs the loop; the train, the ink and the stations all read it.
  const clock = useSharedValue(0);
  const inked = useSharedValue(0);
  useEffect(() => {
    if (!block.isComplete) return;
    clock.value = withDelay(
      DEPART_DELAY,
      withRepeat(
        withTiming(loop, { duration: loop, easing: Easing.linear }),
        -1
      )
    );
    // The first ride inks the line; after that it stays inked.
    inked.value = withDelay(
      DEPART_DELAY + arrivals[arrivals.length - 1]!,
      withTiming(1, { duration: 0 })
    );
  }, [block.isComplete, clock, inked, loop, arrivals]);
  const ride = useDerivedValue(() => rideAt(clock.value, legs));

  const instant = useInstant();
  const timed = useSharedValue(0);
  useEffect(() => {
    if (block.isComplete && route) {
      timed.value = instant.current
        ? 1
        : withDelay(900, withTiming(1, { duration: 400 }));
    }
  }, [block.isComplete, route, timed, instant]);
  const durationStyle = useAnimatedStyle(() => ({ opacity: timed.value }));

  const inkStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: Math.max(inked.value, ride.value.at) }],
  }));
  const trainStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      clock.value,
      [0, FADE_MS, leave, leave + FADE_MS],
      [0, 1, 1, 0],
      'clamp'
    ),
    // Tail at the first platform, nose at the last: the train stays on the
    // line at both ends.
    transform: [
      {
        translateX:
          INSET +
          ride.value.at * (width - INSET * 2) -
          BUFFER -
          ride.value.at * (TRAIN_LENGTH - BUFFER * 2),
      },
    ],
  }));
  const streakStyle = useAnimatedStyle(() => ({
    opacity: ride.value.speed * 0.8,
    transform: [{ scaleX: ride.value.speed }],
  }));

  const stations = route
    ? [
        { stop: route.from, align: 'start' as const, end: true },
        ...stops.map((s) => ({
          stop: s,
          align: 'center' as const,
          end: false,
        })),
        { stop: route.to, align: 'end' as const, end: true },
      ].sort((a, b) => a.stop.minutes - b.stop.minutes)
    : [];

  return (
    <Animated.View style={[diagramStyles.card, styles.card, style]}>
      <View style={styles.head}>
        <Text style={styles.kanji}>東海道新幹線</Text>
        <Text style={styles.kicker}>TOKAIDO SHINKANSEN</Text>
        {/* Laid out from the start, so its line height never moves the card. */}
        <Animated.Text style={[styles.duration, durationStyle]}>
          {duration(span)}
        </Animated.Text>
      </View>
      <View
        style={styles.canvas}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 && route && (
          <>
            <View style={[styles.track, { left: INSET, right: INSET }]} />
            <Animated.View
              style={[styles.ink, { left: INSET, right: INSET }, inkStyle]}
            />
            {sights.map((sight) => (
              <Sight
                key={sight.time}
                sight={sight}
                x={x(at(sight.minutes))}
                fraction={at(sight.minutes)}
                ride={ride}
              />
            ))}
            {stations.map((station, i) => (
              <Station
                key={station.stop.time}
                stop={station.stop}
                x={x(at(station.stop.minutes))}
                align={station.align}
                end={station.end}
                clock={clock}
                arrival={block.isComplete ? arrivals[i] : undefined}
              />
            ))}
            {block.isComplete && (
              <Animated.View
                style={[styles.train, trainStyle]}
                pointerEvents="none"
              >
                <Animated.View style={[styles.streaks, streakStyle]}>
                  <View style={[styles.streak, styles.streakLong]} />
                  <View style={[styles.streak, styles.streakShort]} />
                </Animated.View>
                <Shinkansen />
              </Animated.View>
            )}
          </>
        )}
      </View>
    </Animated.View>
  );
}

// An N700 from the side, nose first: the long duck-bill, the cab window,
// a row of windows and the blue stripe.
const Shinkansen = memo(function Shinkansen() {
  return (
    <Svg width={TRAIN_LENGTH} height={TRAIN_HEIGHT + 2}>
      <Ellipse
        cx={TRAIN_LENGTH / 2}
        cy={TRAIN_HEIGHT + 0.6}
        rx={TRAIN_LENGTH / 2 - 2}
        ry={1.3}
        fill={INK}
        opacity={0.16}
      />
      <Path
        d="M4 1.5 H31 C40 1.5 46.5 5 51.2 9.7 Q52 12 49.5 12 H3.5 Q1 12 1 9.5 V4 Q1 1.5 4 1.5 Z"
        fill="#FFFFFF"
        stroke={INK}
        strokeWidth={0.9}
      />
      <Path d="M1.4 9 H49.3" stroke={STRIPE} strokeWidth={1.7} />
      <Path d="M1.4 10.7 H50.5" stroke={STRIPE} strokeWidth={0.6} />
      <Path
        d="M5 5 H28.5"
        stroke={INK}
        strokeWidth={1.8}
        strokeDasharray="2.6 1.5"
        opacity={0.78}
      />
      <Path d="M33 3.1 C38 3.3 41.8 4.9 44.2 6.8 H34.2 Z" fill={INK} />
      <Path d="M18.5 2 V11.5" stroke={INK} strokeWidth={0.6} opacity={0.25} />
    </Svg>
  );
});

const LABEL_WIDTH = 110;

const ALIGN = {
  start: { alignItems: 'flex-start' },
  center: { alignItems: 'center' },
  end: { alignItems: 'flex-end' },
} as const;

// A station on the line, with a ripple out of its dot as the train pulls in.
const Station = memo(function Station({
  stop: s,
  x,
  align = 'center',
  end = false,
  clock,
  arrival,
}: {
  stop: Stop;
  x: number;
  align?: 'start' | 'center' | 'end';
  end?: boolean;
  clock: SharedValue<number>;
  arrival: number | undefined;
}) {
  const instant = useInstant();
  const shown = useSharedValue(0);
  useEffect(() => {
    shown.value = instant.current
      ? 1
      : withTiming(1, { duration: 500, easing: SETTLE });
  }, [shown, instant]);
  const dotStyle = useAnimatedStyle(() => ({
    transform: [{ scale: interpolate(shown.value, [0, 1], [0.3, 1]) }],
    opacity: shown.value,
  }));
  const labelStyle = useAnimatedStyle(() => ({
    opacity: interpolate(shown.value, [0.2, 1], [0, 1], 'clamp'),
    transform: [{ translateY: interpolate(shown.value, [0, 1], [-6, 0]) }],
  }));
  const rippleStyle = useAnimatedStyle(() => {
    const p = arrival === undefined ? -1 : (clock.value - arrival) / RIPPLE_MS;
    const live = p >= 0 && p <= 1;
    return {
      opacity: live ? 0.55 * (1 - p) : 0,
      transform: [{ scale: live ? 1 + 1.8 * (1 - (1 - p) ** 2) : 1 }],
    };
  });
  const size = end ? 14 : 10;
  const left =
    align === 'start' ? x - 6 : align === 'end' ? x - LABEL_WIDTH + 6 : x;
  const ring = {
    width: size,
    height: size,
    borderRadius: size / 2,
    left: x - size / 2,
    top: TRACK_Y - size / 2 + 1,
  };
  return (
    <>
      <Animated.View style={[styles.ripple, ring, rippleStyle]} />
      <Animated.View style={[styles.dot, ring, dotStyle]} />
      <Animated.View
        style={[
          styles.label,
          {
            left: align === 'center' ? left - LABEL_WIDTH / 2 : left,
          },
          ALIGN[align],
          labelStyle,
        ]}
      >
        <Text style={[styles.station, !end && styles.stationSmall]}>
          {s.name}
        </Text>
        <Text style={styles.time}>{s.time}</Text>
      </Animated.View>
    </>
  );
});

const MOUNTAIN_WIDTH = 46;
const MOUNTAIN_HEIGHT = 30;

// Something to look up for: a peak over the line, rising to meet the train
// as it goes past.
const Sight = memo(function Sight({
  sight,
  x,
  fraction,
  ride,
}: {
  sight: Stop;
  x: number;
  fraction: number;
  ride: SharedValue<{ at: number; speed: number }>;
}) {
  const instant = useInstant();
  const shown = useSharedValue(0);
  useEffect(() => {
    shown.value = instant.current
      ? 1
      : withTiming(1, { duration: 600, easing: SETTLE });
  }, [shown, instant]);
  const style = useAnimatedStyle(() => {
    const distance = Math.abs(ride.value.at - fraction) * 7;
    const near = distance < 1 ? easeInOut(1 - distance) : 0;
    return {
      opacity: shown.value,
      transform: [
        { translateY: interpolate(shown.value, [0, 1], [12, 0]) - near * 3 },
        { scale: interpolate(shown.value, [0, 1], [0.7, 1]) + near * 0.16 },
      ],
    };
  });
  return (
    <Animated.View
      style={[styles.sight, { left: x - LABEL_WIDTH / 2 }, style]}
      pointerEvents="none"
    >
      <Text style={styles.sightName} numberOfLines={1}>
        {sight.name}
      </Text>
      <Svg width={MOUNTAIN_WIDTH} height={MOUNTAIN_HEIGHT}>
        <Polygon
          points={`0,${MOUNTAIN_HEIGHT} 18,6 23,3 28,6 ${MOUNTAIN_WIDTH},${MOUNTAIN_HEIGHT}`}
          fill={RIVER}
        />
        <Polygon
          points="13,12 18,6 23,3 28,6 33,12 28,10 23,13 18,10"
          fill={PAPER}
        />
      </Svg>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  card: {
    gap: 10,
  },
  head: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 8,
  },
  kanji: {
    fontFamily: FONTS.mincho,
    fontSize: 13,
    color: VERMILION,
  },
  kicker: {
    flex: 1,
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.2,
    color: INK_SOFT,
  },
  duration: {
    fontFamily: FONTS.hand,
    fontSize: 21,
    color: VERMILION,
  },
  canvas: {
    height: CANVAS_HEIGHT,
  },
  track: {
    position: 'absolute',
    top: TRACK_Y,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: 'rgba(42, 33, 27, 0.14)',
  },
  ink: {
    position: 'absolute',
    top: TRACK_Y,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: VERMILION,
    transformOrigin: 'left',
  },
  dot: {
    position: 'absolute',
    backgroundColor: PAPER,
    borderWidth: 2.5,
    borderColor: INK,
  },
  ripple: {
    position: 'absolute',
    borderWidth: 2,
    borderColor: VERMILION,
  },
  label: {
    position: 'absolute',
    top: TRACK_Y + 14,
    width: LABEL_WIDTH,
  },
  station: {
    fontFamily: FONTS.display,
    fontSize: 17,
    color: INK,
  },
  stationSmall: {
    fontSize: 14,
    color: INK_SOFT,
  },
  time: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: INK_SOFT,
  },
  sight: {
    position: 'absolute',
    top: TRACK_Y - MOUNTAIN_HEIGHT - 34,
    width: LABEL_WIDTH,
    alignItems: 'center',
    transformOrigin: 'bottom',
  },
  sightName: {
    fontFamily: FONTS.hand,
    fontSize: 20,
    lineHeight: 26,
    color: INK,
  },
  train: {
    position: 'absolute',
    left: 0,
    top: TRACK_Y + 3 - TRAIN_HEIGHT,
    width: TRAIN_LENGTH,
  },
  streaks: {
    position: 'absolute',
    right: TRAIN_LENGTH - 2,
    top: 3,
    width: 26,
    gap: 3,
    alignItems: 'flex-end',
    transformOrigin: 'right',
  },
  streak: {
    height: 1.4,
    borderRadius: 1,
    backgroundColor: INK_SOFT,
  },
  streakLong: {
    width: 26,
  },
  streakShort: {
    width: 15,
  },
});
