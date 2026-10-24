import { ScrollView } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

// With scrollEnabled={false} the input grows to fit its content, letting an
// outer ScrollView own the scrolling instead. Pair it with onCaretRectChange
// to keep the caret visible.
export default function App() {
  return (
    <ScrollView keyboardShouldPersistTaps="handled">
      <EnrichedMarkdownTextInput scrollEnabled={false} placeholder="Type a lot..." />
    </ScrollView>
  );
}
