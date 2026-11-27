import { useState } from 'react';
import { View, Text, useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [sel, setSel] = useState({ start: 0, end: 0 });

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        style={defaultInputColors(isDark)}
        defaultValue="Select part of this sentence."
        onChangeSelection={setSel}
      />
      <Text style={{ color: defaultInputColors(isDark).color }}>
        Selection: [{sel.start}, {sel.end}]
      </Text>
    </View>
  );
}
