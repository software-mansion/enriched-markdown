import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `## A styled heading

A paragraph of body text. The base block properties - font size, family,
weight, color, line height, and the top and bottom margins - are shared by
every block element and set here on the paragraph and the heading.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // fontSize, color, lineHeight, fontWeight, and the block margins are the
  // shared base properties every block type extends.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    h2: {
      fontSize: 22,
      color: isDark ? '#93c5fd' : '#1d4ed8',
      marginTop: 0,
      marginBottom: 8,
    },
    paragraph: {
      fontSize: 16,
      color: isDark ? '#e5e7eb' : '#374151',
      lineHeight: 26,
      marginTop: 0,
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
