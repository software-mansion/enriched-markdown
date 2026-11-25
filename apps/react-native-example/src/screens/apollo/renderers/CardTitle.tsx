import type { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import {
  CARD_HIGHLIGHT,
  CARD_LABEL,
  FONTS,
  PANEL,
  PANEL_EDGE,
  accentFor,
} from '../theme';

// A card's header: the component that draws it, in the same accent as its
// tag on the Duo's source page, then what the card shows.
export function CardTitle({
  renderer,
  title,
  right,
}: {
  renderer: string;
  title: string;
  right?: ReactNode;
}) {
  const accent = accentFor(renderer);
  return (
    <View style={styles.row}>
      <View style={[styles.chip, { borderColor: `${accent}55` }]}>
        <Text style={[styles.chipText, { color: accent }]}>
          {`<${renderer} />`}
        </Text>
      </View>
      <Text style={styles.title} numberOfLines={1}>
        {title}
      </Text>
      {right}
    </View>
  );
}

export const cardStyle = {
  backgroundColor: PANEL,
  borderRadius: 16,
  borderWidth: 1,
  borderColor: PANEL_EDGE,
  borderTopColor: CARD_HIGHLIGHT,
  padding: 16,
} as const;

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  chip: {
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  chipText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10.5,
  },
  title: {
    flex: 1,
    fontFamily: FONTS.label,
    fontSize: 11,
    letterSpacing: 1,
    color: CARD_LABEL,
  },
});
