import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Image,
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
  type MarkdownImageOccurrence,
  type MarkdownRenderers,
  type MarkdownVideoBlock,
} from 'react-native-enriched-markdown';
import { customMarkdownStyle } from '../../markdownStyles';

const FOREST =
  'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800';
const LEAF =
  'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=80&h=80&fit=crop';
const PATH =
  'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400';
const VALLEY =
  'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800';
const LAKE =
  'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800';
const TALL =
  'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=400';
const BUNNY =
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
const ELEPHANTS =
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
const SINTEL =
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4';

const HERO = `![Misty forest at sunrise](${FOREST} "Forest")`;

// Every placement a renderer can see, every placement that must stay native,
// and the identity edge cases, in one document.
const buildMarkdown = (withHero: boolean) => `# Custom block renderers

${withHero ? HERO : '*Hero image removed.*'}

The image above is a paragraph of its own. The inline ![leaf](${LEAF}) image, the list image, the linked image, the table image and the heading image below all stay native:

- ![list](${PATH})

[![linked](${PATH})](https://example.com)

| Cell |
| --- |
| ![cell](${LEAF}) |

### Heading ![leaf](${LEAF}) image

\`\`\`md
![not an image, just code](${FOREST})
\`\`\`

## Same URL twice

![First copy](${LAKE})

![Second copy](${LAKE})

## Quotes and admonitions

> ![Quoted](${VALLEY})
>
> > ![Nested quote](${PATH})
>
> Standalone images inside quotes are replaced, at the quote's inner width.

> [!TIP]
> ![Admonition image](${LAKE})
>
> <video src="${BUNNY}"></video>

## Height that settles after load

![Natural size](${TALL})

## Videos

<video src="${ELEPHANTS}"></video>

> <video src="${SINTEL}"></video>

- <video src="${BUNNY}"></video>

The paragraph after the videos keeps flowing natively, and the last block is a video:

<video src="${SINTEL}"></video>
`;

type SourceMode = 'off' | 'signed' | 'pending' | 'reject';

function Figure({
  block,
  onPress,
}: {
  block: MarkdownImageBlock;
  onPress: (block: MarkdownImageBlock) => void;
}) {
  const [loaded, setLoaded] = useState(false);
  const index = block.id.slice(block.id.lastIndexOf(':') + 1);
  return (
    <Pressable
      style={styles.figure}
      onPress={() => onPress(block)}
      accessibilityRole="image"
      accessibilityLabel={block.altText}
      testID={`renderer-image-${block.placement}-${index}`}
    >
      <Image
        source={{ uri: block.url }}
        style={styles.image}
        onLoad={() => setLoaded(true)}
      />
      {!loaded && <ActivityIndicator style={styles.spinner} color="#FFFFFF" />}
      <View style={styles.captionRow}>
        <Text style={styles.caption} numberOfLines={1}>
          {block.title || block.altText}
        </Text>
        <Text style={styles.badge}>{`${block.placement} #${index}`}</Text>
      </View>
    </Pressable>
  );
}

// Starts at a guessed height and settles on the image's real aspect ratio once
// it loads, so the blocks after it have to move.
function NaturalImage({ block }: { block: MarkdownImageBlock }) {
  const [aspectRatio, setAspectRatio] = useState(16 / 9);
  useEffect(() => {
    let cancelled = false;
    Image.getSize(
      block.url,
      (width, height) => {
        if (!cancelled && width > 0 && height > 0)
          setAspectRatio(width / height);
      },
      () => {}
    );
    return () => {
      cancelled = true;
    };
  }, [block.url]);
  return (
    <View style={styles.natural} testID="renderer-image-natural">
      <Image
        source={{ uri: block.url }}
        style={[styles.image, { aspectRatio }]}
      />
      <Text style={styles.caption}>
        {aspectRatio === 16 / 9
          ? 'measuring…'
          : `aspect ${aspectRatio.toFixed(2)}`}
      </Text>
    </View>
  );
}

function VideoCard({ block }: { block: MarkdownVideoBlock }) {
  const [tall, setTall] = useState(false);
  const index = block.id.slice(block.id.lastIndexOf(':') + 1);
  return (
    <Pressable
      style={[styles.video, tall && styles.videoTall]}
      onPress={() => setTall((value) => !value)}
      testID={`renderer-video-${block.placement}-${index}`}
    >
      <Text style={styles.videoTitle}>▶ Custom player</Text>
      <Text style={styles.videoUrl} numberOfLines={1}>
        {block.url}
      </Text>
      <Text style={styles.videoHint}>
        {`${block.placement} #${index} · tap to ${tall ? 'shrink' : 'grow'}`}
      </Text>
    </Pressable>
  );
}

