import { useEffect, type ReactNode } from 'react';
import { Modal, Pressable, StyleSheet, Text } from 'react-native';
import Animated, {
  Easing,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { FONTS } from './theme';

export const LIGHTBOX_MARGIN = 18;

const OVERSHOOT = Easing.out(Easing.back(1.6));

// A card lifted off the page over the dimmed journal; a tap puts it back.
export function Lightbox({
  open,
  onClose,
  label,
  children,
}: {
  open: boolean;
  onClose: () => void;
  label: string;
  children: ReactNode;
}) {
  return (
    <Modal
      visible={open}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={onClose}
    >
      <Pressable
        style={styles.lightbox}
        onPress={onClose}
        accessibilityLabel={label}
      >
        {open && <Lifted>{children}</Lifted>}
      </Pressable>
    </Modal>
  );
}

function Lifted({ children }: { children: ReactNode }) {
  const lift = useSharedValue(0);
  useEffect(() => {
    lift.value = withTiming(1, { duration: 420, easing: OVERSHOOT });
  }, [lift]);
  const liftStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: interpolate(lift.value, [0, 1], [0.86, 1]) },
      { rotate: `${interpolate(lift.value, [0, 1], [-4, 0])}deg` },
    ],
  }));
  return (
    <>
      <Animated.View style={liftStyle}>{children}</Animated.View>
      <Text style={styles.hint}>tap to put it back</Text>
    </>
  );
}

const styles = StyleSheet.create({
  lightbox: {
    flex: 1,
    backgroundColor: 'rgba(23, 18, 15, 0.9)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: LIGHTBOX_MARGIN,
  },
  hint: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    letterSpacing: 1,
    color: '#C9B9A4',
    marginTop: 18,
  },
});
