import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

// Superscript (^text^) and highlight (==text==) are md4c flags, toggled
// independently of the flavor. Edit the flags below and watch them turn on/off.
const markdown =
  'Energy is E = mc^2^, and you can ==highlight== the important bits.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        md4cFlags={{ superscript: true, highlight: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
