import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = '![A protected image](https://example.com/image.png)';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Attached to remote image requests - e.g. a Referer for CDN hotlink
      // protection or an Authorization token. Headers are part of the image
      // cache key, so the same URL with different headers is cached separately.
      imageRequestHeaders={{
        Referer: 'https://example.com',
      }}
    />
  );
}
