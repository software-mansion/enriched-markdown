import { memo, useEffect, useMemo } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import Animated, {
  Easing,
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
  G,
  Line,
  LinearGradient,
  Path,
  Polygon,
  RadialGradient,
  Rect,
  Stop,
  Text as SvgText,
} from 'react-native-svg';
import { Starfield } from '../FlightJournalScreen';
import { Segments } from '../renderers/Segments';
import {
  AMBER,
  AMBER_DIM,
  EL,
  FONTS,
  PANEL_EDGE,
  PAPER_SOFT,
  SPACE,
  STAR,
} from '../theme';

const SPINE = 16;
const LANDER = 34;
const DESCENT_MS = 5600;
const REST_MS = 2200;

// A point on the cubic from `p0` to `p3`.
function cubic(
  t: number,
  p0: number,
  p1: number,
  p2: number,
  p3: number
): number {
  const u = 1 - t;
  return (
    u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
  );
}

// The folded Duo is the journal's cover: the Moon rising off the bottom edge,
// and Eagle flying its descent to Tranquility Base, over and over. Open the
// phone, like the hatch, to read.
export function Cover({ onRead }: { onRead: () => void }) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();

  // The Moon: a disc far larger than the screen, its top in the lower third.
  const moon = useMemo(() => {
    const r = width * 1.05;
    const cx = width * 0.7;
    const cy = height * 0.74 + r;
    // Tranquility Base sits just left of the limb's highest point.
    const siteX = width * 0.56;
    const siteY = cy - Math.sqrt(r * r - (siteX - cx) ** 2);
    return { r, cx, cy, siteX, siteY };
  }, [width, height]);

  // Eagle's path: in from high on the left, braking, then nearly straight down.
  const path = useMemo(() => {
    const from = { x: width * 0.08, y: height * 0.36 };
    const c1 = { x: width * 0.42, y: height * 0.38 };
    const c2 = { x: moon.siteX, y: moon.siteY - height * 0.16 };
    const to = { x: moon.siteX, y: moon.siteY - LANDER * 0.42 };
    const ts = Array.from({ length: 25 }, (_, i) => i / 24);
    return {
      d: `M ${from.x} ${from.y} C ${c1.x} ${c1.y}, ${c2.x} ${c2.y}, ${to.x} ${to.y}`,
      ts,
      xs: ts.map((t) => cubic(t, from.x, c1.x, c2.x, to.x)),
      ys: ts.map((t) => cubic(t, from.y, c1.y, c2.y, to.y)),
    };
  }, [width, height, moon]);

  const t = useSharedValue(0);
  const ping = useSharedValue(0);
  useEffect(() => {
    t.value = withRepeat(
      withSequence(
        withTiming(1, {
          duration: DESCENT_MS,
          easing: Easing.out(Easing.cubic),
        }),
        withDelay(REST_MS, withTiming(0, { duration: 0 }))
      ),
      -1
    );
    ping.value = withRepeat(withTiming(1, { duration: 1600 }), -1);
  }, [t, ping]);

  const landerStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: interpolate(t.value, path.ts, path.xs) - LANDER / 2 },
      { translateY: interpolate(t.value, path.ts, path.ys) - LANDER / 2 },
      // Pitchover: flown on its back at first, upright for the last stretch.
      {
        rotate: `${interpolate(t.value, [0, 0.55, 0.8], [-38, -12, 0], 'clamp')}deg`,
      },
    ],
  }));
  const plumeStyle = useAnimatedStyle(() => ({
    opacity: interpolate(t.value, [0, 0.96, 0.995], [0.9, 0.9, 0], 'clamp'),
  }));
  const dustStyle = useAnimatedStyle(() => ({
    opacity: interpolate(t.value, [0.86, 0.97, 1], [0, 0.55, 0], 'clamp'),
    transform: [
      { scaleX: interpolate(t.value, [0.86, 1], [0.3, 1.4], 'clamp') },
    ],
  }));
  const contactStyle = useAnimatedStyle(() => ({
    opacity: interpolate(t.value, [0.985, 1], [0, 1], 'clamp'),
  }));
  const pingStyle = useAnimatedStyle(() => ({
    opacity: interpolate(ping.value, [0, 0.1, 1], [0, 0.7, 0]),
    transform: [{ scale: 1 + ping.value * 2.4 }],
  }));

  return (
    <View
      style={[
        styles.root,
        { paddingTop: insets.top + 28, paddingBottom: insets.bottom + 20 },
      ]}
    >
      <Starfield veiled={false} />
      <Moon width={width} height={height} {...moon} trajectory={path.d} />

      <Animated.View
        style={[
          styles.dust,
          { left: moon.siteX - 46, top: moon.siteY - 9 },
          dustStyle,
        ]}
        pointerEvents="none"
      />
      <Animated.View
        style={[
          styles.ping,
          { left: moon.siteX - 7, top: moon.siteY - 7 },
          pingStyle,
        ]}
        pointerEvents="none"
      />
      <Animated.View style={[styles.lander, landerStyle]} pointerEvents="none">
        <Animated.View style={[styles.plume, plumeStyle]} />
        <Eagle />
      </Animated.View>
      <Animated.View
        style={[
          styles.contact,
          { left: moon.siteX + 16, top: moon.siteY - 54 },
          contactStyle,
        ]}
        pointerEvents="none"
      >
        <Text style={styles.contactText}>CONTACT LIGHT</Text>
        <Text style={styles.contactSub}>102:45:40</Text>
      </Animated.View>

      <Spine height={height} />
      <Lamp top={height * 0.47} />

      <Text style={styles.kicker}>FLIGHT JOURNAL · JULY 20, 1969</Text>
      <Text style={styles.title}>APOLLO</Text>
      <Text style={[styles.title, styles.number]}>11</Text>
      <View style={styles.subtitleRow}>
        <Text style={styles.subtitle}>The Eagle has landed</Text>
      </View>
      <View style={styles.clock}>
        <Text style={styles.clockLabel}>GET</Text>
        <Segments text="102" height={18} />
        <Text style={styles.colon}>:</Text>
        <Segments text="45" height={18} />
        <Text style={styles.colon}>:</Text>
        <Segments text="40" height={18} />
      </View>

      <View style={styles.spacer} />
      <Text style={styles.hint}>← open the hatch to read</Text>
      <View style={styles.footer}>
        <Text style={styles.site}>TRANQUILITY BASE · 0.674° N 23.473° E</Text>
        <Pressable
          onPress={onRead}
          hitSlop={12}
          accessibilityRole="button"
          testID="flight-journal-read-folded"
        >
          <Text style={styles.folded}>read it folded →</Text>
        </Pressable>
      </View>
    </View>
  );
}

