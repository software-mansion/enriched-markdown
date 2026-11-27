import { useRef, useState } from 'react';
import { View, Button, StyleSheet, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        ref={ref}
        defaultValue={'Preheat the oven\nMix the batter\nBake for 30 min'}
        onChangeState={setState}
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
      />
      <Button
        title="Numbered list"
        color={state?.orderedList.isActive ? 'green' : 'gray'}
        onPress={() => ref.current?.toggleOrderedList()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 110 },
});
