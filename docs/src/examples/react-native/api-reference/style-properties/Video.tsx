import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  '<video src="https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4" />';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // aspectRatio is the only sizing knob: the video fills the available width
  // and derives its height from the ratio. backgroundColor shows before the
  // video loads and in any letterboxing area.
  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      video: {
        aspectRatio: 16 / 9,
        borderRadius: 12,
        backgroundColor: '#000000',
        marginTop: 8,
        marginBottom: 8,
      },
    }),
    [isDark],
  );

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
