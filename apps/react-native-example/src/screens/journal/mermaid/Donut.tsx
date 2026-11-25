import { memo, useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  FadeIn,
  useAnimatedProps,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Circle, Path } from 'react-native-svg';
import { SETTLE } from '../diagrams/motion';
import { FONTS, INK, INK_SOFT, MOSS, VERMILION } from '../theme';
import { MermaidCard } from './MermaidCard';
import type { PieChart } from './parse';
import { useChartScale } from './scale';
import { useInstant } from '../source/face';

const AnimatedPath = Animated.createAnimatedComponent(Path);

const SIZE = 148;
const THICKNESS = 22;
// The paper left between two slices, as a share of the ring.
const GAP = 0.006;
const SWEEP_MS = 650;
const COLORS = [VERMILION, '#2B5DAA', MOSS, '#B07A2A', '#8C5A7A', INK_SOFT];

function yen(value: number) {
  return `¥${String(Math.round(value)).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}

function radiusOf(size: number) {
  'worklet';
  return (size - THICKNESS) / 2;
}

// The arc of a ring `size` across from one share of the way round to
// another, from twelve o'clock.
function arc(from: number, to: number, size: number) {
  'worklet';
  const radius = radiusOf(size);
  const sweep = Math.min(to - from, 0.9999);
  if (sweep <= 0.0005) return `M ${size / 2} ${THICKNESS / 2}`;
  const at = (share: number) => {
    const angle = share * Math.PI * 2 - Math.PI / 2;
    return `${size / 2 + Math.cos(angle) * radius} ${
      size / 2 + Math.sin(angle) * radius
    }`;
  };
  return `M ${at(from)} A ${radius} ${radius} 0 ${sweep > 0.5 ? 1 : 0} 1 ${at(
    from + sweep
  )}`;
}

// A `pie` as a ring of ink: each slice sweeps in as its line lands, and the
// slices before it make room, so the ring is always whole.
export function Donut({
  chart,
  complete,
}: {
  chart: PieChart;
  complete: boolean;
}) {
  const size = SIZE * useChartScale();
  const instant = useInstant();
  const total = chart.slices.reduce((sum, slice) => sum + slice.value, 0);
  let start = 0;
  const placed = chart.slices.map((slice, i) => {
    const share = total > 0 ? slice.value / total : 0;
    const from = start;
    start += share;
    return { ...slice, from, to: start, share, color: COLORS[i % 6]! };
  });

  return (
    <MermaidCard diagram="pie" title={chart.title}>
      <View style={styles.row}>
        <View style={{ width: size, height: size }}>
          <Svg width={size} height={size}>
            <Circle
              cx={size / 2}
              cy={size / 2}
              r={radiusOf(size)}
              stroke="rgba(42, 33, 27, 0.07)"
              strokeWidth={THICKNESS}
              fill="none"
            />
            {placed.map((slice) => (
              <Slice
                key={slice.label}
                from={slice.from}
                to={slice.to}
                color={slice.color}
                size={size}
              />
            ))}
          </Svg>
          <View style={styles.center} pointerEvents="none">
            <Text style={styles.total}>{yen(total)}</Text>
            <Text style={styles.totalNote}>all in</Text>
          </View>
        </View>
        <View style={styles.legend}>
          {placed.map((slice) => (
            <Animated.View
              key={slice.label}
              entering={instant.current ? undefined : FadeIn.duration(300)}
              style={styles.entry}
            >
              <View style={[styles.swatch, { backgroundColor: slice.color }]} />
              <View style={styles.entryText}>
                <Text style={styles.entryLabel} numberOfLines={1}>
                  {slice.label}
                </Text>
                <Text style={styles.entryValue}>
                  {complete
                    ? `${yen(slice.value)} · ${Math.round(slice.share * 100)}%`
                    : yen(slice.value)}
                </Text>
              </View>
            </Animated.View>
          ))}
        </View>
      </View>
    </MermaidCard>
  );
}

const Slice = memo(function Slice({
  from,
  to,
  color,
  size,
}: {
  from: number;
  to: number;
  color: string;
  size: number;
}) {
  // A new slice grows out of the point where it starts.
  const instant = useInstant();
  const start = useSharedValue(from);
  const end = useSharedValue(from);
  useEffect(() => {
    const sweep = { duration: instant.current ? 0 : SWEEP_MS, easing: SETTLE };
    start.value = withTiming(from, sweep);
    end.value = withTiming(to, sweep);
  }, [start, end, from, to, instant]);
  const props = useAnimatedProps(() => ({
    d: arc(start.value + GAP, end.value - GAP, size),
  }));
  return (
    <AnimatedPath
      stroke={color}
      strokeWidth={THICKNESS}
      fill="none"
      animatedProps={props}
    />
  );
});

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  center: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  total: {
    fontFamily: FONTS.display,
    fontSize: 19,
    color: INK,
  },
  totalNote: {
    fontFamily: FONTS.hand,
    fontSize: 18,
    lineHeight: 20,
    color: INK_SOFT,
  },
  legend: {
    flex: 1,
    gap: 7,
  },
  entry: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  swatch: {
    width: 10,
    height: 10,
    borderRadius: 3,
  },
  entryText: {
    flex: 1,
  },
  entryLabel: {
    fontFamily: FONTS.body,
    fontSize: 14,
    lineHeight: 17,
    color: INK,
  },
  entryValue: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    color: INK_SOFT,
  },
});
