import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import type { TextStory } from '../shared/storyTypes';

// Regression coverage for issue #770: on iOS the visible text view rendered
// each line taller than the measured frame for fonts with a nonzero lineGap
// (Poppins), so the last block's descenders (g, j, p, q, y) clipped at the
// bottom - worse with each added block. Every line here ends in "gjpqy" and
// sits in a tight red frame so any clip shows against the border. The plain
// <Text> row is the control: the font itself renders fine, so if only the
// EnrichedMarkdownText rows clip the bug has regressed.

type Controls = {
  fontFamily: string;
  fontSize: number;
  lineHeight: number;
};

const defaults: Controls = {
  fontFamily: 'Poppins-Regular',
  fontSize: 14,
  lineHeight: 20,
};

const lines = (n: number) =>
  Array.from({ length: n }, (_, i) => `line ${i + 1} gjpqy`);
const markdownFor = (n: number) => lines(n).join('\n\n');

const argTypes = {
  fontFamily: fontFamilyControl('markdownStyle.paragraph.fontFamily'),
  fontSize: numberControl('markdownStyle.paragraph.fontSize', {
    min: 12,
    max: 32,
    step: 1,
  }),
  lineHeight: numberControl('markdownStyle.paragraph.lineHeight', {
    min: 14,
    max: 48,
    step: 1,
  }),
};

const Frame = ({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) => (
  <View style={styles.frameWrap}>
    <Text style={styles.frameLabel}>{label}</Text>
    <View style={styles.frame}>{children}</View>
  </View>
);

export default storyMeta('Regression', 'Descender Clipping (#770)');

export const Default: TextStory<Controls> = {
  // `markdown` satisfies the component-prop type; the render builds its own
  // per-frame markdown from the block counts below.
  args: { markdown: markdownFor(6), ...defaults },
  argTypes,
  render: (args) => {
    const { fontFamily, fontSize, lineHeight } = { ...defaults, ...args };
    const paragraph = {
      fontSize,
      lineHeight,
      marginTop: 0,
      marginBottom: 0,
      ...(fontFamily ? { fontFamily } : {}),
    };
    const blockCounts = [1, 3, 6];
    return (
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>Descender clipping (#770)</Text>
        <Text style={styles.description}>
          Every line ends in "gjpqy". With a nonzero-lineGap font (Poppins) the
          last block's descenders must stay fully visible inside the red frame.
        </Text>

        <Frame label={`plain <Text> - control (${fontFamily || 'system'})`}>
          {lines(6).map((l) => (
            <Text
              key={l}
              style={{
                fontSize,
                lineHeight,
                ...(fontFamily ? { fontFamily } : {}),
              }}
            >
              {l}
            </Text>
          ))}
        </Frame>

        {blockCounts.map((n) => (
          <Frame key={n} label={`EnrichedMarkdownText - ${n} block(s)`}>
            <EnrichedMarkdownText
              markdown={markdownFor(n)}
              markdownStyle={{ paragraph }}
            />
          </Frame>
        ))}
      </ScrollView>
    );
  },
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
  },
  frameWrap: {
    gap: 4,
  },
  frameLabel: {
    fontSize: 12,
    color: '#888',
  },
  frame: {
    borderWidth: 1,
    borderColor: 'red',
    backgroundColor: 'white',
  },
});
