import { useState } from 'react';
import { View, Text } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type CaretRect,
} from 'react-native-enriched-markdown';

export default function App() {
  const [rect, setRect] = useState<CaretRect | null>(null);

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        scrollEnabled={false}
        placeholder="Move the caret..."
        onCaretRectChange={setRect}
      />
      {rect && (
        <Text>
          Caret at x:{Math.round(rect.x)} y:{Math.round(rect.y)}
        </Text>
      )}
    </View>
  );
}
