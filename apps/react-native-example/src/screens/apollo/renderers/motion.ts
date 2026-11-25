import { useEffect } from 'react';
import {
  Easing,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';

// A slot mounts a few frames before the host places it on screen, so every
// entrance waits that out instead of spending its first frames off screen.
const PLACEMENT_DELAY = 100;

export const SETTLE = Easing.out(Easing.cubic);

export function useEntrance(duration = 700, delay = 0) {
  const progress = useSharedValue(0);
  useEffect(() => {
    progress.value = withDelay(
      PLACEMENT_DELAY + delay,
      withTiming(1, { duration, easing: SETTLE })
    );
  }, [progress, duration, delay]);
  return progress;
}

// The journal streams code a whole line at a time, so every line is complete.
export function codeLines(code: string) {
  return code.split('\n').filter((line) => line.trim() !== '');
}
