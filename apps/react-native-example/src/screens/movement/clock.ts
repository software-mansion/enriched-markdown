import { makeMutable, useFrameCallback } from 'react-native-reanimated';

// One clock for every instrument on every screen. A shared element transition
// hands the flight from the source view to its twin on the other side, so both
// have to show the same instant: they read this value, never a timer of their
// own. It starts on a whole minute, so `clock % 60` is the real second.
const START = Math.floor(Date.now() / 60000) * 60000;

export const clock = makeMutable((Date.now() - START) / 1000);

export function useRunClock() {
  useFrameCallback(() => {
    clock.value = (Date.now() - START) / 1000;
  });
}

// The escapement and the balance are drawn at a quarter of the real
// 18,000 beats an hour, slow enough to follow.
export const BEATS_PER_SECOND = 1.25;
