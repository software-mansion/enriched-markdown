import { useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  Switch,
  Button,
  StyleSheet,
} from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const URL = 'https://example.com/context';
const CLIPBOARD = {
  linkTextByUrl: { [URL]: '[Context](ref:one)' },
  htmlAttributes: { 'data-example-context': 'one' },
  mimeTypes: { 'com.example.context': 'one' },
};

export default function SelectionClipboardScreen() {
  const [enabled, setEnabled] = useState(false);
  const [pastedText, setPastedText] = useState('');
  const inputRef = useRef<TextInput>(null);
  return (
    <View style={styles.container}>
      <Text style={styles.instructions}>
        Select the text including the link, copy, and paste below. Enable
        canonical copy to replace the link label with its application identity.
      </Text>
      <View style={styles.row}>
        <Text style={styles.label}>Canonical copy</Text>
        <Switch
          testID="canonical-copy-switch"
          value={enabled}
          onValueChange={setEnabled}
        />
      </View>
      <EnrichedMarkdownText
        testID="clipboard-source"
        markdown={`before[Context](${URL})`}
        selectionClipboard={enabled ? CLIPBOARD : undefined}
        markdownStyle={{ paragraph: { color: '#111827', fontSize: 20 } }}
      />
      <TextInput
        ref={inputRef}
        testID="clipboard-paste"
        accessibilityLabel="Paste copied text"
        placeholder="Paste copied text here"
        multiline
        value={pastedText}
        onChangeText={setPastedText}
        style={styles.input}
      />
      <Button
        testID="clipboard-clear"
        title="Clear pasted text"
        onPress={() => {
          setPastedText('');
          inputRef.current?.blur();
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, gap: 24 },
  instructions: { color: '#374151', fontSize: 16 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  label: { color: '#111827', fontSize: 18 },
  input: {
    borderWidth: 1,
    borderColor: '#9ca3af',
    borderRadius: 8,
    padding: 12,
    minHeight: 100,
    color: '#111827',
    backgroundColor: '#fff',
  },
});
