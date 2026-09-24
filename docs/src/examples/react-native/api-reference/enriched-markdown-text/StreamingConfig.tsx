import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={streamingMarkdown}
      flavor="github"
      streamingAnimation
      streamingConfig={{
        // Hold incomplete tables back until they are complete...
        tableMode: 'hidden',
        // ...but stream code line-by-line as it arrives.
        codeBlockMode: 'progressive',
      }}
    />
  );
}