const STREAM_CHUNK = 48;
const STREAM_INTERVAL_MS = 120;

export default function RenderersScreen() {
  const markdownStyle = useMemo(() => customMarkdownStyle, []);
  const [replaceImages, setReplaceImages] = useState(true);
  const [replaceVideos, setReplaceVideos] = useState(true);
  const [skipQuoted, setSkipQuoted] = useState(false);
  const [withHero, setWithHero] = useState(true);
  const [trailingMargin, setTrailingMargin] = useState(false);
  const [hideStreamingMedia, setHideStreamingMedia] = useState(true);
  const [sourceMode, setSourceMode] = useState<SourceMode>('off');
  const [lastPressed, setLastPressed] = useState<string | null>(null);

  const fullMarkdown = useMemo(() => buildMarkdown(withHero), [withHero]);
  const [streamed, setStreamed] = useState<string | null>(null);
  const streamTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopStreaming = useCallback(() => {
    if (streamTimer.current) clearInterval(streamTimer.current);
    streamTimer.current = null;
  }, []);

  const startStreaming = useCallback(() => {
    stopStreaming();
    let shown = 0;
    setStreamed('');
    streamTimer.current = setInterval(() => {
      shown = Math.min(fullMarkdown.length, shown + STREAM_CHUNK);
      setStreamed(fullMarkdown.slice(0, shown));
      if (shown >= fullMarkdown.length) {
        stopStreaming();
        setStreamed(null);
      }
    }, STREAM_INTERVAL_MS);
  }, [fullMarkdown, stopStreaming]);

  // The button's stop: the full document comes back and the run can restart.
  const cancelStreaming = useCallback(() => {
    stopStreaming();
    setStreamed(null);
  }, [stopStreaming]);

  useEffect(() => stopStreaming, [stopStreaming]);

  const onImagePress = useCallback(
    (block: MarkdownImageBlock) =>
      setLastPressed(`${block.altText} (${block.id})`),
    []
  );

  const renderers = useMemo<MarkdownRenderers>(
    () => ({
      image: replaceImages
        ? (block) => {
            if (skipQuoted && block.placement === 'blockquote') return null;
            if (block.altText === 'Natural size')
              return <NaturalImage block={block} />;
            return <Figure block={block} onPress={onImagePress} />;
          }
        : undefined,
      video: replaceVideos ? (block) => <VideoCard block={block} /> : undefined,
    }),
    [replaceImages, replaceVideos, skipQuoted, onImagePress]
  );

  const resolveImageSource = useMemo(() => {
    switch (sourceMode) {
      case 'signed':
        // A token exchange: every image is fetched through a signed request.
        return async (image: MarkdownImageOccurrence) => {
          await new Promise((resolve) => setTimeout(resolve, 400));
          return {
            uri: `${image.url}${image.url.includes('?') ? '&' : '?'}sig=demo`,
            headers: { 'X-Demo-Token': image.id },
          };
        };
      case 'pending':
        // Never settles: every image keeps its placeholder and nothing is requested.
        return () => new Promise<null>(() => {});
      case 'reject':
        // Inline and list images fail; block images load their Markdown URL.
        return (image: MarkdownImageOccurrence) =>
          image.placement === 'inline' || image.placement === 'list'
            ? Promise.reject(new Error(`no source for ${image.id}`))
            : null;
      default:
        return undefined;
    }
  }, [sourceMode]);

  const streaming = streamed !== null;

  return (
    <ScrollView
      style={styles.scrollView}
      contentContainerStyle={styles.content}
      testID="renderers-screen"
    >
      <View style={styles.controls}>
        <Toggle
          label="Replace images"
          value={replaceImages}
          onValueChange={setReplaceImages}
        />
        <Toggle
          label="Replace videos"
          value={replaceVideos}
          onValueChange={setReplaceVideos}
        />
        <Toggle
          label="Keep quoted images native"
          value={skipQuoted}
          onValueChange={setSkipQuoted}
        />
        <Toggle
          label="Hero image in document"
          value={withHero}
          onValueChange={setWithHero}
        />
        <Toggle
          label="Trailing margin"
          value={trailingMargin}
          onValueChange={setTrailingMargin}
        />
        <Toggle
          label="Hide media while streaming"
          value={hideStreamingMedia}
          onValueChange={setHideStreamingMedia}
        />
        <View style={styles.row}>
          <Text style={styles.toggleLabel}>Image source</Text>
          <View style={styles.segments}>
            {(['off', 'signed', 'pending', 'reject'] as const).map((mode) => (
              <Pressable
                key={mode}
                onPress={() => setSourceMode(mode)}
                style={[
                  styles.segment,
                  sourceMode === mode && styles.segmentOn,
                ]}
                testID={`source-${mode}`}
              >
                <Text
                  style={[
                    styles.segmentText,
                    sourceMode === mode && styles.segmentTextOn,
                  ]}
                >
                  {mode}
                </Text>
              </Pressable>
            ))}
          </View>
        </View>
        <Pressable
          onPress={streaming ? cancelStreaming : startStreaming}
          style={styles.streamButton}
          testID="stream-button"
        >
          <Text style={styles.streamButtonText}>
            {streaming
              ? `Streaming… ${streamed.length}/${fullMarkdown.length}`
              : 'Stream the document'}
          </Text>
        </Pressable>
        <Text style={styles.status} testID="renderer-status">
          {lastPressed ? `Pressed: ${lastPressed}` : 'Tap a replaced image.'}
        </Text>
      </View>
      <EnrichedMarkdownText
        // resolveImageSource is read once per image for the component's lifetime;
        // switching modes remounts so every image is asked again.
        key={sourceMode}
        flavor="github"
        markdown={streamed ?? fullMarkdown}
        markdownStyle={markdownStyle}
        renderers={renderers}
        resolveImageSource={resolveImageSource}
        streamingAnimation={streaming}
        streamingConfig={{
          mediaMode: hideStreamingMedia ? 'hidden' : 'progressive',
        }}
        allowTrailingMargin={trailingMargin}
        onImagePress={({ url, altText }) =>
          setLastPressed(`${altText || url} (native)`)
        }
      />
      <View style={styles.footer} testID="renderers-footer">
        <Text style={styles.footerText}>End of document</Text>
      </View>
    </ScrollView>
  );
}

