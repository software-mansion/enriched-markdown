import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `Above the rule.

---

Below the rule.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // A thematic break (---) draws as a single line; color, height, and its
  // margins are all styleable.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    thematicBreak: {
      color: isDark ? '#f472b6' : '#db2777',
      height: 3,
      marginTop: 12,
      marginBottom: 12,
    },
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
