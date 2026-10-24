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
        placeholder="Type here..."
        onChangeState={setState}
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
      />
      <View style={styles.toolbar}>
        <Button
          title={state?.bold.isActive ? 'Unbold' : 'Bold'}
          color={state?.bold.isActive ? 'green' : 'gray'}
          onPress={() => ref.current?.toggleBold()}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  input: { fontSize: 18, padding: 12, minHeight: 96 },
  toolbar: { flexDirection: 'row', gap: 8 },
});