// The same craters on every render, from a fixed seed.
function craters(count: number) {
  let seed = 1969;
  const next = () => {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  };
  return Array.from({ length: count }, () => ({
    a: -Math.PI / 2 + (next() - 0.5) * 1.5,
    d: 0.08 + next() * 0.3,
    r: 3 + next() * 16,
    o: 0.08 + next() * 0.14,
  }));
}

const CRATERS = craters(26);

const Moon = memo(function Moon({
  width,
  height,
  r,
  cx,
  cy,
  siteX,
  siteY,
  trajectory,
}: {
  width: number;
  height: number;
  r: number;
  cx: number;
  cy: number;
  siteX: number;
  siteY: number;
  trajectory: string;
}) {
  return (
    <Svg
      style={StyleSheet.absoluteFill}
      width={width}
      height={height}
      pointerEvents="none"
    >
      <Defs>
        <RadialGradient
          id="moon-glow"
          cx={cx}
          cy={cy}
          r={r * 1.12}
          gradientUnits="userSpaceOnUse"
        >
          <Stop offset="0.86" stopColor="#9AA3B2" stopOpacity={0.16} />
          <Stop offset="1" stopColor="#9AA3B2" stopOpacity={0} />
        </RadialGradient>
        <LinearGradient id="moon-light" x1="0" y1="0" x2="1" y2="0.4">
          <Stop offset="0" stopColor="#D9D4C7" />
          <Stop offset="0.55" stopColor="#8E8B84" />
          <Stop offset="1" stopColor="#2B2C30" />
        </LinearGradient>
      </Defs>
      <Circle cx={cx} cy={cy} r={r * 1.12} fill="url(#moon-glow)" />
      <Circle cx={cx} cy={cy} r={r} fill="url(#moon-light)" />
      {CRATERS.map((c, i) => (
        <Circle
          key={i}
          cx={cx + Math.cos(c.a) * r * (1 - c.d)}
          cy={cy + Math.sin(c.a) * r * (1 - c.d)}
          r={c.r}
          fill="#1D1E22"
          fillOpacity={c.o}
        />
      ))}
      <Path
        d={trajectory}
        stroke={STAR}
        strokeOpacity={0.35}
        strokeWidth={1.2}
        strokeDasharray="2 7"
        strokeLinecap="round"
        fill="none"
      />
      <Circle cx={siteX} cy={siteY} r={3.5} fill={EL} />
      <SvgText
        x={siteX + 14}
        y={siteY + 30}
        textAnchor="start"
        fontFamily={FONTS.monoMedium}
        fontSize={9}
        letterSpacing={1.2}
        fill="#1A1B1F"
      >
        TRANQUILITY BASE
      </SvgText>
    </Svg>
  );
});

