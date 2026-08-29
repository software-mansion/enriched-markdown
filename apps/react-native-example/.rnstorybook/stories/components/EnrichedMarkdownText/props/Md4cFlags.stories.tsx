import React, { useEffect, useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  EnrichedMarkdownText,
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import {
  githubFlavorArgTypes,
  type MarkdownFlavor,
} from '../shared/storybookMarkdownStyles';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type Md4cFlagsStoryExtra = {
  underline: boolean;
  superscript: boolean;
  subscript: boolean;
  highlight: boolean;
  latexMath: boolean;
  hardSoftBreaks: boolean;
  preserveBlankLines: boolean;
  flavor: MarkdownFlavor;
};

const MARKDOWN = `_underline_

text^superscript^

text~subscript~

==highlight==

$E = mc^2$

Line one
Line two
Line three

Blank lines above this paragraph.




Three blank lines above (toggle preserveBlankLines).`;

const argTypes = {
  underline: {
    control: 'boolean',
    description:
      'md4cFlags.underline — _text_ becomes underline instead of emphasis.',
  },
  superscript: {
    control: 'boolean',
    description: 'md4cFlags.superscript — ^text^ parsing.',
  },
  subscript: {
    control: 'boolean',
    description:
      'md4cFlags.subscript — ~text~ parsing (disables single-tilde strikethrough).',
  },
  highlight: {
    control: 'boolean',
    description: 'md4cFlags.highlight — ==text== parsing.',
  },
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — $...$ and $$...$$ math parsing.',
  },
  hardSoftBreaks: {
    control: 'boolean',
    description:
      'md4cFlags.hardSoftBreaks — treat single newlines as hard line breaks.',
  },
  preserveBlankLines: {
    control: 'boolean',
    description:
      'md4cFlags.preserveBlankLines — keep consecutive blank lines as extra empty lines instead of collapsing them.',
  },
  ...githubFlavorArgTypes('LaTeX math requires flavor="github".'),
};

// Sidebar title uses "Md4c-Flags"; file name follows camelCase convention.
export default storyMeta('Props', 'Md4c-Flags');

export const Default: TextStory<Md4cFlagsStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    underline: true,
    superscript: true,
    subscript: true,
    highlight: true,
    latexMath: true,
    hardSoftBreaks: false,
    preserveBlankLines: false,
    flavor: 'github',
  },
  argTypes,
  render: ({
    underline,
    superscript,
    subscript,
    highlight,
    latexMath,
    hardSoftBreaks,
    preserveBlankLines,
    ...args
  }) => (
    <EnrichedMarkdownTextStory
      title="Md4c-Flags"
      description="Cross-cutting md4cFlags demo. Individual inline/block stories also expose the minimum flag each syntax needs."
      {...args}
      md4cFlags={{
        underline,
        superscript,
        subscript,
        highlight,
        latexMath,
        hardSoftBreaks,
        preserveBlankLines,
      }}
    />
  ),
};

type TextLikeInputExtra = {
  hardSoftBreaks: boolean;
  preserveBlankLines: boolean;
};

// Seeded with both single newlines (Enter once) and blank-line runs (Enter
// several times). By default CommonMark collapses single newlines to spaces and
// blank-line runs to one paragraph break; the two flags make the rendered text
// mirror what was typed in the editor.
const TEXT_LIKE_MARKDOWN = `First message.
Second line, single newline above.
Third line, single newline above.




Four blank lines above this line.


Two blank lines above this one.`;

// Paragraph margins are zeroed so vertical spacing is driven purely by the blank
// lines, matching the plain-text editor above (the recommended setup for a
// chat-like round trip).
const TEXT_LIKE_STYLE = {
  paragraph: { marginTop: 0, marginBottom: 0 },
};

// Live editor -> renderer demo: whatever is typed (or seeded) in the
// EnrichedMarkdownTextInput is rendered below by EnrichedMarkdownText, so the two
// flags that affect the input round trip can be toggled together.
function TextLikeInputDemo({
  hardSoftBreaks,
  preserveBlankLines,
}: TextLikeInputExtra) {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [markdown, setMarkdown] = useState(TEXT_LIKE_MARKDOWN);

  useEffect(() => {
    inputRef.current?.setValue(TEXT_LIKE_MARKDOWN);
  }, []);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Text-Like Input</Text>
      <Text style={styles.description}>
        Content authored in EnrichedMarkdownTextInput, rendered live by
        EnrichedMarkdownText. `hardSoftBreaks` keeps single newlines (Enter
        once); `preserveBlankLines` keeps blank-line runs (Enter several times).
        Paragraph margins are set to 0 here so blank lines drive all spacing.
        Toggle them in Controls and edit the text to compare.
      </Text>

      <View style={styles.block}>
        <Text style={styles.label}>Input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type here and press Enter a few times…"
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            onChangeMarkdown={setMarkdown}
          />
        </View>
      </View>

      <View style={styles.block}>
        <Text style={styles.label}>
          Output (hardSoftBreaks: {String(hardSoftBreaks)}, preserveBlankLines:{' '}
          {String(preserveBlankLines)})
        </Text>
        <View style={styles.output}>
          <EnrichedMarkdownText
            markdown={markdown}
            markdownStyle={TEXT_LIKE_STYLE}
            md4cFlags={{ hardSoftBreaks, preserveBlankLines }}
          />
        </View>
      </View>
    </ScrollView>
  );
}

export const TextLikeInput: TextStory<TextLikeInputExtra> = {
  args: {
    hardSoftBreaks: true,
    preserveBlankLines: true,
  },
  argTypes: {
    hardSoftBreaks: {
      control: 'boolean',
      description:
        'md4cFlags.hardSoftBreaks — treat single newlines as hard line breaks instead of collapsing them to spaces.',
    },
    preserveBlankLines: {
      control: 'boolean',
      description:
        'md4cFlags.preserveBlankLines — keep consecutive blank lines as extra empty lines instead of collapsing them to one break.',
    },
  },
  render: ({ hardSoftBreaks, preserveBlankLines }) => (
    <TextLikeInputDemo
      hardSoftBreaks={hardSoftBreaks ?? false}
      preserveBlankLines={preserveBlankLines ?? false}
    />
  ),
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  block: {
    paddingVertical: 8,
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
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 6,
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
  output: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    minHeight: 48,
  },
});
