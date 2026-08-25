import { useRef, useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  Pressable,
  Alert,
} from 'react-native-macos';
import {
  EnrichedMarkdownTextInput,
  EnrichedMarkdownText,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

interface Message {
  id: number;
  markdown: string;
  isOwn: boolean;
  time: string;
}

const INITIAL_MESSAGES: Message[] = [
  {
    id: 1,
    markdown: 'Hey! Try out the rich text editor below 👇',
    isOwn: false,
    time: '10:51',
  },
  {
    id: 2,
    markdown:
      'Sure! It supports **bold**, *italic*, ~~strikethrough~~ and _underline_.',
    isOwn: true,
    time: '10:52',
  },
  {
    id: 3,
    markdown:
      'You can also add [links](https://github.com) and combine **_bold italic_** styles.',
    isOwn: true,
    time: '10:52',
  },
  {
    id: 4,
    markdown:
      'The toolbar above the input lets you toggle formatting at the cursor too.',
    isOwn: true,
    time: '10:53',
  },
];

const MARKDOWN_STYLE = {
  link: { color: '#2563EB', underline: true },
};

let nextId = 5;

export default function InputScreen() {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const scrollRef = useRef<ScrollView>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [messages, setMessages] = useState<Message[]>(INITIAL_MESSAGES);

  const bubbleContextMenuItems = useMemo(
    () => [
      {
        text: 'Summarize with AI',
        icon: 'sparkles',
        onPress: ({ text }: { text: string }) => {
          Alert.alert('✦ Summarize with AI', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
      {
        text: 'Reply',
        icon: 'arrowshape.turn.up.left.fill',
        onPress: ({ text }: { text: string }) => {
          inputRef.current?.setValue(`> ${text}\n\n`);
          inputRef.current?.focus();
        },
      },
    ],
    []
  );

  const inputContextMenuItems = useMemo(
    () => [
      {
        text: 'Summarize with AI',
        icon: 'sparkles',
        onPress: ({
          text,
          styleState,
        }: {
          text: string;
          styleState: StyleState;
        }) => {
          const flags = [
            styleState.bold.isActive && 'bold',
            styleState.italic.isActive && 'italic',
            styleState.underline.isActive && 'underline',
            styleState.strikethrough.isActive && 'strikethrough',
            styleState.link.isActive && 'link',
          ]
            .filter(Boolean)
            .join(', ');
          Alert.alert(
            '✦ Summarize with AI',
            `"${text}"${flags ? `\n\nActive styles: ${flags}` : ''}`,
            [{ text: 'Dismiss', style: 'cancel' }]
          );
        },
      },
    ],
    []
  );

  const sendMessage = useCallback(async () => {
    const md = await inputRef.current?.getMarkdown();
    if (!md || md.trim().length === 0) return;

    const now = new Date();
    const time = `${now.getHours()}:${String(now.getMinutes()).padStart(2, '0')}`;

    setMessages((prev) => [
      ...prev,
      { id: nextId++, markdown: md.trim(), isOwn: true, time },
    ]);

    inputRef.current?.setValue('');
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.sidebar}>
        <View style={styles.sidebarHeader}>
          <Text style={styles.sidebarTitle}>Messages</Text>
        </View>
        <View style={styles.sidebarItem}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>JD</Text>
          </View>
          <View style={styles.sidebarItemText}>
            <Text style={styles.sidebarName}>John Doe</Text>
            <Text style={styles.sidebarPreview} numberOfLines={1}>
              online
            </Text>
          </View>
        </View>
      </View>
      <View style={styles.chat}>
        <View style={styles.header}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>JD</Text>
          </View>
          <View>
            <Text style={styles.headerName}>John Doe</Text>
            <Text style={styles.headerStatus}>online</Text>
          </View>
        </View>
        <ScrollView
          ref={scrollRef}
          style={styles.messageList}
          contentContainerStyle={styles.messageListContent}
          onContentSizeChange={() =>
            scrollRef.current?.scrollToEnd({ animated: false })
          }
        >
          {messages.map((msg) => (
            <View
              key={msg.id}
              style={[
                styles.messageRow,
                msg.isOwn ? styles.messageRowOwn : styles.messageRowOther,
              ]}
            >
              <View
                style={[
                  styles.bubble,
                  msg.isOwn ? styles.bubbleOwn : styles.bubbleOther,
                ]}
              >
                <EnrichedMarkdownText
                  containerStyle={StyleSheet.flatten([
                    styles.bubbleText,
                    msg.isOwn ? styles.bubbleTextOwn : styles.bubbleTextOther,
                  ])}
                  markdownStyle={MARKDOWN_STYLE}
                  markdown={msg.markdown}
                  contextMenuItems={bubbleContextMenuItems}
                />
                <Text
                  style={[
                    styles.bubbleTime,
                    msg.isOwn ? styles.bubbleTimeOwn : styles.bubbleTimeOther,
                  ]}
                >
                  {msg.time}
                </Text>
              </View>
            </View>
          ))}
        </ScrollView>

        {/* Formatting toolbar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.toolbarScroll}
          contentContainerStyle={styles.toolbar}
        >
          {(
            [
              { label: 'B', style: 'bold', action: 'toggleBold' },
              { label: 'I', style: 'italic', action: 'toggleItalic' },
              { label: 'U', style: 'underline', action: 'toggleUnderline' },
              {
                label: 'S',
                style: 'strikethrough',
                action: 'toggleStrikethrough',
              },
            ] as const
          ).map(({ label, style, action }) => (
            <Pressable
              key={label}
              style={[
                styles.toolbarButton,
                state?.[style].isActive && styles.toolbarButtonActive,
              ]}
              onPress={() => inputRef.current?.[action]()}
            >
              <Text
                style={[
                  styles.toolbarButtonText,
                  style === 'italic' && styles.italic,
                  style === 'underline' && styles.underline,
                  style === 'strikethrough' && styles.strikethrough,
                  state?.[style].isActive && styles.toolbarButtonTextActive,
                ]}
              >
                {label}
              </Text>
            </Pressable>
          ))}
          <Pressable
            style={[
              styles.toolbarButton,
              state?.link.isActive && styles.toolbarButtonActive,
            ]}
            onPress={() => {
              if (state?.link.isActive) {
                inputRef.current?.removeLink();
              } else {
                inputRef.current?.setLink('https://');
              }
            }}
          >
            <Text
              style={[
                styles.toolbarButtonText,
                state?.link.isActive && styles.toolbarButtonTextActive,
              ]}
            >
              Link
            </Text>
          </Pressable>

          <View style={styles.toolbarSeparator} />

          {([1, 2, 3, 4, 5, 6] as const).map((level) => (
            <Pressable
              key={`h${level}`}
              style={[
                styles.toolbarButton,
                state?.heading.isActive &&
                  state.heading.level === level &&
                  styles.toolbarButtonActive,
              ]}
              onPress={() => inputRef.current?.toggleHeading(level)}
            >
              <Text
                style={[
                  styles.toolbarButtonText,
                  state?.heading.isActive &&
                    state.heading.level === level &&
                    styles.toolbarButtonTextActive,
                ]}
              >
                {`H${level}`}
              </Text>
            </Pressable>
          ))}

          <View style={styles.toolbarSeparator} />

          <Pressable
            style={[
              styles.toolbarButton,
              state?.unorderedList.isActive && styles.toolbarButtonActive,
            ]}
            onPress={() => inputRef.current?.toggleUnorderedList()}
          >
            <Text
              style={[
                styles.toolbarButtonText,
                state?.unorderedList.isActive && styles.toolbarButtonTextActive,
              ]}
            >
              •
            </Text>
          </Pressable>
          <Pressable
            style={[
              styles.toolbarButton,
              state?.orderedList.isActive && styles.toolbarButtonActive,
            ]}
            onPress={() => inputRef.current?.toggleOrderedList()}
          >
            <Text
              style={[
                styles.toolbarButtonText,
                state?.orderedList.isActive && styles.toolbarButtonTextActive,
              ]}
            >
              1.
            </Text>
          </Pressable>
          <Pressable
            style={styles.toolbarButton}
            onPress={() => inputRef.current?.outdentList()}
          >
            <Text style={styles.toolbarButtonText}>⇤</Text>
          </Pressable>
          <Pressable
            style={styles.toolbarButton}
            onPress={() => inputRef.current?.indentList()}
          >
            <Text style={styles.toolbarButtonText}>⇥</Text>
          </Pressable>
        </ScrollView>

        {/* Input row */}
        <View style={styles.inputRow}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Message..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            markdownStyle={MARKDOWN_STYLE}
            onChangeState={setState}
            contextMenuItems={inputContextMenuItems}
          />
          <Pressable style={styles.sendButton} onPress={sendMessage}>
            <Text style={styles.sendIcon}>▶</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const TEAL = '#4A9EBF';
const OWN_BUBBLE = '#DCFCE7';
const OTHER_BUBBLE = '#FFFFFF';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: '#E8F4F8',
  },
  sidebar: {
    width: 240,
    backgroundColor: '#F3F4F6',
    borderRightWidth: StyleSheet.hairlineWidth,
    borderRightColor: '#D1D5DB',
  },
  sidebarHeader: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D1D5DB',
  },
  sidebarTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  sidebarItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#DBEAFE',
  },
  sidebarItemText: {
    flex: 1,
  },
  sidebarName: {
    fontSize: 14,
    fontWeight: '600',
    color: '#111827',
  },
  sidebarPreview: {
    fontSize: 12,
    color: '#6B7280',
    marginTop: 1,
  },
  chat: {
    flex: 1,
    flexDirection: 'column',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: TEAL,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#2980B9',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 13,
  },
  headerName: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 15,
  },
  headerStatus: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 12,
  },
  messageList: {
    flex: 1,
  },
  messageListContent: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 6,
  },
  messageRow: {
    flexDirection: 'row',
  },
  messageRowOwn: {
    justifyContent: 'flex-end',
  },
  messageRowOther: {
    justifyContent: 'flex-start',
  },
  bubble: {
    maxWidth: '65%',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingTop: 8,
    paddingBottom: 6,
  },
  bubbleOwn: {
    backgroundColor: OWN_BUBBLE,
    borderBottomRightRadius: 4,
  },
  bubbleOther: {
    backgroundColor: OTHER_BUBBLE,
    borderBottomLeftRadius: 4,
  },
  bubbleText: {
    fontSize: 14,
    lineHeight: 20,
  },
  bubbleTextOwn: {
    color: '#111827',
  },
  bubbleTextOther: {
    color: '#111827',
  },
  bubbleTime: {
    fontSize: 11,
    marginTop: 4,
    alignSelf: 'flex-end',
  },
  bubbleTimeOwn: {
    color: '#6B9E6B',
  },
  bubbleTimeOther: {
    color: '#9CA3AF',
  },
  toolbarScroll: {
    flexGrow: 0,
    backgroundColor: '#F9FAFB',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E5E7EB',
  },
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  toolbarSeparator: {
    width: StyleSheet.hairlineWidth,
    height: 18,
    backgroundColor: '#D1D5DB',
    marginHorizontal: 4,
  },
  toolbarButton: {
    minWidth: 30,
    height: 26,
    borderRadius: 5,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 4,
  },
  toolbarButtonActive: {
    backgroundColor: '#DBEAFE',
  },
  toolbarButtonText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#374151',
  },
  toolbarButtonTextActive: {
    color: '#2563EB',
  },
  italic: {
    fontStyle: 'italic',
  },
  underline: {
    textDecorationLine: 'underline',
  },
  strikethrough: {
    textDecorationLine: 'line-through',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
    paddingHorizontal: 12,
    paddingTop: 6,
    paddingBottom: 12,
    backgroundColor: '#F9FAFB',
  },
  input: {
    flex: 1,
    minHeight: 32,
    maxHeight: 120,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    fontSize: 14,
    color: '#111827',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
  },
  sendButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: TEAL,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendIcon: {
    color: '#fff',
    fontSize: 12,
    marginLeft: 2,
  },
});
