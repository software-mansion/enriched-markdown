import { useEffect, useState, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { journalRenderers } from '../renderers';
import { FONTS, INK, PAPER, VERMILION } from '../theme';
import { SourceProvider, switchable } from './Source';

// The journal's renderers, each able to show the markdown it came from.
export const sourceRenderers = switchable(journalRenderers);

// A page that can switch every block between the component it renders as and
// the markdown it is written in, from a switch at the bottom of the screen.
export function SourceSwitch({ children }: { children: ReactNode }) {
  const insets = useSafeAreaInsets();
  const [components, setComponents] = useState(true);
  return (
    <SourceProvider components={components}>
      <View style={styles.root}>
        {children}
        <View
          style={[styles.toggleRow, { bottom: insets.bottom + 18 }]}
          pointerEvents="box-none"
        >
          <Toggle components={components} onChange={setComponents} />
        </View>
      </View>
    </SourceProvider>
  );
}

const SIDE_WIDTH = 108;

function Toggle({
  components,
  onChange,
}: {
  components: boolean;
  onChange: (components: boolean) => void;
}) {
  const side = useSharedValue(components ? 1 : 0);
  useEffect(() => {
    side.value = withTiming(components ? 1 : 0, {
      duration: 240,
      easing: Easing.out(Easing.cubic),
    });
  }, [side, components]);
  const thumbStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: side.value * SIDE_WIDTH }],
  }));
  return (
    <View style={styles.toggle}>
      <Animated.View style={[styles.thumb, thumbStyle]} />
      {(['markdown', 'components'] as const).map((label) => {
        const active = (label === 'components') === components;
        return (
          <Pressable
            key={label}
            onPress={() => onChange(label === 'components')}
            accessibilityRole="button"
            accessibilityState={{ selected: active }}
            testID={`journal-source-${label}`}
            style={styles.side}
          >
            <Text style={[styles.sideText, active && styles.sideTextActive]}>
              {label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  toggleRow: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  toggle: {
    flexDirection: 'row',
    padding: 4,
    borderRadius: 22,
    backgroundColor: INK,
    shadowColor: '#000',
    shadowOpacity: 0.22,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
  },
  thumb: {
    position: 'absolute',
    top: 4,
    left: 4,
    width: SIDE_WIDTH,
    bottom: 4,
    borderRadius: 18,
    backgroundColor: VERMILION,
  },
  side: {
    width: SIDE_WIDTH,
    paddingVertical: 9,
    alignItems: 'center',
  },
  sideText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    letterSpacing: 0.6,
    color: '#B9A98F',
  },
  sideTextActive: {
    color: PAPER,
  },
});
