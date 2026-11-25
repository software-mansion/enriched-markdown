import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ComponentRef,
} from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Animated, {
  FadeIn,
  FadeInDown,
  FadeOut,
  ZoomIn,
} from 'react-native-reanimated';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import {
  EnrichedMarkdownText,
  type TaskListItemPressEvent,
} from 'react-native-enriched-markdown';
import { closeOpenEmphasis, useDemoStream } from '../shared/useDemoStream';
import {
  CHAT,
  CONTACT,
  FEED,
  JOB_MARKDOWN,
  type ChatMessage,
  type Post,
} from './neonMarkdown';
import {
  FONTS,
  GREEN,
  NIGHT,
  ORANGE,
  PANEL,
  PANEL_HI,
  PINK,
  RULE,
  TEAL,
  TEXT,
  TEXT_SOFT,
  chatMarkdownStyle,
  feedMarkdownStyle,
  jobMarkdownStyle,
  linkRecognition,
} from './theme';

type App = 'chat' | 'job' | 'feed';

const APPS: { key: App; title: string; icon: string; color: string }[] = [
  { key: 'chat', title: 'Texts', icon: '💬', color: TEAL },
  { key: 'job', title: 'Jobs', icon: '🎯', color: PINK },
  { key: 'feed', title: 'Feed', icon: '📸', color: ORANGE },
];

// `$` marks money here, never math; `==x==` is a highlight.
const FLAGS = { latexMath: false, highlight: true };

const TICK_MS = 34;
const TYPING_MS = 1100;

// One token a tick: a whole task marker (`- [ ] `), or a word with its space,
// so a bubble never shows a half-typed checkbox or marker.
function nextToken(text: string, from: number) {
  const rest = text.slice(from);
  const token = rest.match(/^\n?- \[[ x]\] /) ?? rest.match(/^\s*\S+ ?/);
  return from + (token?.[0].length || rest.length);
}

// Plays the thread like a conversation: a typing indicator, then their
// message streams in word by word; yours lands whole.
function useChat(messages: ChatMessage[]) {
  const [shown, setShown] = useState(0);
  const [partial, setPartial] = useState<string | null>(null);
  const [typing, setTyping] = useState(false);
  const [run, setRun] = useState(0);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    let cancelled = false;
    const wait = (ms: number) =>
      new Promise<void>((resolve) => {
        timer = setTimeout(resolve, ms);
      });
    setShown(0);
    setPartial(null);
    setTyping(false);
    (async () => {
      await wait(700);
      for (let i = 0; i < messages.length && !cancelled; i++) {
        const { from, markdown } = messages[i]!;
        if (from === 'me') {
          await wait(900);
          if (cancelled) return;
          setShown(i + 1);
          await wait(500);
          continue;
        }
        setTyping(true);
        await wait(TYPING_MS);
        if (cancelled) return;
        setTyping(false);
        for (let at = 0; at < markdown.length; ) {
          at = nextToken(markdown, at);
          setPartial(closeOpenEmphasis(markdown.slice(0, at)));
          await wait(TICK_MS * 2);
          if (cancelled) return;
        }
        setPartial(null);
        setShown(i + 1);
        await wait(700);
      }
    })();
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [messages, run]);

  const replay = useCallback(() => setRun((value) => value + 1), []);
  return { shown, partial, typing, done: shown === messages.length, replay };
}

