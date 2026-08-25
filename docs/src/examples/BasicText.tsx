import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownStyle } from 'react-native-enriched-markdown';
import { View, StyleSheet, Linking } from 'react-native';

const markdown = `# Welcome to Markdown!

I can render a paragraph with **bold**, *italic*, and a [link](https://reactnative.dev).

> Blockquotes work too.

- List item one
- List item two
  - Nested item
`;

// Every element is styleable through the \`markdownStyle\` prop - tweak the
// colors and sizes below and watch the preview update.
const markdownStyle: MarkdownStyle = {
  h1: { fontSize: 28, marginBottom: 8 },
  h2: { fontSize: 22, marginBottom: 8 },
  paragraph: { fontSize: 16 },
  link: { color: '#57b495' },
  code: { color: '#782aeb', backgroundColor: '#e8dafc' },
  codeblock: { color: '#232736', backgroundColor: '#e2e5ff', borderRadius: 8 },
  blockquote: { borderColor: '#919fcf', borderWidth: 4, gapWidth: 12 },
};

export default function App() {
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
