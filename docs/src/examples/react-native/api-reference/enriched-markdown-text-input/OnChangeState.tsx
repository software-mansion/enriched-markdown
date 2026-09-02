import { useRef, useState } from 'react';
import { View, Button } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput ref={ref} onChangeState={setState} />
      <Button
        title={state?.bold.isActive ? 'Bold (on)' : 'Bold'}
        color={state?.bold.isActive ? 'green' : undefined}
        onPress={() => ref.current?.toggleBold()}
      />
    </View>
  );
}
