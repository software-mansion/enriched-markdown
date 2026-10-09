import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx) or ask [@gregory](user:gregory).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      linkVariants: {
        // Colors come from the variant; geometry and a shared icon from `pill`.
        '^https://example\\.com/files/': {
          color: '#3730A3',
          backgroundColor: '#EEF2FF',
          underline: false,
          pill: {
            iconUri: 'file_icon',
            borderRadius: 10,
            paddingHorizontal: 7,
            paddingVertical: 2,
            borderWidth: 1,
            borderColor: '#C7D2FE',
            maxWidth: 220,
          },
        },
        // The default look needs nothing more than `pill: true`.
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
    <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
  );
}
