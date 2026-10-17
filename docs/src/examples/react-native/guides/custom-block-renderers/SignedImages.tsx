import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownImageOccurrence } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `Images keep their Markdown URL as content; the request can go elsewhere.

![Private photo](app://photos/29)

Inline ![thumb](app://photos/30) images are resolved too.
`;

// Stands in for a token exchange or a signed-URL service.
async function signUrl(photoId: string): Promise<string> {
  await new Promise(resolve => setTimeout(resolve, 600));
  return `https://picsum.photos/id/${photoId}/800/400`;
}

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  const resolveImageSource = async (image: MarkdownImageOccurrence) => {
    const photoId = image.url.replace('app://photos/', '');
    // Return null to load the Markdown URL as-is; while the promise is pending
    // the image keeps its placeholder and nothing is requested.
    if (!image.url.startsWith('app://')) return null;
    return {
      uri: await signUrl(photoId),
      headers: { Authorization: 'Bearer demo' },
    };
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
        resolveImageSource={resolveImageSource}
        // Events still report the Markdown URL, not the resolved one.
        onImagePress={({ url }) => console.log('pressed', url)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
