import { useRef, useState } from 'react';
import { View, Button, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        style={defaultInputColors(isDark)}
        ref={ref}
        placeholder="Type, then toggle bold"
        onChangeState={setState}
      />
      <Button
        title={state?.bold.isActive ? 'Bold (on)' : 'Bold'}
        color={state?.bold.isActive ? 'green' : undefined}
        onPress={() => ref.current?.toggleBold()}
      />
    </View>
  );
}
