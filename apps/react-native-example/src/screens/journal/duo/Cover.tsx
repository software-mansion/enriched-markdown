import { memo, useEffect } from 'react';
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
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Path, Text as SvgText } from 'react-native-svg';
import { DotGrid } from '../JournalScreen';
import { FONTS, INK, INK_SOFT, PAPER, VERMILION } from '../theme';

const SPINE = 16;

// Kiyomizu-dera, November 2016: Martin Falbisoner, CC BY-SA 4.0, Wikimedia
// Commons.
const PAGODA = require('../../../assets/kyoto/kiyomizu-pagoda.jpg');

// The folded Duo is the notebook's cover: a polaroid of Kiyomizu-dera's
// pagoda in the maples, and maples coming down over it. Open the phone, like
// the notebook, to read; a tap on the photo reads it folded.
export function Cover({ onRead }: { onRead: () => void }) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();

  return (
    <View
      style={[
        styles.root,
        { paddingTop: insets.top + 28, paddingBottom: insets.bottom + 20 },
      ]}
    >
      <DotGrid />
      <Spine height={height} />

      <View style={styles.titleRow}>
        <View style={styles.titles}>
          <Text style={styles.kicker}>TRAVEL JOURNAL · AUTUMN</Text>
          <Text style={styles.title}>Kyoto</Text>
          <Text style={styles.subtitle}>Three slow days</Text>
          <Text style={styles.tagline}>trains · temples · bamboo</Text>
        </View>
        <Text style={styles.kanji}>{'京\n都'}</Text>
      </View>

      <View style={styles.photoArea}>
        <Pressable
          style={styles.polaroid}
          onPress={onRead}
          accessibilityRole="button"
          accessibilityLabel="Read it folded"
          testID="journal-read-folded"
        >
          <Photo />
          <Text style={styles.caption}>Kiyomizu-dera, in the maples</Text>
        </Pressable>
        <Hanko />
      </View>

      <Text style={styles.site}>KIYOMIZU-DERA · 34.995° N 135.785° E</Text>

      <Leaves width={width} height={height} />
    </View>
  );
}

// The photo drifts in, slow enough to pass for a held breath.
const DRIFT_MS = 14000;

function Photo() {
  const drift = useSharedValue(0);
  useEffect(() => {
    drift.value = withRepeat(
      withTiming(1, { duration: DRIFT_MS, easing: Easing.inOut(Easing.sin) }),
      -1,
      true
    );
  }, [drift]);
  const style = useAnimatedStyle(() => ({
    transform: [
      { scale: interpolate(drift.value, [0, 1], [1.04, 1.14]) },
      { translateY: interpolate(drift.value, [0, 1], [4, -8]) },
    ],
  }));
  return (
    <View style={styles.photo}>
      <Animated.Image
        source={PAGODA}
        resizeMode="cover"
        style={[styles.photoImage, style]}
      />
    </View>
  );
}

const THUMP = Easing.out(Easing.back(1.8));

// The hanko pressed onto the cover, standing in for the sticker on a sleeve.
function Hanko() {
  const pressed = useSharedValue(0);
  useEffect(() => {
    pressed.value = withDelay(
      500,
      withTiming(1, { duration: 460, easing: THUMP })
    );
  }, [pressed]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(pressed.value, [0, 0.4, 1], [0, 1, 0.94]),
    transform: [
      { scale: interpolate(pressed.value, [0, 1], [1.9, 1]) },
      { rotate: '8deg' },
    ],
  }));
  return (
    <Animated.View style={[styles.hanko, style]} pointerEvents="none">
      <Text style={styles.hankoKanji}>旅</Text>
      <Text style={styles.hankoBig}>4 DIAGRAMS</Text>
      <Text style={styles.hankoSmall}>3 CARDS INSIDE</Text>
    </Animated.View>
  );
}

const LEAF_COLORS = [VERMILION, '#D9822B', '#B8432F', '#E0A030'];

// The same leaves on every render, from a fixed seed.
function leaves(count: number) {
  let seed = 1018;
  const next = () => {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  };
  return Array.from({ length: count }, (_, i) => ({
    x: 0.08 + next() * 0.84,
    size: 14 + next() * 10,
    fall: 8000 + next() * 5000,
    delay: next() * 6000,
    sway: 18 + next() * 26,
    spin: (next() > 0.5 ? 1 : -1) * (180 + next() * 360),
    color: LEAF_COLORS[i % LEAF_COLORS.length]!,
  }));
}

const LEAVES = leaves(8);

