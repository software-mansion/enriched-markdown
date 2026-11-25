import { memo, useCallback, useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  useAnimatedStyle,
  useDerivedValue,
  useFrameCallback,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import { isBlack, noteName, pitchClass } from './theory';
import { BRASS, FONTS, glow as glowShadow } from './theme';

// When each key last sounded, `Date.now()` per MIDI note. A note booked ahead
// of time lights its key when it is heard, not when it was booked.
export type Hits = SharedValue<number[]>;

export function useHits() {
  const hits = useSharedValue<number[]>(new Array(128).fill(0));
  const flash = useCallback(
    (midi: number, at: number = Date.now()) => {
      hits.modify((value) => {
        'worklet';
        value[midi] = at;
        return value;
      });
    },
    [hits]
  );
  return { hits, flash };
}

const BLACK_WIDTH = 0.62;
const BLACK_HEIGHT = 0.6;
const GLOW_MS = 420;

export interface KeyboardProps {
  low: number;
  high: number;
  hits: Hits;
  // Keys held down by something other than a strike, 0 to 1 per MIDI note.
  held?: SharedValue<number[]>;
  // Pitch classes to ring, as a 12-bit mask: the chord tones of the moment.
  targets?: SharedValue<number>;
  marks?: Record<number, string>;
  labels?: boolean | Record<number, string>;
  enabled?: (midi: number) => boolean;
  onKey?: (midi: number) => void;
  height?: number;
  glow?: string;
}

interface KeyRect {
  midi: number;
  x: number;
  width: number;
  black: boolean;
}

function layoutKeys(low: number, high: number, width: number) {
  const whites: KeyRect[] = [];
  const blacks: KeyRect[] = [];
  let count = 0;
  for (let m = low; m <= high; m++) if (!isBlack(m)) count++;
  const white = width / Math.max(count, 1);
  let i = 0;
  for (let m = low; m <= high; m++) {
    if (isBlack(m)) {
      const w = white * BLACK_WIDTH;
      blacks.push({ midi: m, x: i * white - w / 2, width: w, black: true });
    } else {
      whites.push({ midi: m, x: i * white, width: white, black: false });
      i++;
    }
  }
  return { whites, blacks };
}

/**
 * A piano keyboard that lights where it sounds. Touch it to play; slide along
 * it for a glissando. Keys a lesson has turned off stay dim and silent.
 */
export const Keyboard = memo(function Keyboard({
  low,
  high,
  hits,
  held,
  targets,
  marks,
  labels,
  enabled,
  onKey,
  height = 120,
  glow = BRASS,
}: KeyboardProps) {
  const [width, setWidth] = useState(0);
  const now = useSharedValue(Date.now());
  const pressed = useSharedValue(-1);
  const last = useRef(-1);

  useFrameCallback(() => {
    now.value = Date.now();
  });

  const { whites, blacks } = useMemo(
    () => layoutKeys(low, high, width),
    [low, high, width]
  );

  const keyAt = useCallback(
    (x: number, y: number) => {
      if (y < height * BLACK_HEIGHT) {
        const black = blacks.find((k) => x >= k.x && x < k.x + k.width);
        if (black) return black.midi;
      }
      return whites.find((k) => x >= k.x && x < k.x + k.width)?.midi ?? -1;
    },
    [whites, blacks, height]
  );

  const touch = useCallback(
    (x: number, y: number) => {
      const midi = keyAt(x, y);
      if (midi === last.current) return;
      last.current = midi;
      pressed.value = midi;
      if (midi < 0 || (enabled && !enabled(midi))) return;
      onKey?.(midi);
    },
    [keyAt, enabled, onKey, pressed]
  );

  const gesture = useMemo(
    () =>
      Gesture.Pan()
        .runOnJS(true)
        .activeOffsetX([-6, 6])
        // A vertical drag is the page scrolling, not a glissando.
        .failOffsetY([-10, 10])
        .onBegin((e) => touch(e.x, e.y))
        .onUpdate((e) => touch(e.x, e.y))
        .onFinalize(() => {
          last.current = -1;
          pressed.value = -1;
        }),
    [touch, pressed]
  );

  const onLayout = (event: LayoutChangeEvent) =>
    setWidth(event.nativeEvent.layout.width);

  const keyProps = {
    hits,
    held,
    targets,
    now,
    pressed,
    height,
    glow,
  };

  return (
    <View style={styles.case}>
      <View style={styles.felt} />
      <GestureDetector gesture={gesture}>
        <View style={[styles.keys, { height }]} onLayout={onLayout}>
          {width > 0 &&
            [...whites, ...blacks].map((key) => (
              <Key
                key={key.midi}
                rect={key}
                mark={marks?.[key.midi]}
                label={
                  labels === true
                    ? pitchClass(key.midi) === 0
                      ? noteName(key.midi, true)
                      : undefined
                    : labels
                      ? labels[key.midi]
                      : undefined
                }
                off={enabled ? !enabled(key.midi) : false}
                {...keyProps}
              />
            ))}
        </View>
      </GestureDetector>
    </View>
  );
});

interface KeyProps {
  rect: KeyRect;
  hits: Hits;
  held?: SharedValue<number[]>;
  targets?: SharedValue<number>;
  now: SharedValue<number>;
  pressed: SharedValue<number>;
  height: number;
  glow: string;
  mark?: string;
  label?: string;
  off: boolean;
}

const Key = memo(function Key({
  rect,
  hits,
  held,
  targets,
  now,
  pressed,
  height,
  glow: light,
  mark,
  label,
  off,
}: KeyProps) {
  const { midi, black } = rect;

  const level = useDerivedValue(() => {
    const age = now.value - hits.value[midi]!;
    const struck = age >= 0 && age < 3000 ? Math.exp(-age / GLOW_MS) : 0;
    return Math.max(
      struck,
      held?.value[midi] ?? 0,
      pressed.value === midi ? 0.7 : 0
    );
  });

  // A struck key sinks a little and lights from beneath.
  const sink = useAnimatedStyle(() => ({
    transform: [{ translateY: level.value * 2 }],
  }));
  const lit = useAnimatedStyle(() => ({ opacity: level.value }));
  const target = useAnimatedStyle(() => ({
    opacity: targets ? (targets.value >> (midi % 12)) & 1 : 0,
  }));

  return (
    <Animated.View
      style={[
        black ? styles.black : styles.white,
        {
          left: rect.x,
          width: rect.width,
          height: black ? height * BLACK_HEIGHT : height,
        },
        sink,
      ]}
    >
      <Animated.View
        pointerEvents="none"
        style={[
          styles.fill,
          black ? styles.blackLight : styles.whiteLight,
          {
            backgroundImage: `linear-gradient(180deg, ${light}00 0%, ${light}${black ? 'EE' : 'D0'} 100%)`,
          },
          lit,
        ]}
      />
      {off && (
        <View
          pointerEvents="none"
          style={[styles.fill, black ? styles.blackOff : styles.whiteOff]}
        />
      )}
      {targets && !off && (
        <Animated.View
          pointerEvents="none"
          style={[
            black ? styles.blackTarget : styles.whiteTarget,
            { backgroundColor: light, boxShadow: glowShadow(light, 10) },
            target,
          ]}
        />
      )}
      {mark && (
        <View
          style={[
            styles.mark,
            { backgroundColor: mark, boxShadow: glowShadow(mark, 6) },
          ]}
        />
      )}
      {label && (
        <Text
          style={[
            styles.label,
            black && styles.blackLabel,
            off && styles.offLabel,
          ]}
          numberOfLines={1}
        >
          {label}
        </Text>
      )}
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  case: {
    backgroundImage: 'linear-gradient(180deg, #1D1D24 0%, #060609 100%)',
    boxShadow:
      'inset 0 1px 0 rgba(255,255,255,0.09), 0 12px 22px -10px rgba(0,0,0,0.9)',
    borderRadius: 14,
    paddingHorizontal: 6,
    paddingBottom: 9,
  },
  // The strip of red felt the keys rest against.
  felt: {
    height: 5,
    marginHorizontal: -6,
    marginBottom: 1,
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
    backgroundImage: 'linear-gradient(180deg, #2A0B10 0%, #8E2333 100%)',
  },
  keys: {
    width: '100%',
    position: 'relative',
  },
  white: {
    position: 'absolute',
    top: 0,
    marginHorizontal: 0.75,
    backgroundImage:
      'linear-gradient(180deg, #E7DFCC 0%, #FFFCF4 12%, #F4ECDB 82%, #E3D8C1 100%)',
    boxShadow: 'inset 0 -6px 0 #D4C8AE, 0 2px 2px rgba(0,0,0,0.5)',
    borderBottomLeftRadius: 6,
    borderBottomRightRadius: 6,
    alignItems: 'center',
    justifyContent: 'flex-end',
    paddingBottom: 11,
    gap: 5,
    overflow: 'hidden',
  },
  black: {
    position: 'absolute',
    top: 0,
    zIndex: 2,
    backgroundImage:
      'linear-gradient(180deg, #050507 0%, #24242C 70%, #3A3A44 88%, #101014 100%)',
    boxShadow:
      'inset 1px 0 0 rgba(255,255,255,0.08), 0 4px 5px rgba(0,0,0,0.7)',
    borderBottomLeftRadius: 4,
    borderBottomRightRadius: 4,
    alignItems: 'center',
    justifyContent: 'flex-end',
    paddingBottom: 12,
    gap: 4,
    overflow: 'hidden',
  },
  fill: {
    ...StyleSheet.absoluteFill,
  },
  whiteLight: {
    borderBottomLeftRadius: 6,
    borderBottomRightRadius: 6,
  },
  blackLight: {
    borderBottomLeftRadius: 4,
    borderBottomRightRadius: 4,
  },
  whiteOff: {
    backgroundColor: 'rgba(9,11,20,0.62)',
  },
  blackOff: {
    backgroundColor: 'rgba(0,0,0,0.45)',
  },
  // Lights under the keys that fit the bar being played.
  whiteTarget: {
    position: 'absolute',
    bottom: 4,
    left: '22%',
    right: '22%',
    height: 3,
    borderRadius: 2,
  },
  blackTarget: {
    position: 'absolute',
    bottom: 4,
    left: '25%',
    right: '25%',
    height: 2.5,
    borderRadius: 2,
  },
  mark: {
    width: 7,
    height: 7,
    borderRadius: 4,
  },
  label: {
    fontFamily: FONTS.monoMedium,
    fontSize: 9.5,
    color: '#8F826A',
  },
  blackLabel: {
    color: '#9AA0BE',
    fontSize: 8,
  },
  offLabel: {
    opacity: 0.35,
  },
});
