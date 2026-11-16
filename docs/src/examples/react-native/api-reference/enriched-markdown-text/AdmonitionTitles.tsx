import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `> [!NOTE]
> Przydatna informacja, warta uwagi nawet przy szybkim czytaniu.

> [!WARNING]
> Pilna informacja, która wymaga natychmiastowej uwagi.

> [!TIP]
> Without a translation, a type keeps its English title.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <EnrichedMarkdownText
      flavor="github"
      markdown={markdown}
      markdownStyle={markdownStyle}
      admonitionTitles={{ note: 'Uwaga', warning: 'Ostrzeżenie' }}
    />
  );
}
