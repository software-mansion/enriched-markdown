import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      // The variant enables pills; the content below fills one in.
      linkVariants: {
        '^https://example\\.com/files/': {
          color: '#3730A3',
          backgroundColor: '#EEF2FF',
          underline: false,
          pill: { iconUri: 'file_icon' },
        },
      },
    }),
    [isDark],
  );

  return (
    <EnrichedMarkdownText
      markdown={markdown}
      markdownStyle={markdownStyle}
      // Keyed by exact URL. Keep the reference stable when nothing changed.
      linkPillContent={{
        'https://example.com/files/src/components/Button.tsx': {
          label: 'Button.tsx',
        },
      }}
    />
  );
}
