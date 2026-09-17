import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `\`\`\`tsx
function greet(name: string) {
  // build the greeting
  const message = 'Hello, ' + name;
  return message;
}
\`\`\`
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  // syntaxColors recolors individual token types. Omitted tokens keep the
  // default palette; operator/punctuation/variable/embedded inherit the code
  // block's base color. Fenced code blocks need flavor="github".
  const markdownStyle = {
    ...base,
    codeBlock: {
      ...base.codeBlock,
      syntaxColors: {
        keyword: isDark ? '#FF7B72' : '#CF222E',
        string: isDark ? '#A5D6FF' : '#0A3069',
        comment: isDark ? '#8B949E' : '#6E7781',
        function: isDark ? '#D2A8FF' : '#8250DF',
        type: isDark ? '#FFA657' : '#953800',
      },
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="github"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
