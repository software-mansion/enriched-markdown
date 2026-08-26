import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownStyle } from 'react-native-enriched-markdown';
import { View, StyleSheet, Linking, useColorScheme } from 'react-native';

const markdown = `# Welcome to Markdown!

I can render a paragraph with **bold**, *italic*, and a [link](https://enriched.swmansion.com/markdown).

> Blockquotes work too.

- List item one
- List item two
  - Nested item
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Every element is styleable through the \`markdownStyle\` prop. Colors follow
  // the color scheme - tweak the values below and watch the preview update.
  const text = isDark ? '#e7eaf6' : '#232736';
  const markdownStyle: MarkdownStyle = {
    h1: { fontSize: 28, marginBottom: 8, color: text },
    h2: { fontSize: 22, marginBottom: 8, color: text },
    paragraph: { fontSize: 16, color: text },
    list: { color: text },
    blockquote: {
      color: text,
      borderColor: isDark ? '#c9b0fa' : '#782aeb',
      backgroundColor: isDark ? '#332b4d' : '#e8dafc',
      borderWidth: 4,
      gapWidth: 12,
    },
    link: { color: '#57b495' },
    code: {
      color: isDark ? '#c9b0ff' : '#782aeb',
      backgroundColor: isDark ? '#332b4d' : '#e8dafc',
    },
    codeblock: {
      color: isDark ? '#e2e5ff' : '#232736',
      backgroundColor: isDark ? '#2b2f45' : '#e2e5ff',
      borderRadius: 8,
    },
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
