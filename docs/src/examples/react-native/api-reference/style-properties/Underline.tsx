import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Draw a line under _these words_ to underline them.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Underline needs md4cFlags={{ underline: true }}, which makes _text_ an
  // underline instead of emphasis. Only the line color is styleable (iOS and web).
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    underline: {
      color: isDark ? '#57b495' : '#3f9e82',
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ underline: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
