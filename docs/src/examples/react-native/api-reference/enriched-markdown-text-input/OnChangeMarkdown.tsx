import { useState } from 'react';
import { View, Text } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  const [markdown, setMarkdown] = useState('');

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        defaultValue="Make this **bold** to watch the Markdown update."
        onChangeMarkdown={setMarkdown}
      />
      <Text>{markdown}</Text>
    </View>
  );
}
