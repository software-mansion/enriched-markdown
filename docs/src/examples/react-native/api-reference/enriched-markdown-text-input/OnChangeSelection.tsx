import { useState } from 'react';
import { View, Text } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  const [sel, setSel] = useState({ start: 0, end: 0 });

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        defaultValue="Select part of this sentence."
        onChangeSelection={setSel}
      />
      <Text>
        Selection: [{sel.start}, {sel.end}]
      </Text>
    </View>
  );
}