// The lunar module: the gold descent stage on four legs, the grey cabin above.
const Eagle = memo(function Eagle() {
  return (
    <Svg width={LANDER} height={LANDER} viewBox="0 0 34 34">
      <G>
        <Line
          x1={10}
          y1={22}
          x2={4}
          y2={30}
          stroke="#C9C3B4"
          strokeWidth={1.4}
        />
        <Line
          x1={24}
          y1={22}
          x2={30}
          y2={30}
          stroke="#C9C3B4"
          strokeWidth={1.4}
        />
        <Line
          x1={14}
          y1={23}
          x2={12}
          y2={31}
          stroke="#C9C3B4"
          strokeWidth={1.2}
        />
        <Line
          x1={20}
          y1={23}
          x2={22}
          y2={31}
          stroke="#C9C3B4"
          strokeWidth={1.2}
        />
        <Rect x={2} y={29.5} width={5} height={1.6} rx={0.8} fill="#C9C3B4" />
        <Rect x={27} y={29.5} width={5} height={1.6} rx={0.8} fill="#C9C3B4" />
        <Polygon points="8,16 26,16 28,19 26,23 8,23 6,19" fill="#C9A24A" />
        <Polygon points="11,8 23,8 25,12 23,16 11,16 9,12" fill="#A8ADB6" />
        <Rect x={14} y={10} width={4} height={3} rx={0.6} fill="#2B3038" />
        <Line x1={22} y1={8} x2={24} y2={4} stroke="#C9C3B4" strokeWidth={1} />
      </G>
    </Svg>
  );
});

// The spine along the hinge, lettered bottom to top like a shelf of logs.
function Spine({ height }: { height: number }) {
  return (
    <View style={styles.spine} pointerEvents="none">
      <Svg width={SPINE} height={height}>
        <SvgText
          x={-height / 2}
          y={11}
          transform="rotate(-90)"
          textAnchor="middle"
          fontFamily={FONTS.mono}
          fontSize={8}
          letterSpacing={3}
          fill={PAPER_SOFT}
          fillOpacity={0.7}
        >
          APOLLO 11 · FLIGHT JOURNAL · POWERED DESCENT · GET 102:33–102:45
        </SvgText>
      </Svg>
    </View>
  );
}

