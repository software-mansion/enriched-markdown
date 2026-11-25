import { memo, useEffect, useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { AMBER, EL, FONTS, PANEL, PANEL_EDGE, PAPER, STAR } from '../theme';
import { CardTitle, cardStyle } from './CardTitle';
import { SETTLE, codeLines, useEntrance } from './motion';

const ROW_HEIGHT = 60;
const RAIL_MS = 260;

interface Event {
  time: string;
  seconds: number;
  kind: string;
  text: string;
}

// `102:38:26  ALARM  1202, the computer is overloaded`: a Ground Elapsed
// Time, one word for the kind of moment, and what happened.
function event(line: string): Event | null {
  const match = line.match(/^(\d{3}):(\d{2})(?::(\d{2}))?\s+(\S+)\s+(.*)$/);
  if (!match) return null;
  const [, h, m, s, kind, text] = match;
  return {
    time: s ? `${h}:${m}:${s}` : `${h}:${m}`,
    seconds: Number(h) * 3600 + Number(m) * 60 + Number(s ?? 0),
    kind: kind!,
    text: text!.trim(),
  };
}

function colorFor(kind: string) {
  if (kind === 'ALARM') return AMBER;
  if (kind === 'CONTACT') return EL;
  return STAR;
}

function duration(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  return `${minutes} MIN ${seconds % 60} S`;
}

// A ```timeline block as a mission rail: each moment drops onto it as its
// line streams in, and the closing fence sweeps the whole span below.
export function Timeline({ block }: { block: MarkdownCodeBlock }) {
  const events = useMemo(
    () =>
      codeLines(block.code)
        .map(event)
        .filter((e): e is Event => e !== null),
    [block.code]
  );
  const entrance = useEntrance();
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));

  const first = events[0];
  const last = events[events.length - 1];
  const span = first && last ? last.seconds - first.seconds : 0;

  return (
    <Animated.View style={[styles.card, style]}>
      <CardTitle
        renderer="Timeline"
        title="POWERED DESCENT · GROUND ELAPSED TIME"
      />
      <View>
        {events.map((e, i) => (
          <Row key={e.time} event={e} first={i === 0} />
        ))}
      </View>
      {block.isComplete && first && last && (
        <Span events={events} span={span} start={first.seconds} />
      )}
    </Animated.View>
  );
}

const Row = memo(function Row({
  event: e,
  first,
}: {
  event: Event;
  first: boolean;
}) {
  const rail = useSharedValue(first ? 1 : 0);
  const dot = useSharedValue(0);
  const text = useSharedValue(0);
  const color = colorFor(e.kind);
  const alarm = e.kind === 'ALARM';

  useEffect(() => {
    rail.value = withTiming(1, { duration: RAIL_MS, easing: SETTLE });
    const after = first ? 0 : RAIL_MS;
    dot.value = withDelay(after, withSpring(1, { damping: 9, stiffness: 180 }));
    text.value = withDelay(
      after + 60,
      withTiming(1, { duration: 380, easing: SETTLE })
    );
  }, [rail, dot, text, first]);

  const railStyle = useAnimatedStyle(() => ({
    transform: [{ scaleY: rail.value }],
  }));
  const dotStyle = useAnimatedStyle(() => ({
    transform: [{ scale: dot.value }],
  }));
  const textStyle = useAnimatedStyle(() => ({
    opacity: text.value,
    transform: [{ translateX: interpolate(text.value, [0, 1], [12, 0]) }],
  }));

  return (
    <View style={styles.row}>
      <Animated.Text style={[styles.time, textStyle]}>{e.time}</Animated.Text>
      <View style={styles.track}>
        {!first && <Animated.View style={[styles.rail, railStyle]} />}
        {alarm && <Pulse color={color} />}
        <Animated.View
          style={[styles.dot, { backgroundColor: color }, dotStyle]}
        />
      </View>
      <Animated.View style={[styles.copy, textStyle]}>
        <Text style={[styles.kind, { color }]}>{e.kind}</Text>
        <Text style={styles.text} numberOfLines={2}>
          {e.text}
        </Text>
      </Animated.View>
    </View>
  );
});

// The caution lamp's ring, still going after the moment has passed.
function Pulse({ color }: { color: string }) {
  const ping = useSharedValue(0);
  useEffect(() => {
    ping.value = withDelay(
      RAIL_MS,
      withRepeat(withTiming(1, { duration: 1300 }), -1)
    );
  }, [ping]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(ping.value, [0, 0.1, 1], [0, 0.8, 0]),
    transform: [{ scale: 1 + ping.value * 1.6 }],
  }));
  return (
    <Animated.View style={[styles.pulse, { borderColor: color }, style]} />
  );
}

// The whole descent to scale: each moment is a tick, and a fill sweeps from
// ignition to contact once the block is complete.
function Span({
  events,
  span,
  start,
}: {
  events: Event[];
  span: number;
  start: number;
}) {
  const fill = useSharedValue(0);
  const label = useSharedValue(0);
  useEffect(() => {
    fill.value = withDelay(
      200,
      withTiming(1, { duration: 1400, easing: SETTLE })
    );
    label.value = withDelay(1300, withTiming(1, { duration: 300 }));
  }, [fill, label]);
  const fillStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: fill.value }],
  }));
  const labelStyle = useAnimatedStyle(() => ({ opacity: label.value }));

  return (
    <View style={styles.span}>
      <View style={styles.spanTrack}>
        <Animated.View style={[styles.spanFill, fillStyle]} />
        {events.map((e) => (
          <View
            key={e.time}
            style={[
              styles.tick,
              {
                left: `${span ? ((e.seconds - start) / span) * 100 : 0}%`,
                backgroundColor: colorFor(e.kind),
              },
            ]}
          />
        ))}
      </View>
      <Animated.Text style={[styles.spanLabel, labelStyle]}>
        {`${duration(span)} FROM IGNITION TO CONTACT`}
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    ...cardStyle,
    gap: 14,
  },
  row: {
    height: ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
  },
  time: {
    width: 74,
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    color: EL,
  },
  track: {
    width: 26,
    height: ROW_HEIGHT,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rail: {
    position: 'absolute',
    top: -ROW_HEIGHT / 2,
    height: ROW_HEIGHT,
    width: 2,
    backgroundColor: PANEL_EDGE,
    transformOrigin: 'top',
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: PANEL,
  },
  pulse: {
    position: 'absolute',
    width: 12,
    height: 12,
    borderRadius: 6,
    borderWidth: 2,
  },
  copy: {
    flex: 1,
    paddingLeft: 8,
  },
  kind: {
    fontFamily: FONTS.label,
    fontSize: 9,
    letterSpacing: 1.4,
  },
  text: {
    fontFamily: FONTS.body,
    fontSize: 15,
    lineHeight: 19,
    color: PAPER,
  },
  span: {
    gap: 8,
    paddingTop: 4,
  },
  spanTrack: {
    height: 6,
    borderRadius: 3,
    backgroundColor: '#0A0D12',
    overflow: 'hidden',
  },
  spanFill: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(244, 241, 234, 0.22)',
    transformOrigin: 'left',
  },
  tick: {
    position: 'absolute',
    top: 0,
    width: 3,
    height: 6,
    marginLeft: -1.5,
  },
  spanLabel: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1,
    color: STAR,
    textAlign: 'center',
  },
});
