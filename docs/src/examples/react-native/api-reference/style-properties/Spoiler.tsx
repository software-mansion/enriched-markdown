import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'The killer was ||the butler|| all along - tap to reveal.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Spoiler text (||hidden||) is concealed behind an overlay until tapped. The
  // overlay preset is chosen with the spoilerOverlay prop; color drives all
  // presets, and particles/solid tune each preset.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    spoiler: {
      color: isDark ? '#6b7280' : '#374151',
      particles: { density: 10, speed: 24 },
      solid: { borderRadius: 6 },
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        spoilerOverlay="particles"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