// A caution lamp off the panel, lit, standing in for the sticker on a sleeve.
function Lamp({ top }: { top: number }) {
  const glow = useSharedValue(1);
  useEffect(() => {
    glow.value = withRepeat(
      withSequence(
        withDelay(2400, withTiming(0.35, { duration: 90 })),
        withTiming(1, { duration: 90 }),
        withTiming(0.35, { duration: 90 }),
        withTiming(1, { duration: 90 })
      ),
      -1
    );
  }, [glow]);
  const style = useAnimatedStyle(() => ({
    opacity: 0.55 + glow.value * 0.45,
    shadowOpacity: glow.value * 0.9,
  }));
  return (
    <Animated.View style={[styles.lamp, { top }, style]} pointerEvents="none">
      <Text style={styles.lampBig}>3 DIAGRAMS</Text>
      <Text style={styles.lampMid}>INSIDE</Text>
      <Text style={styles.lampSmall}>REAL NASA AUDIO</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: SPACE,
    paddingLeft: SPINE + 24,
    paddingRight: 28,
    overflow: 'hidden',
  },
  spine: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: SPINE,
    backgroundColor: '#05070A',
    borderRightWidth: StyleSheet.hairlineWidth,
    borderRightColor: PANEL_EDGE,
  },
  kicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 2,
    color: PAPER_SOFT,
    marginBottom: 6,
  },
  title: {
    fontFamily: FONTS.display,
    fontSize: 112,
    lineHeight: 98,
    color: STAR,
    paddingTop: 12,
  },
  number: {
    color: AMBER,
  },
  subtitleRow: {
    marginTop: 6,
  },
  subtitle: {
    fontFamily: FONTS.bodyItalic,
    fontStyle: 'italic',
    fontSize: 30,
    lineHeight: 38,
    color: STAR,
  },
  clock: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: 4,
    marginTop: 14,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: PANEL_EDGE,
    backgroundColor: '#0B0D0B',
  },
  clockLabel: {
    fontFamily: FONTS.label,
    fontSize: 8,
    letterSpacing: 1.4,
    color: '#5E7A58',
    marginRight: 4,
  },
  colon: {
    fontFamily: FONTS.monoMedium,
    fontSize: 14,
    color: EL,
    marginTop: -2,
  },
  lamp: {
    position: 'absolute',
    right: 26,
    width: 116,
    paddingVertical: 12,
    borderRadius: 6,
    backgroundColor: AMBER,
    borderWidth: 3,
    borderColor: AMBER_DIM,
    alignItems: 'center',
    transform: [{ rotate: '8deg' }],
    shadowColor: AMBER,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 0 },
  },
  lampBig: {
    fontFamily: FONTS.display,
    fontSize: 22,
    lineHeight: 23,
    color: '#2A1A00',
    paddingTop: 4,
  },
  lampMid: {
    fontFamily: FONTS.display,
    fontSize: 16,
    lineHeight: 17,
    letterSpacing: 3,
    color: '#2A1A00',
  },
  lampSmall: {
    fontFamily: FONTS.monoMedium,
    fontSize: 7,
    letterSpacing: 1,
    color: '#5C3B00',
    marginTop: 4,
  },
  lander: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: LANDER,
    height: LANDER,
  },
  plume: {
    position: 'absolute',
    left: LANDER / 2 - 3,
    top: LANDER - 6,
    width: 6,
    height: 16,
    borderRadius: 3,
    backgroundColor: 'rgba(255, 181, 71, 0.7)',
  },
  dust: {
    position: 'absolute',
    width: 92,
    height: 18,
    borderRadius: 9,
    backgroundColor: 'rgba(217, 212, 199, 0.6)',
  },
  ping: {
    position: 'absolute',
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: EL,
  },
  contact: {
    position: 'absolute',
  },
  contactText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.4,
    color: EL,
  },
  contactSub: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1,
    color: PAPER_SOFT,
  },
  spacer: {
    flex: 1,
  },
  hint: {
    fontFamily: FONTS.hand,
    fontSize: 30,
    color: AMBER,
    marginBottom: 14,
    transform: [{ rotate: '-4deg' }],
  },
  site: {
    flex: 1,
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.2,
    color: '#1A1B1F',
  },
  folded: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1,
    color: '#1A1B1F',
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
});