export default function NeonPhoneScreen() {
  const insets = useSafeAreaInsets();
  const [app, setApp] = useState<App>('chat');
  // An app mounts the first time it opens and stays, so the chat keeps its
  // place while you read the brief.
  const [opened, setOpened] = useState<Set<App>>(() => new Set(['chat']));
  const [jobSeen, setJobSeen] = useState(false);
  const chat = useChat(CHAT);

  const open = useCallback((next: App) => {
    setApp(next);
    setOpened((prev) => (prev.has(next) ? prev : new Set(prev).add(next)));
    if (next === 'job') setJobSeen(true);
  }, []);

  const current = APPS.find((entry) => entry.key === app)!;

  return (
    <GestureHandlerRootView style={styles.root}>
      <Glow />
      <View style={[styles.header, { paddingTop: insets.top + 6 }]}>
        <Text style={[styles.appTitle, { color: current.color }]}>
          {app === 'chat' ? CONTACT : current.title}
        </Text>
        <Text style={styles.appSub}>
          {app === 'chat'
            ? chat.typing
              ? 'typing…'
              : 'online'
            : app === 'job'
              ? 'tap the boxes as you go'
              : 'Sunset Coast · trending'}
        </Text>
      </View>

      <View style={styles.body}>
        <View style={[styles.fill, app !== 'chat' && styles.hidden]}>
          <ChatApp chat={chat} />
        </View>
        {opened.has('job') && (
          <View style={[styles.fill, app !== 'job' && styles.hidden]}>
            <JobApp />
          </View>
        )}
        {opened.has('feed') && (
          <View style={[styles.fill, app !== 'feed' && styles.hidden]}>
            <FeedApp />
          </View>
        )}
      </View>

      <View style={[styles.dock, { paddingBottom: insets.bottom + 6 }]}>
        <View style={styles.dockRow}>
          {APPS.map((entry) => {
            const badge = entry.key === 'job' && chat.done && !jobSeen;
            const active = entry.key === app;
            return (
              <Pressable
                key={entry.key}
                onPress={() => open(entry.key)}
                testID={`neon-app-${entry.key}`}
                style={styles.dockItem}
              >
                <View
                  style={[
                    styles.icon,
                    { borderColor: active ? entry.color : RULE },
                  ]}
                >
                  <Text style={styles.iconGlyph}>{entry.icon}</Text>
                  {badge && (
                    <Animated.View entering={ZoomIn} style={styles.badge}>
                      <Text style={styles.badgeText}>1</Text>
                    </Animated.View>
                  )}
                </View>
                <Text
                  style={[
                    styles.dockLabel,
                    { color: active ? entry.color : TEXT_SOFT },
                  ]}
                >
                  {entry.title}
                </Text>
              </Pressable>
            );
          })}
        </View>
        <Text style={styles.credit}>
          rendered with react-native-enriched-markdown
        </Text>
      </View>
    </GestureHandlerRootView>
  );
}

// A sunset bleeding down from the top of the screen.
function Glow() {
  return (
    <Svg style={StyleSheet.absoluteFill} pointerEvents="none">
      <Defs>
        <LinearGradient id="sunset" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={ORANGE} stopOpacity={0.35} />
          <Stop offset="0.12" stopColor={PINK} stopOpacity={0.28} />
          <Stop offset="0.32" stopColor="#6B2FB3" stopOpacity={0.18} />
          <Stop offset="0.55" stopColor={NIGHT} stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#sunset)" />
    </Svg>
  );
}

function ChatApp({ chat }: { chat: ReturnType<typeof useChat> }) {
  const scroll = useRef<ComponentRef<typeof ScrollView>>(null);
  return (
    <ScrollView
      ref={scroll}
      contentContainerStyle={styles.chatContent}
      onContentSizeChange={() =>
        scroll.current?.scrollToEnd({ animated: true })
      }
    >
      {CHAT.slice(0, chat.shown).map((message, index) => (
        <Bubble key={index} message={message} />
      ))}
      {chat.partial !== null && (
        <Bubble message={{ from: 'them', markdown: chat.partial }} streaming />
      )}
      {chat.typing && <Typing />}
      {chat.done && (
        <Pressable onPress={chat.replay} style={styles.replay} hitSlop={10}>
          <Text style={styles.replayText}>↻ replay thread</Text>
        </Pressable>
      )}
    </ScrollView>
  );
}

