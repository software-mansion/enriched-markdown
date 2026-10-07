import { memo, useEffect, useMemo, useRef } from 'react';
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
  Ellipse,
  LinearGradient,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';

function seeded(n: number): number {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
}

type Star = { x: number; y: number; r: number; o: number };

function makeStars(
  count: number,
  width: number,
  height: number,
  salt: number
): Star[] {
  return Array.from({ length: count }, (_, i) => ({
    x: seeded(i * 3 + salt) * width,
    // Thin out toward the horizon, where the planet's glow takes over.
    y: Math.pow(seeded(i * 3 + salt + 1), 1.25) * height * 0.86,
    r: 0.5 + seeded(i * 3 + salt + 2) * 1.1,
    o: 0.35 + seeded(i * 7 + salt) * 0.65,
  }));
}

/** One layer of stars that slowly breathes, out of step with the others. */
const Twinkle = memo(function Twinkle({
  stars,
  width,
  height,
  delay,
  duration,
}: {
  stars: Star[];
  width: number;
  height: number;
  delay: number;
  duration: number;
}) {
  const opacity = useRef(new Animated.Value(0.25)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 1,
          duration,
          delay,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0.25,
          duration,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [delay, duration, opacity]);

  return (
    <Animated.View style={[StyleSheet.absoluteFill, { opacity }]}>
      <Svg width={width} height={height}>
        {stars.map((star, i) => (
          <Circle
            key={i}
            cx={star.x}
            cy={star.y}
            r={star.r}
            fill="#FFFFFF"
            opacity={star.o}
          />
        ))}
      </Svg>
    </Animated.View>
  );
});

/** A meteor that crosses the upper sky every few seconds. */
function Meteor({ width }: { width: number }) {
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.delay(3200),
        Animated.timing(progress, {
          toValue: 1,
          duration: 900,
          easing: Easing.out(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.delay(4600),
        Animated.timing(progress, {
          toValue: 0,
          duration: 0,
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [progress]);

  const style = {
    opacity: progress.interpolate({
      inputRange: [0, 0.15, 0.7, 1],
      outputRange: [0, 1, 0.9, 0],
    }),
    transform: [
      {
        translateX: progress.interpolate({
          inputRange: [0, 1],
          outputRange: [width * 0.92, width * 0.22],
        }),
      },
      {
        translateY: progress.interpolate({
          inputRange: [0, 1],
          outputRange: [70, 220],
        }),
      },
      { rotate: '-25deg' },
    ],
  };
  return <Animated.View style={[styles.meteor, style]} />;
}

/**
 * Deep space over a Mars horizon: two nebulae, three layers of twinkling
 * stars, a meteor, and the planet's limb glowing along the bottom edge.
 */
export const SpaceBackdrop = memo(function SpaceBackdrop() {
  const { width, height } = useWindowDimensions();
  const layers = useMemo(
    () => [
      makeStars(70, width, height, 11),
      makeStars(38, width, height, 503),
      makeStars(26, width, height, 907),
    ],
    [width, height]
  );

  // The planet is a huge circle whose top just rises into view.
  const radius = width * 1.35;
  const planetY = height + radius - 118;

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Svg width={width} height={height}>
        <Defs>
          <LinearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor="#03050D" />
            <Stop offset="0.55" stopColor="#070B1F" />
            <Stop offset="1" stopColor="#150A1E" />
          </LinearGradient>
          <RadialGradient id="violet" cx="50%" cy="50%" r="50%">
            <Stop offset="0" stopColor="#7C3AED" stopOpacity="0.34" />
            <Stop offset="1" stopColor="#7C3AED" stopOpacity="0" />
          </RadialGradient>
          <RadialGradient id="teal" cx="50%" cy="50%" r="50%">
            <Stop offset="0" stopColor="#0EA5E9" stopOpacity="0.22" />
            <Stop offset="1" stopColor="#0EA5E9" stopOpacity="0" />
          </RadialGradient>
          <RadialGradient id="halo" cx="50%" cy="50%" r="50%">
            <Stop offset="0.9" stopColor="#FB923C" stopOpacity="0" />
            <Stop offset="0.965" stopColor="#FB923C" stopOpacity="0.5" />
            <Stop offset="1" stopColor="#FB923C" stopOpacity="0" />
          </RadialGradient>
          <RadialGradient id="mars" cx="50%" cy="0%" r="60%">
            <Stop offset="0" stopColor="#9A3412" />
            <Stop offset="0.5" stopColor="#5B1D0B" />
            <Stop offset="1" stopColor="#1C0A07" />
          </RadialGradient>
        </Defs>
        <Rect width={width} height={height} fill="url(#sky)" />
        <Ellipse
          cx={width * 0.92}
          cy={height * 0.16}
          rx={width * 0.75}
          ry={height * 0.26}
          fill="url(#violet)"
        />
        <Ellipse
          cx={width * 0.02}
          cy={height * 0.52}
          rx={width * 0.7}
          ry={height * 0.24}
          fill="url(#teal)"
        />
        <Circle cx={width / 2} cy={planetY} r={radius + 44} fill="url(#halo)" />
        <Circle cx={width / 2} cy={planetY} r={radius} fill="url(#mars)" />
        <Circle
          cx={width / 2}
          cy={planetY}
          r={radius}
          fill="none"
          stroke="#FDBA74"
          strokeOpacity={0.75}
          strokeWidth={1.2}
        />
      </Svg>
      <Twinkle
        stars={layers[0]!}
        width={width}
        height={height}
        delay={0}
        duration={2600}
      />
      <Twinkle
        stars={layers[1]!}
        width={width}
        height={height}
        delay={700}
        duration={1900}
      />
      <Twinkle
        stars={layers[2]!}
        width={width}
        height={height}
        delay={1300}
        duration={3300}
      />
      <Meteor width={width} />
    </View>
  );
});

const styles = StyleSheet.create({
  meteor: {
    position: 'absolute',
    width: 86,
    height: 1.5,
    borderRadius: 1,
    backgroundColor: '#E0F2FE',
    shadowColor: '#7DD3FC',
    shadowOpacity: 0.9,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 0 },
  },
});
