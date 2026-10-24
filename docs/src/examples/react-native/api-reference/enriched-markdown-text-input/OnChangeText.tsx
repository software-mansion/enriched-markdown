import { useState } from 'react';
import { View, Text, useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [text, setText] = useState('');

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        style={defaultInputColors(isDark)}
        placeholder="Type here..."
        onChangeText={setText}
      />
      <Text style={{ color: defaultInputColors(isDark).color }}>{text.length} characters</Text>
    </View>
  );
}
