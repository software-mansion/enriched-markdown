import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Energy scales as E = mc^2^ and areas as r^2^.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Superscript (^text^) needs md4cFlags={{ superscript: true }}. fontScale
  // sizes it relative to the surrounding text; baselineOffsetScale lifts it up.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    superscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.4,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ superscript: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
