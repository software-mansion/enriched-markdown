import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const src =
  'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNDAiIGhlaWdodD0iMTIwIj48cmVjdCB3aWR0aD0iMjQwIiBoZWlnaHQ9IjEyMCIgcng9IjgiIGZpbGw9IiM1N2I0OTUiLz48dGV4dCB4PSIxMjAiIHk9IjY4IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIyMiIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSI+aW1hZ2U8L3RleHQ+PC9zdmc+';

const markdown = `![A sample image](${src})`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // A block image on its own line. height sets a fixed height; borderRadius
  // rounds the corners and the margins space it from surrounding blocks.
  // maxHeight and aspectRatio are alternative sizing knobs (precedence:
  // aspectRatio > maxHeight > height).
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    image: {
      height: 120,
      borderRadius: 12,
      marginTop: 8,
      marginBottom: 8,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