function Leaves({ width, height }: { width: number; height: number }) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      {LEAVES.map((leaf, i) => (
        <Leaf key={i} leaf={leaf} width={width} height={height} />
      ))}
    </View>
  );
}

const Leaf = memo(function Leaf({
  leaf,
  width,
  height,
}: {
  leaf: (typeof LEAVES)[number];
  width: number;
  height: number;
}) {
  const fall = useSharedValue(0);
  useEffect(() => {
    fall.value = withDelay(
      leaf.delay,
      withRepeat(
        withTiming(1, { duration: leaf.fall, easing: Easing.linear }),
        -1
      )
    );
  }, [fall, leaf]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(fall.value, [0, 0.05, 0.92, 1], [0, 0.9, 0.9, 0]),
    transform: [
      {
        translateX:
          leaf.x * width + Math.sin(fall.value * Math.PI * 4) * leaf.sway,
      },
      { translateY: -40 + fall.value * (height + 80) },
      { rotate: `${fall.value * leaf.spin}deg` },
    ],
  }));
  return (
    <Animated.View style={[styles.leaf, style]}>
      <Svg width={leaf.size} height={leaf.size} viewBox="0 0 24 24">
        <Path
          d="M12 1 L14 7 L19 4 L17 10 L23 10 L18 14 L20 18 L14 16 L12.6 23 L11.4 23 L10 16 L4 18 L6 14 L1 10 L7 10 L5 4 L10 7 Z"
          fill={leaf.color}
        />
      </Svg>
    </Animated.View>
  );
});

// The spine along the hinge, lettered bottom to top like a shelf of notebooks.
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
          fill={INK_SOFT}
        >
          KYOTO JOURNAL · AUTUMN · THREE DAYS · TOKYO → KYOTO
        </SvgText>
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: PAPER,
    paddingLeft: SPINE + 24,
    paddingRight: 26,
    overflow: 'hidden',
  },
  spine: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: SPINE,
    backgroundColor: '#E6D8C1',
    borderRightWidth: StyleSheet.hairlineWidth,
    borderRightColor: '#CDBEA4',
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  titles: {
    flex: 1,
  },
  kicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 2,
    color: INK_SOFT,
  },
  title: {
    fontFamily: FONTS.display,
    fontSize: 92,
    lineHeight: 100,
    color: INK,
    marginTop: 2,
  },
  subtitle: {
    fontFamily: FONTS.bodyItalic,
    fontStyle: 'italic',
    fontSize: 30,
    lineHeight: 36,
    color: INK,
    marginTop: -6,
  },
  tagline: {
    fontFamily: FONTS.hand,
    fontSize: 24,
    color: INK_SOFT,
    marginTop: 2,
  },
  kanji: {
    fontFamily: FONTS.mincho,
    fontSize: 40,
    lineHeight: 48,
    fontWeight: '700',
    color: VERMILION,
    // Clear of the cover panel's camera.
    marginTop: 64,
  },
  photoArea: {
    flex: 1,
    justifyContent: 'center',
    paddingVertical: 18,
  },
  polaroid: {
    flex: 1,
    maxHeight: 460,
    backgroundColor: '#FFFDF8',
    padding: 10,
    paddingBottom: 4,
    borderRadius: 2,
    transform: [{ rotate: '-2.5deg' }],
    shadowColor: '#3B2A1A',
    shadowOpacity: 0.25,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
  },
  photo: {
    flex: 1,
    overflow: 'hidden',
    backgroundColor: '#3A2A20',
  },
  photoImage: {
    width: '100%',
    height: '100%',
  },
  caption: {
    fontFamily: FONTS.hand,
    fontSize: 25,
    color: INK,
    marginTop: 4,
    marginLeft: 4,
  },
  hanko: {
    position: 'absolute',
    right: -8,
    top: 4,
    width: 100,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: VERMILION,
    alignItems: 'center',
    shadowColor: '#7A2414',
    shadowOpacity: 0.3,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 3 },
  },
  hankoKanji: {
    fontFamily: FONTS.mincho,
    fontSize: 34,
    lineHeight: 40,
    fontWeight: '700',
    color: PAPER,
  },
  hankoBig: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1,
    color: PAPER,
  },
  hankoSmall: {
    fontFamily: FONTS.mono,
    fontSize: 8,
    letterSpacing: 1,
    color: '#F6D9CF',
    marginTop: 2,
  },
  leaf: {
    position: 'absolute',
    left: 0,
    top: 0,
  },
  site: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 1.2,
    color: INK_SOFT,
  },
});
