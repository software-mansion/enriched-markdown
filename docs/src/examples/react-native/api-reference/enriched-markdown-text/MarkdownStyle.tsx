import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Styled heading

A paragraph with **bold**, *italic*, and \`inline code\`.

> A blockquote to show the border and background [with link](https://docs.swmansion.com/react-native-reanimated).

- First item
- Second item
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Start from the shared default palette, then override just the elements you
  // want. Each key you set replaces that element's style object.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    h1: { fontSize: 26, color: '#57b495' },
    link: { color: '#e0699f' },
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
