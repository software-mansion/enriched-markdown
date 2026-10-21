import { useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import type { MarkdownTextInputStyle } from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  // The style derives from the color scheme, so it is memoized on it: the
  // input then gets the same object reference on every render. Never inline
  // the object in JSX.
  const markdownStyle = useMemo<MarkdownTextInputStyle>(
    () => ({
      ...defaultInputMarkdownStyle(isDark),
      strong: { color: isDark ? '#93C5FD' : '#1D4ED8' },
      em: { color: isDark ? '#C4B5FD' : '#7C3AED' },
      link: { color: isDark ? '#60A5FA' : '#2563EB', underline: true },
      h1: { fontSize: 28, fontWeight: 'bold', color: isDark ? '#F9FAFB' : '#111827' },
      list: { itemSpacing: 6 },
    }),
    [isDark]
  );

  return (
    <EnrichedMarkdownTextInput
      defaultValue={
        '# Heading\n\n**Bold**, *italic*, and a [link](https://swmansion.com).\n\n- One\n- Two'
      }
      markdownStyle={markdownStyle}
      style={defaultInputColors(isDark)}
    />
  );
}
