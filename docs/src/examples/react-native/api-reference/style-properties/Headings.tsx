import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Heading level 1
## Heading level 2
### Heading level 3

Body text, for scale.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // fontSize, color, fontWeight, textAlign, and the margins are all fair game
  // per heading level.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    h1: { fontSize: 32, color: isDark ? '#7dd3fc' : '#0369a1' },
    h2: { fontSize: 24, color: isDark ? '#c4b5fd' : '#7c3aed', marginTop: 8 },
    h3: { fontSize: 19, color: isDark ? '#fca5a5' : '#dc2626' },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
