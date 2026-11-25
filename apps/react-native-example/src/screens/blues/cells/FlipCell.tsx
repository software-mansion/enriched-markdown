import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  interpolate,
  interpolateColor,
  useAnimatedStyle,
  useSharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { engine, type Held } from '../audio';
import { Keyboard, useHits } from '../Keyboard';
import { noteName, parseNote } from '../theory';
import { BLUE, BRASS, FONTS } from '../theme';
import { Card, splitCode, useOnClose } from './Card';

const THUMB = 30;
const TICKS = 13;
const STARS = [
  [0.12, 0.18, 1.5],
  [0.3, 0.1, 1],
  [0.46, 0.24, 1.5],
  [0.58, 0.08, 1],
  [0.7, 0.3, 1],
  [0.22, 0.34, 1],
  [0.92, 0.42, 1.5],
] as const;
const DEMO_MS = 3600;

// `hold C4 E4 G4` and `move E4 -> Eb4`: the chord, and the note that slides.
function parseFlip(lines: string[]) {
  let hold: number[] = [];
  let from: number | null = null;
  let to: number | null = null;
  for (const line of lines) {
    const h = /^\s*hold\s+(.*)$/.exec(line);
    if (h) {
      hold = h[1]!
        .split(/\s+/)
        .map(parseNote)
        .filter((m): m is number => m !== null);
    }
    const m = /^\s*move\s+(\S+)\s*->\s*(\S+)\s*$/.exec(line);
    if (m) {
      from = parseNote(m[1]!);
      to = parseNote(m[2]!);
    }
  }
  return { hold, from, to };
}

/**
 * A ```flip block: one chord, held, with one note on a slider. Drag it and the
 * note glides, continuously, from major to minor; the card goes from lamp
 * light to midnight with it. Nothing else changes, and everything does.
 */