function Bubble({
  message,
  streaming = false,
}: {
  message: ChatMessage;
  streaming?: boolean;
}) {
  const mine = message.from === 'me';
  return (
    <Animated.View
      entering={streaming || mine ? FadeInDown.duration(220) : undefined}
      style={[styles.bubble, mine ? styles.bubbleMine : styles.bubbleTheirs]}
    >
      <EnrichedMarkdownText
        flavor="github"
        markdown={message.markdown}
        markdownStyle={chatMarkdownStyle}
        md4cFlags={FLAGS}
        linkRecognition={linkRecognition}
        spoilerOverlay="solid"
        streamingAnimation={streaming}
        enableTaskListItemToggle={false}
        allowTrailingMargin={false}
      />
    </Animated.View>
  );
}

function Typing() {
  return (
    <Animated.View
      entering={FadeIn.duration(150)}
      exiting={FadeOut.duration(100)}
      style={[styles.bubble, styles.bubbleTheirs, styles.typing]}
    >
      <Text style={styles.typingText}>● ● ●</Text>
    </Animated.View>
  );
}

const TASKS = (JOB_MARKDOWN.match(/^- \[ \]/gm) ?? []).length;

function JobApp() {
  const stream = useDemoStream(
    JOB_MARKDOWN,
    500,
    true,
    'lines',
    undefined,
    'words'
  );
  const [checked, setChecked] = useState<Set<number>>(() => new Set());
  const [banner, setBanner] = useState(false);

  useEffect(() => setChecked(new Set()), [stream.run]);

  const onTask = useCallback((event: TaskListItemPressEvent) => {
    setChecked((prev) => {
      const next = new Set(prev);
      if (event.checked) next.add(event.index);
      else next.delete(event.index);
      if (next.size === TASKS && prev.size < TASKS) setBanner(true);
      return next;
    });
  }, []);

  const replay = useCallback(() => {
    setBanner(false);
    stream.replay();
  }, [stream]);

  return (
    <View style={styles.fill}>
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={styles.jobContent}
      >
        <EnrichedMarkdownText
          key={stream.run}
          flavor="github"
          markdown={stream.markdown}
          markdownStyle={jobMarkdownStyle}
          md4cFlags={FLAGS}
          linkRecognition={linkRecognition}
          spoilerOverlay="solid"
          streamingAnimation={stream.streaming}
          onTaskListItemPress={onTask}
        />
        {!stream.streaming && (
          <Animated.View entering={FadeIn} style={styles.progress}>
            <Text style={styles.progressText}>
              {checked.size}/{TASKS} DONE
            </Text>
            <Pressable onPress={replay} hitSlop={10}>
              <Text style={styles.replayText}>↻ replay brief</Text>
            </Pressable>
          </Animated.View>
        )}
      </Animated.ScrollView>
      {banner && <JobDone onDismiss={() => setBanner(false)} />}
    </View>
  );
}

function JobDone({ onDismiss }: { onDismiss: () => void }) {
  return (
    <Pressable style={styles.bannerWrap} onPress={onDismiss}>
      <Animated.View
        entering={FadeIn.duration(200)}
        style={StyleSheet.absoluteFill}
      >
        <View style={styles.bannerShade} />
      </Animated.View>
      <Animated.View entering={ZoomIn.springify().damping(11)}>
        <Text style={styles.bannerTitle}>JOB DONE</Text>
        <Text style={styles.bannerCash}>+$250,000</Text>
        <Text style={styles.bannerSub}>tap to keep reading</Text>
      </Animated.View>
    </Pressable>
  );
}

function FeedApp() {
  return (
    <ScrollView contentContainerStyle={styles.feedContent}>
      {FEED.map((post, index) => (
        <PostCard key={post.handle} post={post} index={index} />
      ))}
    </ScrollView>
  );
}

