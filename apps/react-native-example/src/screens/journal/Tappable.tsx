import type { ReactNode } from 'react';
import { Pressable, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

// Every card is a plain React component, so it can take taps like any other.
export function Tappable({
  onPress,
  disabled,
  label,
  style,
  children,
}: {
  onPress: () => void;
  disabled?: boolean;
  label: string;
  style?: StyleProp<ViewStyle>;
  children: ReactNode;
}) {
  const pressed = useSharedValue(0);
  const pressStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 1 - pressed.value * 0.03 }],
  }));
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      onPressIn={() => {
        pressed.value = withTiming(1, { duration: 90 });
      }}
      onPressOut={() => {
        pressed.value = withTiming(0, { duration: 200 });
      }}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      style={style}
    >
      <Animated.View style={pressStyle}>{children}</Animated.View>
    </Pressable>
  );
}
