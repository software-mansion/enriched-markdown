import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type HighlightLayoutEvent,
  type MarkdownStyle,
  type RenderedTextChangeEvent,
  type TextHighlight,
} from 'react-native-enriched-markdown';

const MARKDOWN = `# Reading along

Text-to-speech engines report which word they speak. **Highlights** paint that word, and the paragraph around it, behind the rendered text without rendering the Markdown again.

## Why draw instead of style

A highlight is drawn, not added to the text. Select some text while it moves: the selection, *copy* and accessibility stay the same.

- Lists keep their markers.
- Nested **bold** and \`inline code\` keep their style.
- Each word moves the highlight a step.

> A quote is read like any other paragraph, and its border stays in place.

\`\`\`ts
const word = words[index];
\`\`\`

| Engine | Rate |
| --- | --- |
| Native | 1.0 |

The view reports where each highlight sits, so the screen scrolls to keep the spoken word in sight. The paragraph tint and the word tint are two entries in one array, and later entries paint over earlier ones.

When the last word is read, playback starts again from the top. Use the buttons to pause, step and switch the flavor or the theme.
`;

type Word = { start: number; end: number; text: string };

const WORD_PATTERN = /\S+/g;

const findWords = (text: string): Word[] =>
  Array.from(text.matchAll(WORD_PATTERN), (match) => ({
    start: match.index,
    end: match.index + match[0].length,
    text: match[0],
  }));

// The paragraph is the text between the newlines around the word.
const paragraphAround = (text: string, word: Word) => {
  const before = text.lastIndexOf('\n', word.start - 1);
  const after = text.indexOf('\n', word.end);
  return { start: before + 1, end: after === -1 ? text.length : after };
};

const THEMES = {
  light: {
    background: '#FFFFFF',
    text: '#1C1C1E',
    muted: '#6E6E73',
    quote: '#F2F2F7',
    paragraph: 'rgba(255, 204, 0, 0.18)',
    word: 'rgba(255, 149, 0, 0.45)',
  },
  dark: {
    background: '#000000',
    text: '#F2F2F7',
    muted: '#98989F',
    quote: '#1C1C1E',
    paragraph: 'rgba(10, 132, 255, 0.22)',
    word: 'rgba(10, 132, 255, 0.55)',
  },
};

type ThemeName = keyof typeof THEMES;

const markdownStyleFor = (theme: ThemeName): MarkdownStyle => {
  const { text, quote } = THEMES[theme];
  return {
    paragraph: { color: text, fontSize: 17, lineHeight: 26 },
    h1: { color: text },
    h2: { color: text },
    list: { color: text, bulletColor: text, markerColor: text },
    blockquote: { color: text, backgroundColor: quote },
  };
};

export default function HighlightScreen() {
  const [theme, setTheme] = useState<ThemeName>('light');
  const [flavor, setFlavor] = useState<'github' | 'commonmark'>('github');
  const [playing, setPlaying] = useState(true);
  const [rendered, setRendered] = useState('');
  const [wordIndex, setWordIndex] = useState(0);

  const scrollRef = useRef<ScrollView>(null);
  const markdownTop = useRef(0);
  const scrollY = useRef(0);
  const viewportHeight = useRef(0);

  const words = useMemo(() => findWords(rendered), [rendered]);
  const word = words.length > 0 ? words[wordIndex % words.length] : undefined;

  useEffect(() => {
    if (!playing || words.length === 0) return;
    const timer = setInterval(
      () => setWordIndex((index) => (index + 1) % words.length),
      300
    );
    return () => clearInterval(timer);
  }, [playing, words.length]);

  const colors = THEMES[theme];
  const highlights = useMemo((): TextHighlight[] => {
    if (!word) return [];
    const paragraph = paragraphAround(rendered, word);
    return [
      { ...paragraph, color: colors.paragraph, borderRadius: 4 },
      {
        start: word.start,
        end: word.end,
        color: colors.word,
        borderRadius: 4,
        padding: 1,
      },
    ];
  }, [word, rendered, colors]);

  const handleRenderedTextChange = useCallback(
    ({ text }: RenderedTextChangeEvent) => setRendered(text),
    []
  );

  // Keeps the spoken word in the upper half of the screen.
  const handleHighlightLayout = useCallback(
    ({ highlights: rects }: HighlightLayoutEvent) => {
      const rect = rects.find(({ index }) => index === 1);
      if (!rect || viewportHeight.current === 0) return;
      const top = markdownTop.current + rect.y;
      const visibleTop = scrollY.current;
      const visibleBottom = visibleTop + viewportHeight.current;
      if (top < visibleTop + 40 || top + rect.height > visibleBottom - 80) {
        scrollRef.current?.scrollTo({
          y: Math.max(0, top - viewportHeight.current / 3),
          animated: true,
        });
      }
    },
    []
  );

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    scrollY.current = e.nativeEvent.contentOffset.y;
  };

  const markdownStyle = useMemo(() => markdownStyleFor(theme), [theme]);

  return (
    <View
      style={[styles.container, { backgroundColor: colors.background }]}
      testID="highlight-screen"
    >
      <View style={styles.toolbar}>
        <ToolbarButton
          label={playing ? 'Pause' : 'Play'}
          onPress={() => setPlaying((value) => !value)}
          testID="highlight-play"
        />
        <ToolbarButton
          label="Step"
          onPress={() =>
            setWordIndex((index) => (index + 1) % Math.max(1, words.length))
          }
          testID="highlight-step"
        />
        <ToolbarButton
          label={flavor === 'github' ? 'GitHub' : 'CommonMark'}
          onPress={() =>
            setFlavor((value) => (value === 'github' ? 'commonmark' : 'github'))
          }
          testID="highlight-flavor"
        />
        <ToolbarButton
          label={theme === 'light' ? 'Dark' : 'Light'}
          onPress={() =>
            setTheme((value) => (value === 'light' ? 'dark' : 'light'))
          }
          testID="highlight-theme"
        />
      </View>
      <Text style={[styles.status, { color: colors.muted }]}>
        {word
          ? `Word ${(wordIndex % words.length) + 1} of ${words.length}: ${word.text}`
          : 'Waiting for the rendered text'}
      </Text>
      <ScrollView
        ref={scrollRef}
        onScroll={handleScroll}
        scrollEventThrottle={16}
        onLayout={(e: LayoutChangeEvent) => {
          viewportHeight.current = e.nativeEvent.layout.height;
        }}
        contentContainerStyle={styles.content}
      >
        <View
          onLayout={(e: LayoutChangeEvent) => {
            markdownTop.current = e.nativeEvent.layout.y;
          }}
        >
          <EnrichedMarkdownText
            key={flavor}
            flavor={flavor}
            markdown={MARKDOWN}
            markdownStyle={markdownStyle}
            highlights={highlights}
            onRenderedTextChange={handleRenderedTextChange}
            onHighlightLayout={handleHighlightLayout}
          />
        </View>
      </ScrollView>
    </View>
  );
}

function ToolbarButton({
  label,
  onPress,
  testID,
}: {
  label: string;
  onPress: () => void;
  testID: string;
}) {
  return (
    <Pressable style={styles.button} onPress={onPress} testID={testID}>
      <Text style={styles.buttonLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  toolbar: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  button: {
    backgroundColor: '#007AFF',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  buttonLabel: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  status: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    fontSize: 13,
  },
  content: {
    paddingHorizontal: 16,
    paddingBottom: 400,
  },
});
