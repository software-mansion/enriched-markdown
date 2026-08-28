import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, Linking, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Welcome to Markdown!

I can render a paragraph with **bold**, *italic*, and a [link](https://enriched.swmansion.com/markdown).

> Blockquotes work too.

- List item one
- List item two
  - Nested item
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Start from the shared default palette (it follows the color scheme) and
  // override just the elements you want. Every element is styleable this way -
  // tweak a value and watch the preview update.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    link: { color: '#57b495' },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        onLinkPress={({ url }) => Linking.openURL(url)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
