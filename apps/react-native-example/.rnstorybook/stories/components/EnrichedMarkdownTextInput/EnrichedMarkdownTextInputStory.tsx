import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type EnrichedMarkdownTextInputProps,
  type StyleState,
} from 'react-native-enriched-markdown';
import { FormattingToolbar } from '../../../../src/components/FormattingToolbar';

type Props = {
  title: string;
  description: string;
  initialMarkdown?: string;
} & EnrichedMarkdownTextInputProps;

export function EnrichedMarkdownTextInputStory({
  title,
  description,
  initialMarkdown,
  style,
  ...props
}: Props) {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [hasSelection, setHasSelection] = useState(false);

  useEffect(() => {
    if (initialMarkdown != null) {
      inputRef.current?.setValue(initialMarkdown);
    }
  }, [initialMarkdown]);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <View style={styles.block}>
        <Text style={styles.label}>Input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type markdown here..."
            placeholderTextColor="#9CA3AF"
            style={{ ...styles.input, ...style }}
            onChangeState={setState}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            {...props}
          />
          <FormattingToolbar
            state={state}
            inputRef={inputRef}
            hasSelection={hasSelection}
          />
        </View>
      </View>
    </ScrollView>
  );
}

const MAX_RECENT_KEYS = 12;

export function KeyPressStory({
  title,
  description,
  onKeyPress,
}: {
  title: string;
  description: string;
  onKeyPress?: EnrichedMarkdownTextInputProps['onKeyPress'];
}) {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [hasSelection, setHasSelection] = useState(false);
  const [recentKeys, setRecentKeys] = useState<string[]>([]);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <View style={styles.block}>
        <Text style={styles.label}>Input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type to see key presses…"
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            onChangeState={setState}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            onKeyPress={(e) => {
              const { key } = e.nativeEvent;
              setRecentKeys((prev) => [key, ...prev].slice(0, MAX_RECENT_KEYS));
              onKeyPress?.(e);
            }}
          />
          <FormattingToolbar
            state={state}
            inputRef={inputRef}
            hasSelection={hasSelection}
          />
        </View>
      </View>

      <View style={styles.block}>
        <Text style={styles.label}>Last keys (newest first)</Text>
        {recentKeys.length === 0 ? (
          <Text style={styles.description}>No keys pressed yet</Text>
        ) : (
          <View style={styles.keyRow}>
            {recentKeys.map((key, index) => (
              <View
                key={`${index}-${key}`}
                style={[styles.keyChip, index === 0 && styles.keyChipLatest]}
              >
                <Text style={styles.keyChipText}>
                  {key === ' ' ? 'Space' : key}
                </Text>
              </View>
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

export const DEFAULT_MENTION_USERS = [
  { id: 'u_1', name: 'Alice', url: 'user://u_1' },
  { id: 'u_2', name: 'Bob', url: 'user://u_2' },
  { id: 'u_3', name: 'Charlie', url: 'user://u_3' },
  { id: 'u_4', name: 'Diana', url: 'user://u_4' },
];

export const DEFAULT_MENTION_CHANNELS = [
  { id: 'c_1', name: 'general', url: 'channel://c_1' },
  { id: 'c_2', name: 'random', url: 'channel://c_2' },
  { id: 'c_3', name: 'design', url: 'channel://c_3' },
];

const MENTIONS_MARKDOWN_STYLE: EnrichedMarkdownTextInputProps['markdownStyle'] =
  {
    link: { color: '#2563EB', underline: false },
    linkVariants: {
      '^user:': {
        color: '#1264A3',
        backgroundColor: '#E8F5FB',
        underline: false,
      },
      '^channel:': {
        color: '#065F46',
        backgroundColor: '#D1FAE5',
        underline: false,
      },
    },
  };

type MentionItem = { id: string; name: string; url: string };

export function MentionsStory({
  title,
  description,
  users = DEFAULT_MENTION_USERS,
  channels = DEFAULT_MENTION_CHANNELS,
}: {
  title: string;
  description: string;
  users?: MentionItem[];
  channels?: MentionItem[];
}) {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [hasSelection, setHasSelection] = useState(false);
  const [activeMention, setActiveMention] = useState<{
    indicator: string;
    query: string;
  } | null>(null);
  const [suggestions, setSuggestions] = useState<MentionItem[]>([]);

  const getSuggestions = useCallback(
    (indicator: string, query: string): MentionItem[] => {
      const list = indicator === '@' ? users : channels;
      return list.filter((item) =>
        item.name.toLowerCase().includes(query.toLowerCase())
      );
    },
    [users, channels]
  );

  const handleStartMention = useCallback(
    ({ indicator }: { indicator: string }) => {
      setActiveMention({ indicator, query: '' });
      setSuggestions(getSuggestions(indicator, ''));
    },
    [getSuggestions]
  );

  const handleChangeMention = useCallback(
    ({ indicator, text }: { indicator: string; text: string }) => {
      setActiveMention({ indicator, query: text });
      setSuggestions(getSuggestions(indicator, text));
    },
    [getSuggestions]
  );

  const handleEndMention = useCallback(() => {
    setActiveMention(null);
    setSuggestions([]);
  }, []);

  const handlePickSuggestion = useCallback(
    (item: MentionItem) => {
      const prefix = activeMention?.indicator ?? '';
      inputRef.current?.insertMention(`${prefix}${item.name}`, item.url);
    },
    [activeMention]
  );

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <View style={styles.block}>
        <Text style={styles.label}>Input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type @ or # to mention…"
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            mentionIndicators={['@', '#']}
            markdownStyle={MENTIONS_MARKDOWN_STYLE}
            onChangeState={setState}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            onStartMention={handleStartMention}
            onChangeMention={handleChangeMention}
            onEndMention={handleEndMention}
          />
          <FormattingToolbar
            state={state}
            inputRef={inputRef}
            hasSelection={hasSelection}
            mentionIndicators={['@', '#']}
          />
        </View>

        {suggestions.length > 0 && (
          <View style={styles.suggestions}>
            {suggestions.map((item) => (
              <TouchableOpacity
                key={item.id}
                style={styles.suggestionItem}
                onPress={() => handlePickSuggestion(item)}
              >
                <Text style={styles.suggestionText}>
                  {activeMention?.indicator}
                  {item.name}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  block: {
    paddingVertical: 8,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
    marginBottom: 4,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 6,
  },
  editorContainer: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: '#fff',
  },
  input: {
    minHeight: 120,
    maxHeight: 200,
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  suggestions: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    marginTop: 4,
    backgroundColor: '#fff',
    overflow: 'hidden',
  },
  suggestionItem: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  suggestionText: {
    fontSize: 14,
    color: '#111827',
  },
  keyRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  keyChip: {
    borderWidth: 1,
    borderColor: '#D1D5DB',
    borderRadius: 6,
    backgroundColor: '#F3F4F6',
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  keyChipLatest: {
    borderColor: '#2563EB',
    backgroundColor: '#DBEAFE',
  },
  keyChipText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#111827',
  },
});
