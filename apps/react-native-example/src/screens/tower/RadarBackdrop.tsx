import { memo, useEffect, useRef } from 'react';
import {
  Animated,
  Easing,
  StyleSheet,
  View,
  useWindowDimensions,
} from 'react-native';
import Svg, {
  Circle,
  Defs,
  Line,
  LinearGradient,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';

const SWEEP_MS = 4200;
const GREEN = '#4ADE80';

/** The rotating beam: a 48° wedge that fades along its trailing edge. */
function Sweep({ cx, cy, r }: { cx: number; cy: number; r: number }) {
  const turn = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(turn, {
        toValue: 1,
        duration: SWEEP_MS,
        easing: Easing.linear,
        useNativeDriver: true,
      })
    );
    loop.start();
    return () => loop.stop();
  }, [turn]);

  const rad = (48 * Math.PI) / 180;
  const x = r + r * Math.cos(-rad);
  const y = r + r * Math.sin(-rad);
  const wedge = `M ${r} ${r} L ${2 * r} ${r} A ${r} ${r} 0 0 0 ${x} ${y} Z`;

  return (
    <Animated.View
      style={[
        styles.sweep,
        {
          left: cx - r,
          top: cy - r,
          width: 2 * r,
          height: 2 * r,
          transform: [
            {
              rotate: turn.interpolate({
                inputRange: [0, 1],
                outputRange: ['0deg', '360deg'],
              }),
            },
          ],
        },
      ]}
    >
      <Svg width={2 * r} height={2 * r}>
        <Defs>
          <LinearGradient id="beam" x1="1" y1="0.5" x2="0.55" y2="0.08">
            <Stop offset="0" stopColor={GREEN} stopOpacity="0.5" />
            <Stop offset="1" stopColor={GREEN} stopOpacity="0" />
          </LinearGradient>
        </Defs>
        <Path d={wedge} fill="url(#beam)" />
        <Line
          x1={r}
          y1={r}
          x2={2 * r}
          y2={r}
          stroke={GREEN}
          strokeOpacity={0.9}
          strokeWidth={1.5}
        />
      </Svg>
    </Animated.View>
  );
}

type BlipSpec = { angle: number; dist: number; size: number };

/** A contact that lights when the beam passes and decays until the next pass. */
function Blip({
  cx,
  cy,
  r,
  spec,
}: {
  cx: number;
  cy: number;
  r: number;
  spec: BlipSpec;
}) {
  const glow = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    // The beam starts at 3 o'clock and turns clockwise; delay until it reaches us.
    const delay = (((spec.angle % 360) + 360) % 360) * (SWEEP_MS / 360);
    const loop = Animated.loop(
      Animated.sequence([
        Animated.delay(delay),
        Animated.timing(glow, {
          toValue: 1,
          duration: 120,
          useNativeDriver: true,
        }),
        Animated.timing(glow, {
          toValue: 0.08,
          duration: SWEEP_MS - 120 - delay,
          easing: Easing.out(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [glow, spec.angle]);

  const a = (spec.angle * Math.PI) / 180;
  return (
    <Animated.View
      style={[
        styles.blip,
        {
          left: cx + r * spec.dist * Math.cos(a) - spec.size / 2,
          top: cy + r * spec.dist * Math.sin(a) - spec.size / 2,
          width: spec.size,
          height: spec.size,
          borderRadius: spec.size / 2,
          opacity: glow,
        },
      ]}
    />
  );
}

const BLIPS: BlipSpec[] = [
  { angle: 20, dist: 0.62, size: 7 },
  { angle: 95, dist: 0.38, size: 6 },
  { angle: 150, dist: 0.8, size: 7 },
  { angle: 215, dist: 0.55, size: 5 },
  { angle: 300, dist: 0.72, size: 6 },
  { angle: 335, dist: 0.3, size: 5 },
];

/** Black glass, a radar disc rising behind the header, a beam, contacts, scanlines. */
export const RadarBackdrop = memo(function RadarBackdrop() {
  const { width, height } = useWindowDimensions();
  const cx = width * 0.5;
  const cy = height * 0.2;
  const r = width * 0.98;
  const rings = [0.25, 0.5, 0.75, 1];
  const scanlines = Math.ceil(height / 6);

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Svg width={width} height={height}>
        <Defs>
          <RadialGradient id="disc" cx="50%" cy="50%" r="50%">
            <Stop offset="0" stopColor="#14532D" stopOpacity="1" />
            <Stop offset="0.55" stopColor="#0A2E1F" stopOpacity="0.85" />
            <Stop offset="1" stopColor="#02070A" stopOpacity="0" />
          </RadialGradient>
        </Defs>
        <Rect width={width} height={height} fill="#02070A" />
        <Circle cx={cx} cy={cy} r={r * 1.1} fill="url(#disc)" />
        <Circle
          cx={cx}
          cy={cy}
          r={r}
          fill="none"
          stroke={GREEN}
          strokeOpacity={0.12}
          strokeWidth={14}
        />
        {rings.map((k) => (
          <Circle
            key={k}
            cx={cx}
            cy={cy}
            r={r * k}
            fill="none"
            stroke={GREEN}
            strokeOpacity={k === 1 ? 0.45 : 0.22}
            strokeWidth={k === 1 ? 1.2 : 0.8}
          />
        ))}
        <Line
          x1={cx - r}
          y1={cy}
          x2={cx + r}
          y2={cy}
          stroke={GREEN}
          strokeOpacity={0.18}
        />
        <Line
          x1={cx}
          y1={cy - r}
          x2={cx}
          y2={cy + r}
          stroke={GREEN}
          strokeOpacity={0.18}
        />
        {Array.from({ length: 24 }, (_, i) => {
          const a = (i * 15 * Math.PI) / 180;
          const inner = r * 0.96;
          return (
            <Line
              key={i}
              x1={cx + inner * Math.cos(a)}
              y1={cy + inner * Math.sin(a)}
              x2={cx + r * Math.cos(a)}
              y2={cy + r * Math.sin(a)}
              stroke={GREEN}
              strokeOpacity={0.5}
              strokeWidth={1}
            />
          );
        })}
      </Svg>
      <Sweep cx={cx} cy={cy} r={r} />
      {BLIPS.map((spec) => (
        <Blip key={spec.angle} cx={cx} cy={cy} r={r} spec={spec} />
      ))}
      <Svg width={width} height={height} style={StyleSheet.absoluteFill}>
        {Array.from({ length: scanlines }, (_, i) => (
          <Line
            key={i}
            x1={0}
            y1={i * 6 + 0.5}
            x2={width}
            y2={i * 6 + 0.5}
            stroke="#000"
            strokeOpacity={0.16}
            strokeWidth={1}
          />
        ))}
      </Svg>
    </View>
  );
});

const styles = StyleSheet.create({
  sweep: { position: 'absolute' },
  blip: {
    position: 'absolute',
    backgroundColor: '#BBF7D0',
    shadowColor: GREEN,
    shadowOpacity: 1,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 0 },
  },
});
