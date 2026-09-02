import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `## Heading with **bold** and a [link](https://docs.swmansion.com)

- List item with *italic* and \`inline code\`
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  const headingColor = isDark ? '#7dd3fc' : '#1d4ed8';
  const listColor = isDark ? '#9ca3af' : '#6b7280';

  // Only the two blocks set size and color. The inline elements below leave
  // those unset, so each inherits its block's size and color and adds only its
  // own emphasis: strong -> bold, em -> italic, link -> its color + underline,
  // code -> a background chip. Change the block color and every inline element
  // inside it follows.
  const markdownStyle = {
    ...base,
    h2: { fontSize: 24, color: headingColor },
    list: { fontSize: 16, color: listColor },
    strong: {},
    em: {},
    link: { color: isDark ? '#f0abfc' : '#c026d3', underline: true },
    code: {
      backgroundColor: isDark ? '#25322d' : '#e6f4ee',
      borderColor: isDark ? '#315049' : '#bfe3db',
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
