import { memo, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  FadeIn,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import { SETTLE } from '../diagrams/motion';
import { FONTS, INK, INK_SOFT, MOSS, VERMILION } from '../theme';
import { MermaidCard } from './MermaidCard';
import type { XYChart } from './parse';
import { useChartScale } from './scale';
import { useInstant } from '../source/face';

const AnimatedPath = Animated.createAnimatedComponent(Path);

const CHART_HEIGHT = 112;
const LABEL_HEIGHT = 18;
const GAP = 5;
const STAGGER_MS = 45;
// Under this share of the busiest bar, a bar counts as quiet.
const QUIET = 0.35;
// How far past the chart the ring may run, into the card's padding.
const RING_BLEED = 12;

// An `xychart-beta` with bars, drawn by hand: the axis is laid out as its
// line lands, the bars rise one after another, and once the block is
// complete a red pen rings the quiet run at the start.
export function BarChart({
  chart,
  complete,
}: {
  chart: XYChart;
  complete: boolean;
}) {
  const [width, setWidth] = useState(0);
  const instant = useInstant();
  const height = CHART_HEIGHT * useChartScale();
  const slots = Math.max(chart.x.length, chart.bars.length, 1);
  const barWidth = width > 0 ? (width - GAP * (slots - 1)) / slots : 0;
  const max = Math.max(1, ...chart.bars);
  let quiet = 0;
  while (quiet < chart.bars.length && chart.bars[quiet]! < max * QUIET) {
    quiet++;
  }
  const after = chart.x[quiet];

  return (
    <MermaidCard diagram="xychart" title={chart.title}>
      <View
        style={{ height }}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 &&
          Array.from({ length: slots }, (_, i) => (
            <Slot
              key={i}
              index={i}
              label={chart.x[i] ?? ''}
              value={chart.bars[i]}
              share={(chart.bars[i] ?? 0) / max}
              left={i * (barWidth + GAP)}
              width={barWidth}
              chartHeight={height}
            />
          ))}
        {width > 0 && complete && quiet > 0 && (
          <Ring
            width={quiet * (barWidth + GAP) - GAP}
            chartWidth={width}
            chartHeight={height}
          />
        )}
      </View>
      {complete && quiet > 0 && after !== undefined && (
        <Animated.Text
          entering={
            instant.current ? undefined : FadeIn.delay(900).duration(400)
          }
          style={styles.note}
        >
          {`↑ before ${after}, it's all yours`}
        </Animated.Text>
      )}
    </MermaidCard>
  );
}

const Slot = memo(function Slot({
  index,
  label,
  value,
  share,
  left,
  width,
  chartHeight,
}: {
  index: number;
  label: string;
  value: number | undefined;
  share: number;
  left: number;
  width: number;
  chartHeight: number;
}) {
  const instant = useInstant();
  const grown = useSharedValue(0);
  const known = value !== undefined;
  useEffect(() => {
    if (!known) return;
    if (instant.current) {
      grown.value = 1;
      return;
    }
    grown.value = withDelay(
      index * STAGGER_MS,
      withTiming(1, { duration: 650, easing: SETTLE })
    );
  }, [grown, known, index, instant]);
  const height = share * (chartHeight - LABEL_HEIGHT);
  const barStyle = useAnimatedStyle(() => ({
    height: Math.max(known ? 3 : 0, height * grown.value),
  }));
  const quiet = share < QUIET;
  return (
    <View style={[styles.slot, { left, width }]}>
      <Animated.View
        style={[
          styles.bar,
          quiet
            ? styles.barQuiet
            : { backgroundColor: VERMILION, opacity: 0.35 + share * 0.6 },
          barStyle,
        ]}
      />
      <Text style={styles.label}>{label}</Text>
    </View>
  );
});

// The red pen around the quiet bars, drawn in one go and a little past
// where it started, the way a hand rings something.
function Ring({
  width,
  chartWidth,
  chartHeight,
}: {
  width: number;
  chartWidth: number;
  chartHeight: number;
}) {
  const instant = useInstant();
  const drawn = useSharedValue(0);
  useEffect(() => {
    drawn.value = instant.current
      ? 1
      : withDelay(300, withTiming(1, { duration: 700, easing: SETTLE }));
  }, [drawn, instant]);
  const rx = width / 2 + 6;
  const ry = 30;
  const cx = width / 2 + RING_BLEED;
  const cy = chartHeight - 28 + RING_BLEED;
  const d =
    `M ${cx + rx} ${cy} A ${rx} ${ry} 0 1 1 ${cx - rx} ${cy}` +
    ` A ${rx} ${ry} 0 1 1 ${cx + rx * 0.86} ${cy - ry * 0.5}`;
  // Ramanujan's perimeter, and the overshoot past the start.
  const length =
    Math.PI * (3 * (rx + ry) - Math.sqrt((3 * rx + ry) * (rx + 3 * ry))) * 1.1;
  const props = useAnimatedProps(() => ({
    strokeDashoffset: length * (1 - drawn.value),
  }));
  return (
    <Svg
      style={styles.ring}
      width={chartWidth + RING_BLEED * 2}
      height={chartHeight + RING_BLEED * 2}
      pointerEvents="none"
    >
      <AnimatedPath
        d={d}
        stroke={VERMILION}
        strokeWidth={2.2}
        strokeLinecap="round"
        fill="none"
        strokeDasharray={`${length} ${length}`}
        animatedProps={props}
      />
    </Svg>
  );
}

const styles = StyleSheet.create({
  slot: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  bar: {
    alignSelf: 'stretch',
    borderTopLeftRadius: 4,
    borderTopRightRadius: 4,
  },
  barQuiet: {
    backgroundColor: MOSS,
  },
  label: {
    height: LABEL_HEIGHT,
    paddingTop: 4,
    fontFamily: FONTS.mono,
    fontSize: 10,
    color: INK_SOFT,
  },
  ring: {
    position: 'absolute',
    left: -RING_BLEED,
    top: -RING_BLEED,
  },
  note: {
    fontFamily: FONTS.hand,
    fontSize: 21,
    lineHeight: 24,
    color: INK,
    marginTop: -4,
  },
});
