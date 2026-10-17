import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  Animated,
  Image,
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type MarkdownImageBlock,
  type MarkdownLinkBlock,
  type MarkdownRenderers,
  type MarkdownVideoBlock,
} from 'react-native-enriched-markdown';
import { customMarkdownStyle } from '../../markdownStyles';

// The assistant's answer: plain Markdown, the kind an LLM streams. Every block
// below is a URL on a line of its own; the app decides what each one becomes.
const QUESTION =
  'Can you summarise the Q3 numbers and point me at the sources?';

const ANSWER = `Revenue grew **18%** quarter over quarter, mostly on the new enterprise tier. The full breakdown is in the board deck:

[Q3 board deck.pdf](https://files.example.com/q3-board-deck.pdf "2.4 MB")

The growth came from three regions. Here is how they compare:

![Regional growth, Q3](https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&q=70)

Sam walked through the numbers in the all-hands recording, the finance part starts at 12:40:

[All-hands recording, Q3 numbers](https://www.youtube.com/watch?v=dQw4w9WgXcQ)

The Dublin office is the one that drove most of the EMEA number:

[Dublin office on the map](https://www.openstreetmap.org/#map=15/53.3498/-6.2603)

If you want the raw data, the reporting repo has the notebooks:

https://github.com/software-mansion/enriched-markdown

> [!TIP]
> Next quarter's guidance is in the same deck, slide 14.`;

const STREAM_CHUNK = 18;
const STREAM_INTERVAL_MS = 45;

// Advances the stream by a chunk, but delivers a line that holds a URL in one
// piece (as a model emitting a whole token sequence would), so a card never
// waits several ticks behind a half-typed link.
function nextCursor(answer: string, cursor: number): number {
  const next = Math.min(answer.length, cursor + STREAM_CHUNK);
  const lineStart = answer.lastIndexOf('\n', next - 1) + 1;
  const lineEnd = answer.indexOf('\n', next);
  const line = answer.slice(lineStart, lineEnd === -1 ? undefined : lineEnd);
  if (/^(\[|!\[|https?:)/.test(line)) {
    return lineEnd === -1 ? answer.length : lineEnd + 1;
  }
  return next;
}

// Cards land the way the text does: a short fade and lift on mount.
function Reveal({ children }: { children: ReactNode }) {
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(progress, {
      toValue: 1,
      duration: 320,
      useNativeDriver: true,
    }).start();
  }, [progress]);
  return (
    <Animated.View
      style={{
        opacity: progress,
        transform: [
          {
            translateY: progress.interpolate({
              inputRange: [0, 1],
              outputRange: [10, 0],
            }),
          },
        ],
      }}
    >
      {children}
    </Animated.View>
  );
}

function youtubeId(url: string): string | null {
  const match = url.match(/(?:v=|youtu\.be\/)([\w-]{6,})/);
  return match ? match[1]! : null;
}

