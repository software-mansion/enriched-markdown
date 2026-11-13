import React, { useState } from 'react';
import { ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type FocusLog = {
  focused: boolean;
  focusCount: number;
  blurCount: number;
};

const INITIAL_LOG: FocusLog = { focused: false, focusCount: 0, blurCount: 0 };

const FILLER_ROWS = Array.from({ length: 12 }, (_, index) => index + 1);

function useFocusLog() {
  const [log, setLog] = useState(INITIAL_LOG);
  return {
    log,
    onFocus: () =>
      setLog((prev) => ({
        ...prev,
        focused: true,
        focusCount: prev.focusCount + 1,
      })),
    onBlur: () =>
      setLog((prev) => ({
        ...prev,
        focused: false,
        blurCount: prev.blurCount + 1,
      })),
  };
}

function FocusStatus({
  label,
  log,
  testID,
}: {
  label: string;
  log: FocusLog;
  testID: string;
}) {
  return (
    <Text style={styles.status} testID={testID}>
      {label}: {log.focused ? 'focused' : 'blurred'} · focus {log.focusCount} ·
      blur {log.blurCount}
    </Text>
  );
}

function KeyboardDismissOnDragStory({
  rejectResponderTermination,
}: {
  rejectResponderTermination?: boolean;
}) {
  const enriched = useFocusLog();
  const builtIn = useFocusLog();

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="always"
      testID="keyboard-dismiss-scroll"
    >
      <Text style={styles.title}>Keyboard dismiss on drag (#1158)</Text>
      <Text style={styles.description}>
        Tap an input, then drag a short way starting on it and release. The drag
        dismisses the keyboard. For the enriched input it must stay dismissed:
        the focus count must not go up after the release. React Native's
        TextInput is here for comparison and does re-focus.
      </Text>

      <FocusStatus
        label="Enriched"
        log={enriched.log}
        testID="enriched-focus-status"
      />
      <View style={styles.editorContainer}>
        <EnrichedMarkdownTextInput
          testID="enriched-input"
          placeholder="EnrichedMarkdownTextInput"
          placeholderTextColor="#9CA3AF"
          style={styles.input}
          rejectResponderTermination={rejectResponderTermination}
          onFocus={enriched.onFocus}
          onBlur={enriched.onBlur}
        />
      </View>

      <FocusStatus
        label="TextInput"
        log={builtIn.log}
        testID="text-input-focus-status"
      />
      <View style={styles.editorContainer}>
        <TextInput
          testID="text-input"
          multiline
          placeholder="React Native TextInput"
          placeholderTextColor="#9CA3AF"
          style={styles.input}
          rejectResponderTermination={rejectResponderTermination}
          onFocus={builtIn.onFocus}
          onBlur={builtIn.onBlur}
        />
      </View>

      {FILLER_ROWS.map((row) => (
        <View key={row} style={styles.filler}>
          <Text style={styles.fillerText}>Row {row}</Text>
        </View>
      ))}
    </ScrollView>
  );
}

export default storyMeta('Regression', 'Keyboard Dismiss On Drag (#1158)');

export const Default: InputStory = {
  args: { rejectResponderTermination: true },
  argTypes: {
    rejectResponderTermination: {
      control: 'boolean',
      description:
        'Passed to both inputs. Off lets the scroll view take the touch, which is the workaround from the issue.',
    },
  },
  render: ({ rejectResponderTermination }) => (
    <KeyboardDismissOnDragStory
      rejectResponderTermination={rejectResponderTermination}
    />
  ),
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
  status: {
    fontSize: 13,
    color: '#6B7280',
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
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  filler: {
    height: 56,
    justifyContent: 'center',
    paddingHorizontal: 14,
    borderRadius: 8,
    backgroundColor: '#F3F4F6',
  },
  fillerText: {
    fontSize: 14,
    color: '#6B7280',
  },
});
