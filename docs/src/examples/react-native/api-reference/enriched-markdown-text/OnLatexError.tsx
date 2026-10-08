import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown =
  'Valid: $E = mc^2$\n\nInvalid inline: $\\nosuchcommand$\n\n$$\\frac{1}{\\bogus}$$';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Fires once per distinct failing expression per component instance.
      // The failing formula still renders as its raw source rather than
      // crashing - this callback is for reporting, not recovery.
      onLatexError={({ source, message, displayMode }) => {
        console.log('LaTeX failed', { source, message, displayMode });
      }}
    />
  );
}
