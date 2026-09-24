import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'A **chat preview** needs only the first couple of lines. The rest of this paragraph is clamped away, and the truncation is applied to the measurement pass too, so the measured height matches what you see.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        // CommonMark only - ignored under flavor="github". 0 means unlimited.
        numberOfLines={2}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
