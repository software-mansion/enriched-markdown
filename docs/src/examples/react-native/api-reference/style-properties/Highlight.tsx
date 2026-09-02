import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Draw the eye with ==highlighted spans== dropped right into a sentence.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Highlight needs md4cFlags={{ highlight: true }}. Only color and
  // backgroundColor apply; the rest inherits from the block.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    highlight: {
      color: '#1f2937',
      backgroundColor: isDark ? '#fde047' : '#fef08a',
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ highlight: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
