import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue={'# Draft\n\nStart from **existing** Markdown.'}
    />
  );
}