function osmCenter(url: string): { lat: number; lon: number } | null {
  const match = url.match(/#map=\d+\/(-?[\d.]+)\/(-?[\d.]+)/);
  return match ? { lat: Number(match[1]), lon: Number(match[2]) } : null;
}

function osmTile(lat: number, lon: number, zoom: number) {
  const n = 2 ** zoom;
  const x = Math.floor(((lon + 180) / 360) * n);
  const latRad = (lat * Math.PI) / 180;
  const y = Math.floor(
    ((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) * n
  );
  return `https://tile.openstreetmap.org/${zoom}/${x}/${y}.png`;
}

function open(url: string) {
  Linking.openURL(url).catch(() => {});
}

// ---- the components the assistant's URLs turn into

function FileCard({ block }: { block: MarkdownLinkBlock }) {
  const extension = block.url.split('.').pop()?.toUpperCase() ?? 'FILE';
  return (
    <Pressable style={styles.card} onPress={() => open(block.url)}>
      <View style={styles.fileIcon}>
        <Text style={styles.fileIconText}>{extension}</Text>
      </View>
      <View style={styles.cardBody}>
        <Text style={styles.cardTitle} numberOfLines={1}>
          {block.label || block.url}
        </Text>
        <Text style={styles.cardMeta}>{block.title || 'Tap to open'}</Text>
      </View>
      <Text style={styles.cardAction}>Open</Text>
    </Pressable>
  );
}

function YouTubeCard({ block, id }: { block: MarkdownLinkBlock; id: string }) {
  const [playing, setPlaying] = useState(false);
  return (
    <Pressable
      style={styles.player}
      onPress={() => (playing ? open(block.url) : setPlaying(true))}
    >
      <Image
        source={{ uri: `https://img.youtube.com/vi/${id}/hqdefault.jpg` }}
        style={styles.playerImage}
      />
      <View style={styles.playerOverlay}>
        {playing ? (
          <ActivityIndicator color="#FFFFFF" />
        ) : (
          <View style={styles.playButton}>
            <Text style={styles.playGlyph}>▶</Text>
          </View>
        )}
      </View>
      <View style={styles.playerFooter}>
        <Text style={styles.playerSource}>YouTube</Text>
        <Text style={styles.playerTitle} numberOfLines={1}>
          {block.label || 'All-hands, Q3 numbers'}
        </Text>
      </View>
    </Pressable>
  );
}

function MapCard({
  block,
  lat,
  lon,
}: {
  block: MarkdownLinkBlock;
  lat: number;
  lon: number;
}) {
  return (
    <Pressable style={styles.map} onPress={() => open(block.url)}>
      <Image source={{ uri: osmTile(lat, lon, 14) }} style={styles.mapTile} />
      <View style={styles.pin} />
      <View style={styles.mapFooter}>
        <Text style={styles.mapTitle}>Dublin office</Text>
        <Text
          style={styles.cardMeta}
        >{`${lat.toFixed(4)}, ${lon.toFixed(4)}`}</Text>
      </View>
    </Pressable>
  );
}

function RepoCard({ block }: { block: MarkdownLinkBlock }) {
  const [repo, setRepo] = useState<{
    description: string;
    stars: number;
    language: string;
  } | null>(null);
  const path = block.url.replace('https://github.com/', '');
  useEffect(() => {
    let cancelled = false;
    fetch(`https://api.github.com/repos/${path}`)
      .then((response) => response.json())
      .then((json) => {
        if (cancelled || typeof json?.stargazers_count !== 'number') return;
        setRepo({
          description: json.description ?? '',
          stars: json.stargazers_count,
          language: json.language ?? '',
        });
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [path]);
  return (
    <Pressable style={styles.card} onPress={() => open(block.url)}>
      <View style={[styles.fileIcon, styles.repoIcon]}>
        <Text style={styles.fileIconText}>GH</Text>
      </View>
      <View style={styles.cardBody}>
        <Text style={styles.cardTitle} numberOfLines={1}>
          {path}
        </Text>
        <Text style={styles.cardMeta} numberOfLines={2}>
          {repo
            ? `★ ${repo.stars.toLocaleString()} · ${repo.language}${repo.description ? ` · ${repo.description}` : ''}`
            : 'Loading repository…'}
        </Text>
      </View>
    </Pressable>
  );
}

function LinkPreview({ block }: { block: MarkdownLinkBlock }) {
  const host = block.url.replace(/^https?:\/\//, '').split('/')[0] ?? '';
  return (
    <Pressable style={styles.card} onPress={() => open(block.url)}>
      <Image
        source={{
          uri: `https://www.google.com/s2/favicons?domain=${host}&sz=64`,
        }}
        style={styles.favicon}
      />
      <View style={styles.cardBody}>
        <Text style={styles.cardTitle} numberOfLines={1}>
          {block.label || host}
        </Text>
        <Text style={styles.cardMeta} numberOfLines={1}>
          {host}
        </Text>
      </View>
    </Pressable>
  );
}

function Figure({ block }: { block: MarkdownImageBlock }) {
  const [loaded, setLoaded] = useState(false);
  return (
    <View style={styles.figure}>
      <Image
        source={{ uri: block.url }}
        style={styles.figureImage}
        onLoad={() => setLoaded(true)}
      />
      {!loaded && (
        <ActivityIndicator style={styles.figureSpinner} color="#5856D6" />
      )}
      <Text style={styles.figureCaption}>{block.altText}</Text>
    </View>
  );
}

function VideoCard({ block }: { block: MarkdownVideoBlock }) {
  return (
    <Pressable style={styles.player} onPress={() => open(block.url)}>
      <View style={[styles.playerImage, styles.playerDark]} />
      <View style={styles.playerOverlay}>
        <View style={styles.playButton}>
          <Text style={styles.playGlyph}>▶</Text>
        </View>
      </View>
    </Pressable>
  );
}

// One `link` renderer, five components: the URL decides.
function linkCard(block: MarkdownLinkBlock) {
  const url = block.url;
  const video = youtubeId(url);
  if (video) return <YouTubeCard block={block} id={video} />;
  const map = osmCenter(url);
  if (map) return <MapCard block={block} lat={map.lat} lon={map.lon} />;
  if (/^https:\/\/github\.com\/[^/]+\/[^/]+\/?$/.test(url))
    return <RepoCard block={block} />;
  if (/\.(pdf|docx?|xlsx?|pptx?|zip|csv)$/i.test(url))
    return <FileCard block={block} />;
  return <LinkPreview block={block} />;
}

function renderLink(block: MarkdownLinkBlock) {
  return <Reveal>{linkCard(block)}</Reveal>;
}

export default function AssistantScreen() {
  const [shown, setShown] = useState(0);
  const [richBlocks, setRichBlocks] = useState(true);
  const scrollRef = useRef<ScrollView>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  const stop = useCallback(() => {
    if (timer.current) clearInterval(timer.current);
    timer.current = null;
  }, []);

  const replay = useCallback(() => {
    stop();
    setShown(0);
    timer.current = setInterval(() => {
      setShown((value) => {
        const next = nextCursor(ANSWER, value);
        if (next >= ANSWER.length) stop();
        return next;
      });
    }, STREAM_INTERVAL_MS);
  }, [stop]);

  useEffect(() => {
    const start = setTimeout(replay, 600);
    return () => {
      clearTimeout(start);
      stop();
    };
  }, [replay, stop]);

  const streaming = shown < ANSWER.length;
  const markdown = ANSWER.slice(0, shown);

  const renderers = useMemo<MarkdownRenderers | undefined>(
    () =>
      richBlocks
        ? {
            link: renderLink,
            image: (block) => (
              <Reveal>
                <Figure block={block} />
              </Reveal>
            ),
            video: (block) => (
              <Reveal>
                <VideoCard block={block} />
              </Reveal>
            ),
          }
        : undefined,
    [richBlocks]
  );

  return (
    <View style={styles.screen}>
      <ScrollView
        ref={scrollRef}
        style={styles.scroll}
        contentContainerStyle={styles.content}
        // Follow the tail smoothly while streaming; a card landing is a big
        // size step, and an animated scroll turns it into a glide, not a jump.
        onContentSizeChange={() =>
          streaming && scrollRef.current?.scrollToEnd({ animated: true })
        }
        testID="assistant-screen"
      >
        <View style={styles.userBubble}>
          <Text style={styles.userText}>{QUESTION}</Text>
        </View>
        <View style={styles.assistantRow}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>AI</Text>
          </View>
          <View style={styles.assistantBubble}>
            {shown === 0 ? (
              <ActivityIndicator color="#5856D6" />
            ) : (
              <EnrichedMarkdownText
                flavor="github"
                markdown={markdown}
                markdownStyle={customMarkdownStyle}
                renderers={renderers}
                streamingAnimation={streaming}
                onLinkPress={({ url }) => open(url)}
              />
            )}
          </View>
        </View>
      </ScrollView>
      <View style={styles.toolbar}>
        <View style={styles.toggle}>
          <Text style={styles.toggleLabel}>Rich blocks</Text>
          <Switch value={richBlocks} onValueChange={setRichBlocks} />
        </View>
        <Pressable
          style={styles.replay}
          onPress={replay}
          testID="assistant-replay"
        >
          <Text style={styles.replayText}>
            {streaming ? 'Streaming…' : 'Replay'}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#F2F2F7' },
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 32, gap: 16 },
  userBubble: {
    alignSelf: 'flex-end',
    maxWidth: '82%',
    backgroundColor: '#5856D6',
    borderRadius: 20,
    borderBottomRightRadius: 6,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  userText: { color: '#FFFFFF', fontSize: 16, lineHeight: 22 },
  assistantRow: { flexDirection: 'row', gap: 10, alignItems: 'flex-start' },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#BEEBD0',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  avatarText: { color: '#001A72', fontWeight: '700', fontSize: 12 },
  assistantBubble: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    borderTopLeftRadius: 6,
    padding: 14,
    minHeight: 48,
    justifyContent: 'center',
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: '#F7F7FA',
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D9D9E3',
    padding: 12,
  },
  cardBody: { flex: 1, gap: 2 },
  cardTitle: { color: '#1C1C1E', fontSize: 15, fontWeight: '600' },
  cardMeta: { color: '#6E6E73', fontSize: 13 },
  cardAction: { color: '#5856D6', fontSize: 15, fontWeight: '600' },
  fileIcon: {
    width: 44,
    height: 44,
    borderRadius: 10,
    backgroundColor: '#E5484D',
    alignItems: 'center',
    justifyContent: 'center',
  },
  repoIcon: { backgroundColor: '#24292F' },
  fileIconText: { color: '#FFFFFF', fontWeight: '800', fontSize: 12 },
  favicon: { width: 36, height: 36, borderRadius: 8 },
  player: {
    borderRadius: 14,
    overflow: 'hidden',
    backgroundColor: '#000000',
  },
  playerImage: { width: '100%', aspectRatio: 16 / 9 },
  playerDark: { backgroundColor: '#1C1C1E' },
  playerOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  playButton: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: 'rgba(255,255,255,0.92)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  playGlyph: { color: '#1C1C1E', fontSize: 24, marginLeft: 4 },
  playerFooter: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    padding: 10,
    backgroundColor: 'rgba(0,0,0,0.55)',
  },
  playerSource: { color: '#FF3B30', fontSize: 11, fontWeight: '700' },
  playerTitle: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  map: {
    borderRadius: 14,
    overflow: 'hidden',
    backgroundColor: '#E8EEF2',
  },
  mapTile: { width: '100%', aspectRatio: 2, resizeMode: 'cover' },
  pin: {
    position: 'absolute',
    left: '50%',
    top: '50%',
    width: 18,
    height: 18,
    marginLeft: -9,
    marginTop: -22,
    borderRadius: 9,
    backgroundColor: '#FF3B30',
    borderWidth: 3,
    borderColor: '#FFFFFF',
  },
  mapFooter: { padding: 10, backgroundColor: '#FFFFFF' },
  mapTitle: { color: '#1C1C1E', fontSize: 15, fontWeight: '600' },
  figure: { borderRadius: 14, overflow: 'hidden', backgroundColor: '#E5E5EA' },
  figureImage: { width: '100%', aspectRatio: 16 / 10 },
  figureSpinner: { position: 'absolute', alignSelf: 'center', top: '45%' },
  figureCaption: {
    color: '#FFFFFF',
    backgroundColor: '#1C1C1E',
    fontSize: 13,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    paddingBottom: 28,
    backgroundColor: '#FFFFFF',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#D9D9E3',
  },
  toggle: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  toggleLabel: { color: '#1C1C1E', fontSize: 15, fontWeight: '600' },
  replay: {
    backgroundColor: '#5856D6',
    borderRadius: 20,
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  replayText: { color: '#FFFFFF', fontWeight: '600' },
});
