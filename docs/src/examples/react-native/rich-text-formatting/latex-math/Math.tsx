import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

// Block math ($$...$$) needs flavor="github"; inline math ($...$) works anywhere.
// Backslashes are doubled here because this is a JS template literal.
const markdown = `The quadratic formula:

$$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

Einstein's $E = mc^2$ flows inline with the surrounding text.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  const markdownStyle = {
    ...base,
    math: { ...base.math, padding: 12, textAlign: 'center' },
    inlineMath: { ...base.inlineMath },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="github"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
