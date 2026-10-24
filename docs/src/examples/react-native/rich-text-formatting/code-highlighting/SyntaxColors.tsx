import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const fence = '```';

const markdown = `${fence}python
def greet(name: str) -> str:
    return f"Hello, {name}!"  # a comment
${fence}
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  const markdownStyle = useMemo(
    () => ({
      ...defaultMarkdownStyle(isDark),
      codeBlock: {
        ...defaultMarkdownStyle(isDark).codeBlock,
        syntaxColors: {
          keyword: '#C678DD',
          string: '#98C379',
          number: '#D19A66',
          comment: '#7F848E',
          function: '#61AFEF',
          type: '#E5C07B',
        },
      },
    }),
    [isDark]
  );

  return (
    <EnrichedMarkdownText
      flavor="github"
      markdown={markdown}
      markdownStyle={markdownStyle}
    />
  );
}
