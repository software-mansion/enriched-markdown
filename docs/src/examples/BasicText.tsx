import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet } from 'react-native';
import { markdownStyle } from './markdownStyle';

const markdown = `# Hello Markdown

This is a paragraph with **bold**, *italic*, and a [link](https://swmansion.com).

> Blockquotes work too.

- List item one
- List item two
`;

export default function App() {
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
