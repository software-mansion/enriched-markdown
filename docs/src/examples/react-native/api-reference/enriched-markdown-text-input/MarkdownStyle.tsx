import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import type { MarkdownTextInputStyle } from 'react-native-enriched-markdown';

// Nothing here depends on props or state, so the style lives outside the
// component and the same object reference is reused on every render. Build it
// with useMemo instead when it derives from something that changes (the color
// scheme, a theme prop) - either way, never inline the object in JSX.
const markdownStyle: MarkdownTextInputStyle = {
  strong: { color: '#1D4ED8' },
  em: { color: '#7C3AED' },
  link: { color: '#2563EB', underline: true },
  h1: { fontSize: 28, fontWeight: 'bold', color: '#111827' },
  list: { itemSpacing: 6 },
};

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue={
        '# Heading\n\n**Bold**, *italic*, and a [link](https://swmansion.com).'
      }
      markdownStyle={markdownStyle}
    />
  );
}
