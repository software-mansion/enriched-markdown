import { memo, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  FadeIn,
  interpolate,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import { SETTLE } from '../diagrams/motion';
import { FONTS, INK, INK_SOFT, VERMILION } from '../theme';
import { MermaidCard } from './MermaidCard';
import type { Journey } from './parse';
import { useChartScale } from './scale';
import { useInstant } from '../source/face';

const AnimatedPath = Animated.createAnimatedComponent(Path);

const BAND_HEIGHT = 24;
const PLOT_HEIGHT = 104;
const PLOT_PAD = 12;
const DOT = 14;
const DRAW_MS = 380;
// The columns a day is laid out in before the answer has written them all.
const MIN_COLUMNS = 6;

// A dot lands with a slight give, not a bounce.
const POP = Easing.out(Easing.back(1.2));

const SCORE_COLORS = ['', INK, INK_SOFT, '#B07A2A', '#D9822B', VERMILION];

function scoreY(score: number, plotHeight: number) {
  return (
    BAND_HEIGHT + PLOT_PAD + ((5 - score) / 4) * (plotHeight - PLOT_PAD * 2)
  );
}

// A `journey` as a day on paper: each section a band of the day, each task
// a dot at how it felt, and an ink line drawn on to it as its line lands.
// Once the block is complete the day is washed in underneath.
export function MoodLine({
  chart,
  complete,
}: {
  chart: Journey;
  complete: boolean;
}) {
  const [width, setWidth] = useState(0);
  const instant = useInstant();
  const plotHeight = PLOT_HEIGHT * useChartScale();
  const tasks = chart.sections.flatMap((section, s) =>
    section.tasks.map((task) => ({ ...task, section: s }))
  );
  const columns = Math.max(tasks.length, MIN_COLUMNS);
  const column = width / columns;
  const points = tasks.map((task, i) => ({
    x: (i + 0.5) * column,
    y: scoreY(task.score, plotHeight),
  }));

  let first = 0;
  const bands = chart.sections.map((section, s) => {
    const band = {
      name: section.name,
      from: first,
      count: section.tasks.length,
    };
    first += section.tasks.length;
    return { ...band, key: s };
  });

  const wash =
    points.length > 1
      ? `M ${points[0]!.x} ${BAND_HEIGHT + plotHeight} ` +
        points
          .map((p, i) =>
            i === 0 ? `L ${p.x} ${p.y}` : curve(points[i - 1]!, p)
          )
          .join(' ') +
        ` L ${points[points.length - 1]!.x} ${BAND_HEIGHT + plotHeight} Z`
      : null;

  return (
    <MermaidCard diagram="journey" title={chart.title}>
      <View
        style={{ height: BAND_HEIGHT + plotHeight }}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 && (
          <>
            {bands.map((band) => (
              <Band
                key={band.key}
                name={band.name}
                left={band.from * column}
                width={Math.max(band.count, 1) * column}
                tinted={band.key % 2 === 0}
              />
            ))}
            <Svg
              style={StyleSheet.absoluteFill}
              width={width}
              height={BAND_HEIGHT + plotHeight}
              pointerEvents="none"
            >
              {complete && wash && <Wash d={wash} />}
              {points.slice(1).map((p, i) => (
                <Segment key={i} from={points[i]!} to={p} />
              ))}
            </Svg>
            {tasks.map((task, i) => (
              <Dot
                key={i}
                x={points[i]!.x}
                y={points[i]!.y}
                score={task.score}
                delayed={i > 0}
              />
            ))}
          </>
        )}
      </View>
      {width > 0 && (
        <View style={styles.labels}>
          {tasks.map((task, i) => (
            <Animated.Text
              key={i}
              entering={
                instant.current
                  ? undefined
                  : FadeIn.delay(i > 0 ? DRAW_MS : 0).duration(300)
              }
              style={[styles.task, { left: i * column, width: column }]}
              numberOfLines={2}
              adjustsFontSizeToFit
              minimumFontScale={0.8}
            >
              {task.name}
            </Animated.Text>
          ))}
        </View>
      )}
    </MermaidCard>
  );
}

