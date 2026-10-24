import React from 'react';
import { ScrollView, StyleSheet, Text } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

// Regression coverage for issue #826: on iOS inline code was built with an
// unscaled font size, so it ignored Dynamic Type while the paragraph around it
// scaled. Below the default text size the code outgrew the scaled line height
// and its background overlapped the neighboring lines. Change the system text
// size: the inline code must grow and shrink together with the paragraph, like
// the monospace run in the plain <Text> control.

const markdown =
  'You treat the model object like a function: `output = my_model(input_data)`. The next line sits right under the code, and `forward` runs for you.';

const markdownStyle = {
  paragraph: { fontSize: 15, lineHeight: 20, marginTop: 0, marginBottom: 0 },
  code: { fontSize: 15, backgroundColor: '#1E1E1E', color: '#9CDCFE' },
};

export default storyMeta('Regression', 'Inline Code Font Scaling (#826)');

export const Default: TextStory = {
  args: { markdown },
  render: () => (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Inline code font scaling (#826)</Text>
      <Text style={styles.description}>
        Set Dynamic Type to a small and a large size. Inline code must scale
        with the paragraph and its background must stay within its own line.
      </Text>

      <Text style={styles.label}>plain {'<Text>'} - control</Text>
      <Text style={markdownStyle.paragraph}>
        You treat the model object like a function:{' '}
        <Text style={styles.monospace}>output = my_model(input_data)</Text>.
      </Text>

      <Text style={styles.label}>EnrichedMarkdownText</Text>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />

      <Text style={styles.label}>
        EnrichedMarkdownText, allowFontScaling=false
      </Text>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        allowFontScaling={false}
      />
    </ScrollView>
  ),
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 12,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
  },
  label: {
    fontSize: 12,
    color: '#888',
  },
  monospace: {
    fontFamily: 'Menlo',
    fontSize: 15,
    backgroundColor: '#1E1E1E',
    color: '#9CDCFE',
  },
});