function Toggle({
  label,
  value,
  onValueChange,
}: {
  label: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
}) {
  return (
    <View style={styles.row}>
      <Text style={styles.toggleLabel}>{label}</Text>
      <Switch value={value} onValueChange={onValueChange} />
    </View>
  );
}

const styles = StyleSheet.create({
  scrollView: { paddingHorizontal: 16 },
  content: { paddingVertical: 16 },
  controls: {
    gap: 8,
    marginBottom: 16,
    padding: 12,
    borderRadius: 12,
    backgroundColor: '#F2F4F7',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  toggleLabel: { fontSize: 15, color: '#001A72' },
  segments: { flexDirection: 'row', gap: 4 },
  segment: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    backgroundColor: '#E4E7EC',
  },
  segmentOn: { backgroundColor: '#001A72' },
  segmentText: { fontSize: 12, color: '#001A72' },
  segmentTextOn: { color: '#FFFFFF' },
  streamButton: {
    alignItems: 'center',
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: '#BEEBD0',
  },
  streamButtonText: { color: '#001A72', fontWeight: '600' },
  status: { fontSize: 13, color: '#5B6478', fontStyle: 'italic' },
  figure: {
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#101828',
  },
  natural: {
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#1F2A44',
  },
  image: { width: '100%', aspectRatio: 16 / 9 },
  spinner: { position: 'absolute', top: 0, right: 0, bottom: 40, left: 0 },
  captionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  caption: { flex: 1, color: '#E4E7EC', fontSize: 13, padding: 0 },
  badge: {
    color: '#101828',
    backgroundColor: '#BEEBD0',
    fontSize: 11,
    fontWeight: '600',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
    textTransform: 'uppercase',
  },
  video: {
    borderRadius: 12,
    padding: 16,
    backgroundColor: '#001A72',
    gap: 4,
  },
  videoTall: { paddingVertical: 48 },
  videoTitle: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  videoUrl: { color: '#BEEBD0', fontSize: 12 },
  videoHint: { color: '#C7CBE0', fontSize: 12 },
  footer: {
    marginTop: 8,
    padding: 12,
    borderRadius: 8,
    backgroundColor: '#F2F4F7',
    alignItems: 'center',
  },
  footerText: { color: '#5B6478', fontSize: 12 },
});
