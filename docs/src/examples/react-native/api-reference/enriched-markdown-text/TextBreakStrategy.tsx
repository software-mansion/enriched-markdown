import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet } from 'react-native';

const markdown =
  'Supercalifragilisticexpialidocious antidisestablishmentarianism ' +
  'pneumonoultramicroscopicsilicovolcanoconiosis fill a narrow column to ' +
  'show how Android breaks long lines.';

export default function App() {
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        // 'simple' | 'highQuality' (default) | 'balanced' - Android only.
        textBreakStrategy="balanced"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { maxWidth: 220 },
});
