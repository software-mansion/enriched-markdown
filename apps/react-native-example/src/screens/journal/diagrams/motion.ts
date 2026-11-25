import { useEffect } from 'react';
import { useInstant } from '../source/face';
import { StyleSheet } from 'react-native';
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
  const instant = useInstant();
  const progress = useSharedValue(instant.current ? 1 : 0);
  useEffect(() => {
    if (instant.current) {
      progress.value = 1;
      return;
    }
    progress.value = withDelay(
      PLACEMENT_DELAY + delay,
      withTiming(1, { duration, easing: SETTLE })
    );
  }, [progress, duration, delay, instant]);
  return progress;
}

export function codeLines(code: string) {
  return code.split('\n').filter((line) => line.trim() !== '');
}

export const diagramStyles = StyleSheet.create({
  card: {
    backgroundColor: '#FBF6EC',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#E3D6BF',
    padding: 16,
    marginVertical: 4,
  },
});
