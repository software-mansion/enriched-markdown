import React, { useEffect, useRef } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

const SAMPLE_MARKDOWN =
  'Place the cursor anywhere in this text, or select a fragment, then insert below.';

const SNIPPETS = [
  { label: 'Insert plain text', markdown: 'inserted text' },
  {
    label: 'Insert inline markdown',
    markdown: '**bold**, *italic* and a [link](https://swmansion.com)',
  },
  {
    label: 'Insert a list',
    markdown: '\n- first item\n- second item\n',
  },
] as const;

export default storyMeta('Methods', 'InsertText');

function InsertTextDemo() {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);

  useEffect(() => {
    inputRef.current?.setValue(SAMPLE_MARKDOWN);
  }, []);

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>insertText()</Text>
      <Text style={styles.description}>
        Ref method that parses the given string as Markdown and inserts it
        literally at the current cursor position, replacing the selection if
        there is one. Leading and trailing newlines are preserved, so wrap block
        content (lists, headings) in newlines to keep it on its own lines when
        inserting mid-paragraph.
      </Text>

      <View style={styles.block}>
        <Text style={styles.label}>Input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type markdown here..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
          />
        </View>
        {SNIPPETS.map(({ label, markdown }) => (
          <TouchableOpacity
            key={label}
            style={styles.actionButton}
            onPress={() => inputRef.current?.insertText(markdown)}
          >
            <Text style={styles.actionButtonText}>{label}</Text>
          </TouchableOpacity>
        ))}
      </View>
    </ScrollView>
  );
}

export const Default: InputStory = {
  render: () => <InsertTextDemo />,
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
    marginBottom: 4,
  },
  block: {
    paddingVertical: 8,
    gap: 8,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  editorContainer: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: '#fff',
  },
  input: {
    minHeight: 120,
    maxHeight: 200,
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  actionButton: {
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#BEEBD0',
    alignItems: 'center',
  },
  actionButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#001A72',
  },
});
