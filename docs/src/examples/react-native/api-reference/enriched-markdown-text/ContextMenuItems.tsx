import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'Select any part of this sentence to open the custom menu.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Custom items appear before the system actions (Copy, etc.). On iOS this
      // requires iOS 16+; the icon is an SF Symbol (ignored on Android).
      contextMenuItems={[
        {
          text: 'Summarize with AI',
          icon: 'sparkles',
          onPress: ({ text, selection }) => {
            console.log('Selected:', text, selection);
          },
        },
      ]}
    />
  );
}
