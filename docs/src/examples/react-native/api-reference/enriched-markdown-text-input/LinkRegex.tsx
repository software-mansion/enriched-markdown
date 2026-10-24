import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

// Only turn fully-qualified http(s) URLs into links; pass null to disable.
export default function App() {
  return (
    <EnrichedMarkdownTextInput
      linkRegex={/https?:\/\/[^\s]+/i}
      placeholder="Type a URL like https://swmansion.com"
    />
  );
}