export function FlipCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const { hold, from, to } = parseFlip(block.isComplete ? body : []);
  const ready = hold.length > 0 && from !== null && to !== null;
  const voice = ready ? hold.indexOf(from!) : -1;

  const { hits } = useHits();
  const amount = useSharedValue(0);
  const held = useSharedValue<number[]>(new Array(128).fill(0));
  const chord = useRef<Held | null>(null);
  const [width, setWidth] = useState(0);
  const demo = useRef<ReturnType<typeof setInterval> | null>(null);

  const setLevels = useCallback(
    (v: number, on: boolean) => {
      if (!ready) return;
      const levels = new Array(128).fill(0);
      if (on) {
        for (const m of hold) levels[m] = m === from ? 1 - v : 1;
        levels[to!] = v;
      }
      held.value = levels;
    },
    [ready, hold, from, to, held]
  );

  const start = useCallback(() => {
    if (!ready || chord.current) return;
    chord.current = engine.hold(hold);
    chord.current.setPitch(voice, from! + (to! - from!) * amount.value);
    setLevels(amount.value, true);
  }, [ready, hold, voice, from, to, amount, setLevels]);

  const slide = useCallback(
    (v: number) => {
      amount.value = v;
      chord.current?.setPitch(voice, from! + (to! - from!) * v);
      setLevels(v, chord.current !== null);
    },
    [amount, voice, from, to, setLevels]
  );

  const release = useCallback(() => {
    chord.current?.release();
    chord.current = null;
    setLevels(amount.value, false);
  }, [amount, setLevels]);

  const stopDemo = () => {
    if (demo.current) clearInterval(demo.current);
    demo.current = null;
  };

  // The first time through, the answer plays it for you: major, slide down to
  // minor, hold, and back up.
  useOnClose(block, () => {
    setTimeout(() => {
      if (!ready) return;
      amount.value = 0;
      start();
      const began = Date.now();
      demo.current = setInterval(() => {
        const t = (Date.now() - began) / DEMO_MS;
        if (t >= 1) {
          stopDemo();
          slide(0);
          release();
          return;
        }
        const ease = (x: number) => x * x * (3 - 2 * x);
        const v =
          t < 0.2
            ? 0
            : t < 0.4
              ? ease((t - 0.2) / 0.2)
              : t < 0.7
                ? 1
                : t < 0.85
                  ? 1 - ease((t - 0.7) / 0.15)
                  : 0;
        slide(v);
      }, 16);
    }, 400);
  });

  useEffect(
    () => () => {
      stopDemo();
      chord.current?.release();
    },
    []
  );

  const track = width - THUMB;
  const gesture = useMemo(
    () =>
      Gesture.Pan()
        .runOnJS(true)
        .activeOffsetX([-6, 6])
        // A vertical drag is the page scrolling, not the fader.
        .failOffsetY([-10, 10])
        .onBegin((e) => {
          stopDemo();
          start();
          slide(Math.min(1, Math.max(0, (e.x - THUMB / 2) / track)));
        })
        .onUpdate((e) =>
          slide(Math.min(1, Math.max(0, (e.x - THUMB / 2) / track)))
        )
        .onFinalize(release),
    [start, slide, release, track]
  );

  const night = useAnimatedStyle(() => ({ opacity: amount.value }));
  const sun = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(amount.value, [0, 1], [BRASS, '#DCE6FF']),
    boxShadow: `0 0 ${28 - amount.value * 14}px ${amount.value > 0.5 ? '#9DB8FF99' : '#FFB547CC'}`,
  }));
  // The night's edge slides over the sun until only a crescent is left.
  const shade = useAnimatedStyle(() => ({
    transform: [{ translateX: interpolate(amount.value, [0, 1], [64, 12]) }],
    opacity: interpolate(amount.value, [0, 0.05, 0.2], [0, 0, 1]),
  }));
  const thumb = useAnimatedStyle(() => ({
    transform: [{ translateX: amount.value * track }],
    boxShadow: `0 0 16px ${amount.value > 0.5 ? BLUE : BRASS}AA, 0 4px 8px rgba(0,0,0,0.6)`,
  }));
  const fill = useAnimatedStyle(() => ({
    width: amount.value * track + THUMB / 2,
    backgroundColor: interpolateColor(amount.value, [0, 1], [BRASS, BLUE]),
  }));
  const majorLabel = useAnimatedStyle(() => ({
    opacity: interpolate(amount.value, [0, 1], [1, 0.25]),
    transform: [{ scale: interpolate(amount.value, [0, 1], [1, 0.92]) }],
  }));
  const minorLabel = useAnimatedStyle(() => ({
    opacity: interpolate(amount.value, [0, 1], [0.25, 1]),
    transform: [{ scale: interpolate(amount.value, [0, 1], [0.92, 1]) }],
  }));

  const labels = useMemo(() => {
    const out: Record<number, string> = {};
    for (const m of hold) out[m] = noteName(m);
    if (to !== null) out[to] = noteName(to);
    return out;
  }, [hold.join(','), to]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <Card tag="MAJOR → MINOR" caption={caption} accent={BLUE}>
      <View style={styles.stage}>
        <View style={[styles.sky, styles.day]} />
        <Animated.View style={[styles.sky, styles.night, night]}>
          {STARS.map(([x, y, r], i) => (
            <View
              key={i}
              style={[
                styles.star,
                {
                  left: `${x * 100}%`,
                  top: `${y * 100}%`,
                  width: r * 2,
                  height: r * 2,
                },
              ]}
            />
          ))}
        </Animated.View>
        <View style={styles.top}>
          <View style={styles.moods}>
            <Animated.Text style={[styles.mood, majorLabel]}>
              Major
            </Animated.Text>
            <Animated.Text style={[styles.mood, styles.minor, minorLabel]}>
              minor
            </Animated.Text>
          </View>
          <View style={styles.orbit}>
            <Animated.View style={[styles.sun, sun]} />
            <Animated.View style={[styles.shade, shade]} />
          </View>
        </View>
        <Keyboard
          low={60}
          high={72}
          hits={hits}
          held={held}
          labels={labels}
          height={92}
          glow={BRASS}
        />
        <GestureDetector gesture={gesture}>
          <View
            style={styles.track}
            onLayout={(e: LayoutChangeEvent) =>
              setWidth(e.nativeEvent.layout.width)
            }
            testID="flip-slider"
          >
            <View style={styles.ticks}>
              {Array.from({ length: TICKS }, (_, i) => (
                <View
                  key={i}
                  style={[styles.tick, i % 6 === 0 && styles.tickMajor]}
                />
              ))}
            </View>
            <View style={styles.rail}>
              <Animated.View style={[styles.railFill, fill]} />
            </View>
            <Animated.View style={[styles.thumb, thumb]}>
              <View style={styles.grip} />
              <View style={styles.grip} />
              <View style={styles.grip} />
            </Animated.View>
          </View>
        </GestureDetector>
        <Text style={styles.hint}>
          {ready
            ? `hold the fader and slide · ${noteName(from!)} → ${noteName(to!)}`
            : 'tuning up…'}
        </Text>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  stage: {
    borderRadius: 18,
    padding: 14,
    gap: 14,
    overflow: 'hidden',
  },
  sky: {
    ...StyleSheet.absoluteFill,
  },
  day: {
    backgroundImage:
      'radial-gradient(circle at 85% 0%, #FFB54755 0%, #FFB54700 55%), linear-gradient(180deg, #3D2611 0%, #1B1320 100%)',
  },
  night: {
    backgroundImage:
      'radial-gradient(circle at 85% 0%, #5C8BFF44 0%, #5C8BFF00 55%), linear-gradient(180deg, #0C1838 0%, #060917 100%)',
  },
  star: {
    position: 'absolute',
    borderRadius: 2,
    backgroundColor: '#DCE6FF',
    boxShadow: '0 0 4px #DCE6FF',
  },
  top: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  moods: {
    gap: 0,
  },
  mood: {
    fontFamily: FONTS.display,
    fontSize: 30,
    lineHeight: 34,
    color: '#FFD08A',
  },
  minor: {
    color: '#A9C0FF',
  },
  orbit: {
    width: 52,
    height: 52,
    overflow: 'hidden',
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sun: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  shade: {
    position: 'absolute',
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#0C1838',
  },
  track: {
    height: THUMB + 22,
    justifyContent: 'center',
  },
  ticks: {
    position: 'absolute',
    top: 0,
    left: THUMB / 2,
    right: THUMB / 2,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  tick: {
    width: 1,
    height: 5,
    backgroundColor: '#ffffff33',
  },
  tickMajor: {
    height: 9,
    backgroundColor: '#ffffff77',
  },
  rail: {
    height: 6,
    borderRadius: 3,
    backgroundColor: '#00000066',
    boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.8)',
    marginTop: 8,
    overflow: 'hidden',
  },
  railFill: {
    height: 6,
    borderRadius: 3,
  },
  thumb: {
    position: 'absolute',
    left: 0,
    top: 14,
    width: THUMB,
    height: THUMB + 4,
    borderRadius: 7,
    backgroundImage: 'linear-gradient(180deg, #F2EEE6 0%, #B9B3A8 100%)',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
  },
  grip: {
    width: 14,
    height: 1.5,
    backgroundColor: '#00000055',
  },
  hint: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: '#C9CEE6AA',
    textAlign: 'center',
  },
});
