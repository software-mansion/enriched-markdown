import React, { useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import {
  EnrichedMarkdownText,
  type EnrichedMarkdownTextProps,
  type EnrichedMarkdownTextRef,
} from 'react-native-enriched-markdown';
import { MarkdownStoryLayout } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = [
  '# Ref methods',
  '',
  'Call `getPlainText()` and `copyToClipboard()` imperatively on the component',
  'ref. The value comes from the same parse result as the render, so `<verb>`,',
  '`x < y > z`, and **bold** keep their literal content instead of being',
  'reverse-engineered from the source.',
  '',
  '- first item',
  '- second item',
].join('\n');

function RefMethodsDemo({
  markdown: initialMarkdown,
  ...props
}: EnrichedMarkdownTextProps) {
  const [markdown, setMarkdown] = useState(initialMarkdown);
  const [plainText, setPlainText] = useState('');
  const [copied, setCopied] = useState(false);
  const ref = useRef<EnrichedMarkdownTextRef>(null);

  const handleGetPlainText = async () => {
    setPlainText((await ref.current?.getPlainText()) ?? '');
  };

  const handleCopy = async () => {
    await ref.current?.copyToClipboard();
    setCopied(true);
  };

  return (
    <MarkdownStoryLayout
      title="Ref Methods"
      description="getPlainText() and copyToClipboard() are called imperatively on the component ref."
      markdown={markdown}
      onMarkdownChange={setMarkdown}
      output={
        <View style={styles.container}>
          <EnrichedMarkdownText {...props} ref={ref} markdown={markdown} />

          <View style={styles.actions}>
            <Pressable style={styles.button} onPress={handleCopy}>
              <Text style={styles.buttonText}>Copy to clipboard</Text>
            </Pressable>
            <Pressable style={styles.button} onPress={handleGetPlainText}>
              <Text style={styles.buttonText}>Get plain text</Text>
            </Pressable>
          </View>

          {copied ? (
            <Text style={styles.hint}>Copied to clipboard.</Text>
          ) : null}

          <Text style={styles.label}>getPlainText() result</Text>
          <Text style={styles.result}>
            {plainText || '(press "Get plain text")'}
          </Text>
        </View>
      }
    />
  );
}

export default storyMeta('Props', 'Ref Methods');

export const Default: TextStory = {
  args: {
    markdown: MARKDOWN,
  },
  render: (args) => <RefMethodsDemo {...args} />,
};

const styles = StyleSheet.create({
  container: {
    gap: 12,
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
    backgroundColor: '#5A52FA',
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  hint: {
    fontSize: 13,
    color: '#2E7D32',
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  result: {
    fontFamily: 'monospace',
    fontSize: 13,
    color: '#222',
  },
});
