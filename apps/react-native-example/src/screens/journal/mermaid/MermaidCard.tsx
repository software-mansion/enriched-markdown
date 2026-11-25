import type { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
} from 'react-native-reanimated';
import { diagramStyles, useEntrance } from '../diagrams/motion';
import { FONTS, INK_SOFT, accentFor } from '../theme';

// A Mermaid chart's card: its title, and which Mermaid diagram it was
// written as, so the page owns up to the source.
export function MermaidCard({
  diagram,
  title,
  children,
}: {
  diagram: string;
  title: string | null;
  children: ReactNode;
}) {
  const entrance = useEntrance();
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));
  const accent = accentFor('Mermaid');
  return (
    <Animated.View style={[diagramStyles.card, styles.card, style]}>
      <View style={styles.head}>
        <Text style={styles.title} numberOfLines={1}>
          {(title ?? '').toUpperCase()}
        </Text>
        <View style={[styles.chip, { borderColor: `${accent}66` }]}>
          <Text style={[styles.chipText, { color: accent }]}>
            {`mermaid · ${diagram}`}
          </Text>
        </View>
      </View>
      {children}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: 12,
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  title: {
    flex: 1,
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.2,
    color: INK_SOFT,
  },
  chip: {
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  chipText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 9.5,
  },
});
