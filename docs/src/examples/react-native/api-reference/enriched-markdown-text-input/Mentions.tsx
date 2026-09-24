import { useRef, useState } from 'react';
import { View, Text, Pressable } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

const USERS = ['alice', 'bob', 'carol'];

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [query, setQuery] = useState<string | null>(null);

  const matches =
    query != null
      ? USERS.filter((u) => u.startsWith(query.toLowerCase()))
      : [];

  return (
    <View style={{ gap: 8 }}>
      <EnrichedMarkdownTextInput
        ref={ref}
        mentionIndicators={['@']}
        placeholder="Mention someone with @"
        onStartMention={() => setQuery('')}
        onChangeMention={({ text }) => setQuery(text)}
        onEndMention={() => setQuery(null)}
      />
      {matches.map((user) => (
        <Pressable
          key={user}
          onPress={() =>
            ref.current?.insertMention(`@${user}`, `https://app/users/${user}`)
          }
        >
          <Text>@{user}</Text>
        </Pressable>
      ))}
    </View>
  );
}
