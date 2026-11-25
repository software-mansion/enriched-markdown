import { useEffect, useState } from 'react';
import {
  useSharedValue,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import NativeHinge, { type HingeUpdate } from '../../../specs/NativeHinge';

const CLOSED = 1;
const FULLY_OPEN = 3;

const NO_HINGE: HingeUpdate = { available: false, angle: 0, status: 0 };

export interface Hinge {
  // False until the module has reported, so no layout mounts only to swap.
  known: boolean;
  available: boolean;
  closed: boolean;
  // 0 folded to 1 flat, eased on the UI thread between hinge updates.
  open: SharedValue<number>;
}

// The iPhone Duo's hinge, or `available: false` on every other phone.
export function useHinge(): Hinge {
  const [update, setUpdate] = useState<HingeUpdate | null>(
    NativeHinge ? null : NO_HINGE
  );
  const open = useSharedValue(0);

  useEffect(() => {
    if (!NativeHinge) return;
    const subscription = NativeHinge.onChange(setUpdate);
    NativeHinge.start();
    return () => {
      subscription.remove();
      NativeHinge?.stop();
    };
  }, []);

  useEffect(() => {
    if (!update) return;
    const flat =
      update.status === FULLY_OPEN
        ? 1
        : update.status === CLOSED
          ? 0
          : Math.min(1, Math.max(0, update.angle / Math.PI));
    open.value = withTiming(flat, { duration: 260 });
  }, [update, open]);

  return {
    known: update !== null,
    available: update?.available ?? false,
    closed: update?.status === CLOSED,
    open,
  };
}
