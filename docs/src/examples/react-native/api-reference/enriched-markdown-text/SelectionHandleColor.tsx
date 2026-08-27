import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'Select this text on Android to see the tinted drag handles.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Colors the selection drag anchors independently of selectionColor.
      // No-op on Android API levels below 29.
      selectionHandleColor="#57b495"
    />
  );
}
