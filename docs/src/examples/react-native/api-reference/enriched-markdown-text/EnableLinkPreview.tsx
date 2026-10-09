import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'Long-press [this link](https://reactnative.dev) on iOS.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Disables the native iOS link preview on long press without providing
      // an onLinkLongPress handler.
      enableLinkPreview={false}
    />
  );
}
