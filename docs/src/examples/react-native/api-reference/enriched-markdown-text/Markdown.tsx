import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Edit me

Change this **Markdown** string and the preview re-renders live.

- A list item
- A [link](https://enriched.swmansion.com)
- Some \`inline code\`
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
