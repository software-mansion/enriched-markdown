import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue="Select this text, then open the menu."
      contextMenuItems={[
        {
          text: 'Summarize with AI',
          icon: 'sparkles',
          onPress: ({ text, styleState }) => {
            console.log('Selected:', text, 'bold?', styleState.bold.isActive);
          },
        },
      ]}
    />
  );
}
