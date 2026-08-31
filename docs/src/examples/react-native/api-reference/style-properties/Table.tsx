import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `| Element | Style key |
| --- | --- |
| Header | headerBackgroundColor |
| Even row | rowEvenBackgroundColor |
| Odd row | rowOddBackgroundColor |`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Tables need flavor="github". The header and alternating rows each tint
  // separately; borderRadius rounds the whole grid.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    table: {
      color: isDark ? '#e7eaf6' : '#232736',
      headerBackgroundColor: isDark ? '#4c1d95' : '#ede9fe',
      headerTextColor: isDark ? '#ede9fe' : '#5b21b6',
      rowEvenBackgroundColor: isDark ? '#1e1b2e' : '#ffffff',
      rowOddBackgroundColor: isDark ? '#2a2540' : '#f5f3ff',
      borderColor: isDark ? '#6d28d9' : '#c4b5fd',
      borderRadius: 10,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="github"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
