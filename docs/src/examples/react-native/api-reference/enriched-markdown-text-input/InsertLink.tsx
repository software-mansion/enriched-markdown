import { useRef } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

// insertLink adds a brand-new link at the cursor - handy when nothing is selected.
export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Place the cursor here: "
        style={styles.input}
      />
      <Button
        title="Insert link"
        onPress={() =>
          ref.current?.insertLink('Software Mansion', 'https://swmansion.com')
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
});
