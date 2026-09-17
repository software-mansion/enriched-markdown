import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `A fenced block renders as its own surface:

\`\`\`ts
const greeting = 'hello';
console.log(greeting);
\`\`\`
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // A code block keeps a dark IDE-like surface in both schemes so it always
  // reads as code.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    codeBlock: {
      color: '#e2e8f0',
      backgroundColor: isDark ? '#0f172a' : '#1e293b',
      borderRadius: 12,
      padding: 16,
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