function PostCard({ post, index }: { post: Post; index: number }) {
  return (
    <Animated.View
      entering={FadeInDown.delay(index * 120).duration(320)}
      style={styles.post}
    >
      <View style={styles.postHead}>
        <View style={[styles.avatar, { backgroundColor: post.color }]}>
          <Text style={styles.avatarText}>{post.name[0]}</Text>
        </View>
        <View style={styles.fill}>
          <Text style={styles.postName}>{post.name}</Text>
          <Text style={styles.postHandle}>
            {post.handle} · {post.time}
          </Text>
        </View>
      </View>
      <EnrichedMarkdownText
        flavor="github"
        markdown={post.markdown}
        markdownStyle={feedMarkdownStyle}
        md4cFlags={FLAGS}
        linkRecognition={linkRecognition}
        spoilerOverlay="solid"
        allowTrailingMargin={false}
      />
      <Text style={styles.postStats}>♥ {post.likes} · ↻ · ↗</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: NIGHT },
  fill: { flex: 1 },
  hidden: { display: 'none' },
  header: { paddingHorizontal: 20, paddingBottom: 10 },
  appTitle: { fontFamily: FONTS.display, fontSize: 40, lineHeight: 44 },
  appSub: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    color: TEXT_SOFT,
    marginTop: -2,
  },
  body: {
    flex: 1,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: RULE,
  },
  chatContent: { padding: 16, gap: 8 },
  bubble: {
    maxWidth: '80%',
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  bubbleTheirs: {
    alignSelf: 'flex-start',
    backgroundColor: PANEL_HI,
    borderBottomLeftRadius: 4,
  },
  bubbleMine: {
    alignSelf: 'flex-end',
    backgroundColor: '#B0287A',
    borderBottomRightRadius: 4,
  },
  typing: { paddingVertical: 11 },
  typingText: { color: TEXT_SOFT, fontSize: 10, letterSpacing: 2 },
  replay: { alignSelf: 'center', marginTop: 12 },
  replayText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    color: TEXT_SOFT,
    letterSpacing: 1,
  },
  jobContent: { padding: 20, paddingBottom: 40 },
  progress: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
  },
  progressText: { fontFamily: FONTS.display, fontSize: 22, color: TEAL },
  bannerWrap: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bannerShade: { flex: 1, backgroundColor: 'rgba(14, 7, 24, 0.82)' },
  bannerTitle: {
    fontFamily: FONTS.display,
    fontSize: 76,
    lineHeight: 80,
    color: PINK,
    textAlign: 'center',
    textShadowColor: PINK,
    textShadowRadius: 18,
  },
  bannerCash: {
    fontFamily: FONTS.display,
    fontSize: 40,
    color: GREEN,
    textAlign: 'center',
    textShadowColor: GREEN,
    textShadowRadius: 12,
  },
  bannerSub: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    color: TEXT_SOFT,
    textAlign: 'center',
    marginTop: 16,
  },
  feedContent: { padding: 14, gap: 12 },
  post: {
    backgroundColor: PANEL,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: RULE,
    padding: 14,
    gap: 10,
  },
  postHead: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { fontFamily: FONTS.sansBold, color: NIGHT, fontSize: 16 },
  postName: { fontFamily: FONTS.sansBold, color: TEXT, fontSize: 14 },
  postHandle: { fontFamily: FONTS.mono, color: TEXT_SOFT, fontSize: 12 },
  postStats: { fontFamily: FONTS.mono, color: TEXT_SOFT, fontSize: 12 },
  dock: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: RULE,
    backgroundColor: 'rgba(26, 15, 43, 0.96)',
    paddingTop: 10,
  },
  dockRow: { flexDirection: 'row', justifyContent: 'space-evenly' },
  dockItem: { alignItems: 'center', gap: 4 },
  icon: {
    width: 52,
    height: 52,
    borderRadius: 14,
    backgroundColor: PANEL_HI,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconGlyph: { fontSize: 24 },
  badge: {
    position: 'absolute',
    top: -6,
    right: -6,
    minWidth: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: PINK,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: { fontFamily: FONTS.sansBold, fontSize: 11, color: NIGHT },
  dockLabel: { fontFamily: FONTS.sansMedium, fontSize: 11 },
  credit: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    color: TEXT_SOFT,
    textAlign: 'center',
    marginTop: 8,
    opacity: 0.7,
  },
});
