import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `> [!TIP]
> The default palette only tints the accent bar, title, and icon.

> [!CAUTION]
> This one opts into a background fill as well.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Admonitions nest under blockquote because they reuse its geometry
  // (borderWidth, gapWidth, padding, borderRadius) and override only colors.
  // Pass just the types you want to restyle; the rest keep the GitHub palette.
  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      blockquote: {
        borderWidth: 4,
        gapWidth: 12,
        padding: 12,
        borderRadius: 8,
        admonitions: {
          tip: { color: isDark ? '#4ade80' : '#15803d' },
          caution: {
            color: isDark ? '#f87171' : '#b91c1c',
            backgroundColor: isDark ? '#2c1618' : '#fef2f2',
          },
        },
      },
    }),
    [isDark],
  );

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
