import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      placeholder="Type a URL, e.g. swmansion.com"
      onLinkDetected={({ text, url, start, end }) => {
        console.log(`Detected ${text} -> ${url} at [${start}, ${end}]`);
      }}
    />
  );
}
