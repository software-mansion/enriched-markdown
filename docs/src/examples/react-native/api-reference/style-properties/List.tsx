import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `- First bullet
- Second bullet
  - Nested bullet
1. Ordered one
2. Ordered two`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Bullets and number markers tint independently; bulletSize and gapWidth
  // control the marker column. itemSpacing adds breathing room between
  // consecutive items (nested ones included) without touching the outer margins.
  const markdownStyle = useMemo(() => {
    const accent = isDark ? '#57b495' : '#3f9e82';

    return {
      ...defaultMarkdownStyle(isDark),
      list: {
        color: isDark ? '#e7eaf6' : '#232736',
        bulletColor: accent,
        markerColor: accent,
        bulletSize: 8,
        gapWidth: 12,
        itemSpacing: 8,
      },
    };
  }, [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
