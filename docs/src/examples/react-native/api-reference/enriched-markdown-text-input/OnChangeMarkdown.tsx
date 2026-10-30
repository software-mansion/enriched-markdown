import { useState } from 'react';
import { View, Text, useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [markdown, setMarkdown] = useState('');

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        style={defaultInputColors(isDark)}
        defaultValue="Make this **bold** to watch the Markdown update."
        onChangeMarkdown={setMarkdown}
      />
      <Text style={{ color: defaultInputColors(isDark).color }}>{markdown}</Text>
    </View>
  );
}
