import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'The identity $e^{i\\pi} + 1 = 0$ flows inline with the text.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Inline math ($...$) renders within the text flow. Only the equation color
  // is styleable; size follows the surrounding text.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    inlineMath: {
      color: isDark ? '#5eead4' : '#0d9488',
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ latexMath: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
