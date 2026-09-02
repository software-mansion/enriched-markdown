import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet } from 'react-native';

const markdown =
  'The killer was ||the butler|| all along. Tap the spoiler to reveal it.';

export default function App() {
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        // 'particles' (default) animates a particle overlay; 'solid' paints an
        // opaque rectangle (Discord-style). Both support tap-to-reveal.
        spoilerOverlay="solid"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
