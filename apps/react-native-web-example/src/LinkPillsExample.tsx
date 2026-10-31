import { StyleSheet, Text, View } from 'react-native';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
  type MarkdownStyle,
} from 'react-native-enriched-markdown';

const svg = (body: string) =>
  `data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`
  )}`;

const BOOK_ICON = svg(
  '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5z"/><path d="M4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5"/>'
);
const FILE_ICON = svg(
  '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6"/>'
);
const avatar = (initials: string, color: string) =>
  `data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="${color}"/><text x="12" y="16" font-family="sans-serif" font-size="11" font-weight="700" fill="white" text-anchor="middle">${initials}</text></svg>`
  )}`;

// The labels are the link text itself, so this markdown reads the same where
// pills are not supported (plain colored links).
const citationMarkdown = `
The Eiffel Tower was built for the 1889 World's Fair [Wikipedia](cite:https://en.wikipedia.org/wiki/Eiffel_Tower) and stood as the tallest man-made structure in the world until 1930 [toureiffel.paris](cite:https://www.toureiffel.paris/en/the-monument/history). Its iron lattice is repainted roughly every seven years [toureiffel.paris — Key figures about painting the tower](cite:https://www.toureiffel.paris/en/the-monument/key-figures-and-anecdotes-about-the-eiffel-tower-painting).

| Fact | Source |
| --- | --- |
| Opened in 1889 | [Wikipedia](cite:https://en.wikipedia.org/wiki/Eiffel_Tower) |
| Height: 330 m | [toureiffel.paris](cite:https://www.toureiffel.paris/en/the-monument/history) |
`.trim();

const mentionMarkdown = `
Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx) and ask [@gregory](user:gregory) or [@ana](user:ana) to review. Plain links like [the docs](https://example.com/docs) stay ordinary links.
`.trim();

const mentionContent = {
  'https://example.com/files/src/components/Button.tsx': {
    label: 'Button.tsx',
  },
  'user:gregory': { iconUri: avatar('G', '#059669') },
  'user:ana': { iconUri: avatar('A', '#7C3AED') },
};

function citationStyle(dark: boolean): MarkdownStyle {
  const text = dark ? '#E5E7EB' : '#1F2937';
  return {
    paragraph: { color: text, fontSize: 16, lineHeight: 26 },
    table: {
      color: text,
      borderColor: dark ? '#374151' : '#E5E7EB',
      headerTextColor: text,
      headerBackgroundColor: dark ? '#1F2937' : '#F9FAFB',
      rowEvenBackgroundColor: dark ? '#111827' : '#FFFFFF',
      rowOddBackgroundColor: dark ? '#1F2937' : '#F9FAFB',
    },
    linkVariants: {
      '^cite:': {
        color: dark ? '#BFDBFE' : '#1E40AF',
        backgroundColor: dark ? '#1E3A5F' : '#EFF6FF',
        underline: false,
        pill: {
          iconUri: BOOK_ICON,
          iconTintColor: dark ? '#93C5FD' : '#3B82F6',
          borderRadius: 999,
          paddingHorizontal: 8,
          paddingVertical: 1,
          borderWidth: 1,
          borderColor: dark ? '#1D4ED8' : '#BFDBFE',
          maxWidth: 220,
        },
      },
    },
  };
}

const mentionStyle: MarkdownStyle = {
  paragraph: { color: '#1F2937', fontSize: 16, lineHeight: 26 },
  link: { color: '#2563EB', underline: true },
  linkVariants: {
    '^https://example\\.com/files/': {
      color: '#3730A3',
      backgroundColor: '#EEF2FF',
      underline: false,
      pill: {
        iconUri: FILE_ICON,
        iconTintColor: '#6366F1',
        borderRadius: 6,
        paddingHorizontal: 6,
        borderWidth: 1,
        borderColor: '#C7D2FE',
      },
    },
    '^user:': {
      color: '#065F46',
      backgroundColor: '#ECFDF5',
      underline: false,
      pill: { borderRadius: 999, paddingHorizontal: 6 },
    },
  },
};

export function LinkPillsExample({
  onLinkPress,
}: {
  onLinkPress: (event: LinkPressEvent) => void;
}) {
  return (
    <View style={styles.column}>
      <Text style={styles.caption}>Citations (linkVariants only)</Text>
      <View style={styles.card} testID="pills-citations-light">
        <EnrichedMarkdownText
          markdown={citationMarkdown}
          markdownStyle={citationStyle(false)}
          onLinkPress={onLinkPress}
        />
      </View>

      <Text style={styles.caption}>Citations, dark</Text>
      <View
        style={[styles.card, styles.darkCard]}
        testID="pills-citations-dark"
      >
        <EnrichedMarkdownText
          markdown={citationMarkdown}
          markdownStyle={citationStyle(true)}
          onLinkPress={onLinkPress}
        />
      </View>

      <Text style={styles.caption}>Files and mentions (the docs example)</Text>
      <View style={styles.card} testID="pills-mentions">
        <EnrichedMarkdownText
          markdown={mentionMarkdown}
          markdownStyle={mentionStyle}
          linkPillContent={mentionContent}
          onLinkPress={onLinkPress}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  column: { gap: 8 },
  caption: { fontSize: 12, fontWeight: '600', color: '#6B7280' },
  card: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    backgroundColor: '#FFFFFF',
    maxWidth: 560,
    marginBottom: 12,
  },
  darkCard: { backgroundColor: '#111827', borderColor: '#1F2937' },
});
