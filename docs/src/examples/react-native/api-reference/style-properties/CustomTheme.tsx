import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Make it yours

Every element takes a **style object**. Start from the defaults and override only what you want - here the *heading color*, a [link](https://docs.swmansion.com), and the quote accent.

> Blockquotes, \`inline code\`, and lists all pick up your palette.

- One
- Two
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);
  const accent = isDark ? '#c4b5fd' : '#7c3aed';

  // Spread the defaults, then override just the elements you want to restyle.
  const markdownStyle = {
    ...base,
    h1: { fontSize: 30, color: accent },
    link: { color: isDark ? '#f0abfc' : '#c026d3', underline: true },
    blockquote: { ...base.blockquote, borderColor: accent },
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