function curve(from: { x: number; y: number }, to: { x: number; y: number }) {
  const mid = (from.x + to.x) / 2;
  return `C ${mid} ${from.y}, ${mid} ${to.y}, ${to.x} ${to.y}`;
}

function Band({
  name,
  left,
  width,
  tinted,
}: {
  name: string;
  left: number;
  width: number;
  tinted: boolean;
}) {
  const instant = useInstant();
  return (
    <Animated.View
      entering={instant.current ? undefined : FadeIn.duration(300)}
      style={[styles.band, tinted && styles.bandTinted, { left, width }]}
    >
      <Text style={styles.bandName} numberOfLines={1}>
        {name}
      </Text>
    </Animated.View>
  );
}

const Segment = memo(function Segment({
  from,
  to,
}: {
  from: { x: number; y: number };
  to: { x: number; y: number };
}) {
  const instant = useInstant();
  const drawn = useSharedValue(0);
  useEffect(() => {
    drawn.value = instant.current
      ? 1
      : withTiming(1, { duration: DRAW_MS, easing: SETTLE });
  }, [drawn, instant]);
  const length = Math.hypot(to.x - from.x, to.y - from.y) * 1.15 + 4;
  const props = useAnimatedProps(() => ({
    strokeDashoffset: length * (1 - drawn.value),
  }));
  return (
    <AnimatedPath
      d={`M ${from.x} ${from.y} ${curve(from, to)}`}
      stroke={INK}
      strokeWidth={2.2}
      strokeLinecap="round"
      fill="none"
      strokeDasharray={`${length} ${length}`}
      animatedProps={props}
    />
  );
});

function Wash({ d }: { d: string }) {
  const instant = useInstant();
  const shown = useSharedValue(0);
  useEffect(() => {
    shown.value = instant.current
      ? 1
      : withDelay(200, withTiming(1, { duration: 900 }));
  }, [shown, instant]);
  const props = useAnimatedProps(() => ({ fillOpacity: shown.value * 0.12 }));
  return <AnimatedPath d={d} fill={VERMILION} animatedProps={props} />;
}

const Dot = memo(function Dot({
  x,
  y,
  score,
  delayed,
}: {
  x: number;
  y: number;
  score: number;
  delayed: boolean;
}) {
  const instant = useInstant();
  const shown = useSharedValue(0);
  useEffect(() => {
    shown.value = instant.current
      ? 1
      : withDelay(
          delayed ? DRAW_MS * 0.85 : 0,
          withTiming(1, { duration: 420, easing: POP })
        );
  }, [shown, delayed, instant]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(shown.value, [0, 0.3], [0, 1], 'clamp'),
    transform: [{ scale: shown.value }],
  }));
  return (
    <Animated.View
      style={[
        styles.dot,
        {
          left: x - DOT / 2,
          top: y - DOT / 2,
          backgroundColor: SCORE_COLORS[score],
        },
        style,
      ]}
    />
  );
});

const styles = StyleSheet.create({
  band: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    borderRadius: 8,
    paddingTop: 2,
    alignItems: 'center',
  },
  bandTinted: {
    backgroundColor: 'rgba(42, 33, 27, 0.045)',
  },
  bandName: {
    fontFamily: FONTS.hand,
    fontSize: 18,
    lineHeight: 20,
    color: INK_SOFT,
  },
  dot: {
    position: 'absolute',
    width: DOT,
    height: DOT,
    borderRadius: DOT / 2,
    borderWidth: 2.5,
    borderColor: '#FBF6EC',
  },
  labels: {
    height: 34,
  },
  task: {
    position: 'absolute',
    top: 0,
    paddingHorizontal: 2,
    fontFamily: FONTS.body,
    fontSize: 12,
    lineHeight: 15,
    color: INK,
    textAlign: 'center',
  },
});
