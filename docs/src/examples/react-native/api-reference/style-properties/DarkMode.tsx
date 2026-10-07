import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const markdown = `# Theming with the color scheme

The library ships **light-mode** defaults. Provide a second palette and switch on \`useColorScheme()\`.

> Toggle this site between light and dark to watch the palette follow.

- \`inline code\` picks up the code colors
- [links](swmansion.com) use the accent color
`;

// Define the palettes outside the component so the same object reference is
// reused across renders. Each one only names the colors it wants to change.
const lightMarkdownStyle: MarkdownStyle = {
  paragraph: { color: '#232736' },
  h1: { color: '#232736' },
  link: { color: '#c026d3' },
  code: {
    color: '#E01E5A',
    backgroundColor: '#FDF2F4',
    borderColor: '#f6d4dd',
  },
  blockquote: { backgroundColor: '#F9FAFB', borderColor: '#D1D5DB' },
  list: { color: '#232736' },
};

const darkMarkdownStyle: MarkdownStyle = {
  paragraph: { color: '#E5E7EB' },
  h1: { color: '#E5E7EB' },
  link: { color: '#f0abfc' },
  code: {
    color: '#F87171',
    backgroundColor: '#1F2937',
    borderColor: '#374151',
  },
  blockquote: { backgroundColor: '#1F2937', borderColor: '#4B5563' },
  list: { color: '#E5E7EB' },
};

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={isDark ? darkMarkdownStyle : lightMarkdownStyle}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
