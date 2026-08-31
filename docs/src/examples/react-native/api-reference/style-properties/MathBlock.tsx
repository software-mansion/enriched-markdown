import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `Block math renders as a standalone display element:

$$
E = mc^2
$$`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Block math ($$...$$) needs md4cFlags={{ latexMath: true }} (on by default).
  // fontSize, color, backgroundColor, padding, margins, and textAlign all apply.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    math: {
      fontSize: 22,
      color: isDark ? '#e5e7eb' : '#111827',
      backgroundColor: isDark ? '#1f2937' : '#f3f4f6',
      padding: 16,
      textAlign: 'center' as const,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="github"
        md4cFlags={{ latexMath: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
