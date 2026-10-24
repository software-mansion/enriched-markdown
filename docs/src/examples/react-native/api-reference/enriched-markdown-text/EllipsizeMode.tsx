import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'A single line that runs past the edge of the view and has to be truncated somewhere.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        // 'head' and 'middle' only place the ellipsis as described at
        // numberOfLines={1}; past one line they fall back to tail truncation.
        numberOfLines={1}
        ellipsizeMode="middle"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
