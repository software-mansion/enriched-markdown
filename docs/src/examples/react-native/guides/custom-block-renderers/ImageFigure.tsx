import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownImageBlock } from 'react-native-enriched-markdown';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Field notes

![A scenic mountain](https://picsum.photos/id/29/800/400 "Morning light")

The paragraph above holds only an image, so \`renderers.image\` draws it. The
inline ![icon](https://picsum.photos/id/30/40/40) stays native.

> ![Quoted](https://picsum.photos/id/37/800/300)
>
> Standalone images inside quotes and admonitions are replaced too.
`;

// Any React element works: the host measures it at the block's width and
// reserves exactly its height, so the Markdown around it stays native.
function Figure({ block }: { block: MarkdownImageBlock }) {
  const [loaded, setLoaded] = useState(false);
  return (
    <Pressable
      onPress={() => console.log('pressed', block.url)}
      style={styles.figure}
      accessibilityRole="image"
      accessibilityLabel={block.altText}>
      <Image
        source={{ uri: block.url }}
        style={styles.image}
        onLoad={() => setLoaded(true)}
      />
      <Text style={styles.caption}>
        {block.title || block.altText}
        {loaded ? '' : ' · loading…'}
      </Text>
    </Pressable>
  );
}

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
        renderers={{
          // Return undefined to keep the native image for some blocks.
          image: block =>
            block.placement === 'admonition' ? undefined : <Figure block={block} />,
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  figure: {
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#1c1c2e',
  },
  image: { width: '100%', aspectRatio: 2 },
  caption: {
    color: '#c7cbe0',
    fontSize: 13,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
});
