import { useEffect, useState } from 'react';
import { StyleSheet, View, type LayoutChangeEvent } from 'react-native';
import Animated, {
  makeMutable,
  useAnimatedProps,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import { engine } from './audio';
import { BRASS } from './theme';

const POINTS = 96;
const POLL_MS = 33;

// What the speaker is playing, sampled ~30 times a second for the UI thread:
// the waveform as POINTS values from -1 to 1, and its loudness, 0 to 1.
export const waveform = makeMutable<number[]>(new Array(POINTS).fill(0));
export const loudness = makeMutable(0);

let listeners = 0;
let timer: ReturnType<typeof setInterval> | null = null;
const buffer = new Float32Array(1024);

function poll() {
  if (!engine.readWaveform(buffer)) return;
  // Starts the window on a rising zero crossing, so a held note stands still
  // instead of crawling across the screen.
  let start = 0;
  for (let i = 1; i < buffer.length / 2; i++) {
    if (buffer[i - 1]! < 0 && buffer[i]! >= 0) {
      start = i;
      break;
    }
  }
  const span = buffer.length / 2;
  const next = new Array<number>(POINTS);
  let energy = 0;
  for (let i = 0; i < POINTS; i++) {
    const v = buffer[start + Math.floor((i / POINTS) * span)] ?? 0;
    next[i] = v;
    energy += v * v;
  }
  waveform.value = next;
  const rms = Math.sqrt(energy / POINTS);
  // Rises at once, falls slowly, like a VU needle.
  loudness.value = Math.max(Math.min(1, rms * 5), loudness.value * 0.85);
}

/** Keeps the scope feed running while the calling component is mounted. */
export function useScopeFeed() {
  useEffect(() => {
    listeners++;
    if (!timer) timer = setInterval(poll, POLL_MS);
    return () => {
      listeners--;
      if (listeners === 0 && timer) {
        clearInterval(timer);
        timer = null;
      }
    };
  }, []);
}

const AnimatedPath = Animated.createAnimatedComponent(Path);

function useTrace(
  data: SharedValue<number[]>,
  width: number,
  height: number,
  gain: number
) {
  return useAnimatedProps(() => {
    const values = data.value;
    const mid = height / 2;
    let d = '';
    for (let i = 0; i < values.length; i++) {
      const x = (i / (values.length - 1)) * width;
      // Tapers to the edges, so the trace fades in and out of the frame.
      const edge = Math.sin((i / (values.length - 1)) * Math.PI);
      const y = mid - Math.max(-1, Math.min(1, values[i]! * gain)) * mid * edge;
      d += `${i === 0 ? 'M' : 'L'}${x.toFixed(1)} ${y.toFixed(1)}`;
    }
    return { d };
  });
}

/**
 * A phosphor oscilloscope of what the lesson is playing right now: every
 * key, chord, drum and bass note passes through it.
 */
export function Scope({
  height = 44,
  color = BRASS,
  gain = 3.2,
}: {
  height?: number;
  color?: string;
  gain?: number;
}) {
  const [width, setWidth] = useState(0);
  useScopeFeed();
  // One set of animated props per path: Reanimated binds each to one view.
  const halo = useTrace(waveform, width, height, gain);
  const trace = useTrace(waveform, width, height, gain);

  return (
    <View
      style={[styles.scope, { height }]}
      onLayout={(e: LayoutChangeEvent) => setWidth(e.nativeEvent.layout.width)}
      pointerEvents="none"
    >
      {width > 0 && (
        <Svg width={width} height={height}>
          <AnimatedPath
            animatedProps={halo}
            stroke={color}
            strokeOpacity={0.25}
            strokeWidth={6}
            fill="none"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
          <AnimatedPath
            animatedProps={trace}
            stroke={color}
            strokeWidth={1.6}
            fill="none"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        </Svg>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  scope: {
    width: '100%',
  },
});
