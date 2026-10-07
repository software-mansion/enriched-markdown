import { useState } from 'react';
import { View, Text } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  const [text, setText] = useState('');

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput placeholder="Type here..." onChangeText={setText} />
      <Text>{text.length} characters</Text>
    </View>
  );
}
