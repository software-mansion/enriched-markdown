import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue={
        '# Heading\n\n**Bold**, *italic*, and a [link](https://swmansion.com).'
      }
      markdownStyle={{
        strong: { color: '#1D4ED8' },
        em: { color: '#7C3AED' },
        link: { color: '#2563EB', underline: true },
        h1: { fontSize: 28, fontWeight: 'bold', color: '#111827' },
        list: { itemSpacing: 6 },
      }}
    />
  );
}
