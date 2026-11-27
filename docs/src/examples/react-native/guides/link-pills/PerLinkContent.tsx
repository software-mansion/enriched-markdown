import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx) or ask [@gregory](user:gregory).';

// Content, not style: this map can change on every render while
// `markdownStyle` stays a stable object.
const content = {
  'https://example.com/files/src/components/Button.tsx': {
    label: 'Button.tsx',
  },
  'user:gregory': {
    iconUri: 'https://example.com/avatars/gregory.png',
  },
};

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      linkVariants: {
        '^https://example\\.com/files/': {
          color: '#3730A3',
          backgroundColor: '#EEF2FF',
          underline: false,
          pill: { iconUri: 'file_icon', borderRadius: 10 },
        },
        '^user:': {
          color: '#065F46',
          backgroundColor: '#ECFDF5',
          underline: false,
          pill: true,
        },
      },
    }),
    [isDark],
  );

  return (
    <EnrichedMarkdownText
      markdown={markdown}
      markdownStyle={markdownStyle}
      linkPillContent={content}
    />
  );
}
