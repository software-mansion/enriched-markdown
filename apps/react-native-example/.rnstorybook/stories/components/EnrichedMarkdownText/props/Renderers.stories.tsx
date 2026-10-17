import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  ActivityIndicator,
  Image,
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type MarkdownImageBlock,
  type MarkdownImageOccurrence,
  type MarkdownLinkBlock,
  type MarkdownRenderers,
  type MarkdownVideoBlock,
} from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';
import { customMarkdownStyle } from '../../../../../src/markdownStyles';

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

// Every placement a renderer can see, every placement that must stay native,
// and the identity edge cases, in one document.
const MARKDOWN = `# Custom block renderers

![Misty forest at sunrise](${FOREST} "Forest")

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

// A link on a line of its own is a block too; an assistant's answer is full of them.
const LINKS_MARKDOWN = `Revenue grew **18%** quarter over quarter. The full breakdown is in the board deck:

[Q3 board deck](https://example.com/finance/q3-board-deck.pdf "12 pages")

The parser that produced these numbers lives here:

https://github.com/software-mansion/enriched-markdown

A link with prose around it stays an inline link: see [the docs](https://docs.swmansion.com/enriched-markdown) for the API.

<https://reactnative.dev>
`;

type SourceMode = 'off' | 'signed' | 'pending' | 'reject';
type MediaMode = 'progressive' | 'hidden';

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

// A file gets its extension, a repository its path, anything else its host.
function LinkCard({ block }: { block: MarkdownLinkBlock }) {
  const index = block.id.slice(block.id.lastIndexOf(':') + 1);
  const host = block.url.replace(/^https?:\/\//, '').split('/')[0] ?? '';
  const file = /\.(pdf|docx?|xlsx?|pptx?|zip|csv)$/i.exec(block.url)?.[1];
  const repo = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/?$/.exec(
    block.url
  )?.[1];
  return (
    <Pressable
      style={styles.card}
      onPress={() => Linking.openURL(block.url).catch(() => {})}
      testID={`renderer-link-${block.placement}-${index}`}
    >
      <View style={styles.cardIcon}>
        <Text style={styles.cardIconText}>
          {file ? file.toUpperCase() : repo ? 'GH' : 'WWW'}
        </Text>
      </View>
      <View style={styles.cardBody}>
        <Text style={styles.cardTitle} numberOfLines={1}>
          {block.label || repo || host}
        </Text>
        <Text style={styles.cardMeta} numberOfLines={1}>
          {block.title || block.url}
        </Text>
      </View>
    </Pressable>
  );
}

const STREAM_CHUNK = 48;
const STREAM_INTERVAL_MS = 120;

type RenderersControls = {
  replaceImages: boolean;
  replaceVideos: boolean;
  replaceLinks: boolean;
  keepQuotedNative: boolean;
  mediaMode: MediaMode;
  sourceMode: SourceMode;
  allowTrailingMargin: boolean;
};

const defaultControls: RenderersControls = {
  replaceImages: true,
  replaceVideos: true,
  replaceLinks: true,
  keepQuotedNative: false,
  mediaMode: 'hidden',
  sourceMode: 'off',
  allowTrailingMargin: false,
};

function RenderersStory({
  title,
  description,
  markdown: fullMarkdown,
  replaceImages,
  replaceVideos,
  replaceLinks,
  keepQuotedNative,
  mediaMode,
  sourceMode,
  allowTrailingMargin,
}: RenderersControls & {
  title: string;
  description: string;
  markdown: string;
}) {
  const [lastPressed, setLastPressed] = useState<string | null>(null);
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
            if (keepQuotedNative && block.placement === 'blockquote')
              return null;
            if (block.altText === 'Natural size')
              return <NaturalImage block={block} />;
            return <Figure block={block} onPress={onImagePress} />;
          }
        : undefined,
      video: replaceVideos ? (block) => <VideoCard block={block} /> : undefined,
      link: replaceLinks ? (block) => <LinkCard block={block} /> : undefined,
    }),
    [replaceImages, replaceVideos, replaceLinks, keepQuotedNative, onImagePress]
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
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
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
      <EnrichedMarkdownText
        // resolveImageSource is read once per image for the component's lifetime;
        // switching modes remounts so every image is asked again.
        key={sourceMode}
        flavor="github"
        markdown={streamed ?? fullMarkdown}
        markdownStyle={customMarkdownStyle}
        renderers={renderers}
        resolveImageSource={resolveImageSource}
        streamingAnimation={streaming}
        streamingConfig={{ mediaMode }}
        allowTrailingMargin={allowTrailingMargin}
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

const argTypes = {
  replaceImages: {
    control: { type: 'boolean' as const },
    description: 'renderers.image set',
  },
  replaceVideos: {
    control: { type: 'boolean' as const },
    description: 'renderers.video set',
  },
  replaceLinks: {
    control: { type: 'boolean' as const },
    description: 'renderers.link set',
  },
  keepQuotedNative: {
    control: { type: 'boolean' as const },
    description: 'renderers.image returns null for blockquote placements',
  },
  mediaMode: {
    options: ['progressive', 'hidden'] as const,
    control: { type: 'select' as const },
    description: 'streamingConfig.mediaMode while the stream button runs',
  },
  sourceMode: {
    options: ['off', 'signed', 'pending', 'reject'] as const,
    control: { type: 'select' as const },
    description:
      'resolveImageSource: off, a signed URL after 400ms, never settles, or rejects inline and list images',
  },
  allowTrailingMargin: {
    control: { type: 'boolean' as const },
    description: 'allowTrailingMargin',
  },
};

export default storyMeta('Props', 'Renderers');

export const Default: TextStory<RenderersControls> = {
  args: { markdown: MARKDOWN, ...defaultControls },
  argTypes,
  render: ({ markdown, ...controls }) => (
    <RenderersStory
      title="Custom block renderers"
      description="renderers.image and renderers.video replace standalone images and video blocks with React components, placed where the native layout reserved space. Stream the document to see blocks arrive."
      markdown={markdown}
      {...(controls as RenderersControls)}
    />
  ),
};

export const LinkCards: TextStory<RenderersControls> = {
  args: { markdown: LINKS_MARKDOWN, ...defaultControls },
  argTypes,
  render: ({ markdown, ...controls }) => (
    <RenderersStory
      title="Link cards"
      description="renderers.link replaces a link that stands alone in a paragraph: a bracketed link, an autolink or a bare URL. Links inside prose stay inline."
      markdown={markdown}
      {...(controls as RenderersControls)}
    />
  ),
};

export const ResolvedSources: TextStory<RenderersControls> = {
  args: {
    markdown: MARKDOWN,
    ...defaultControls,
    replaceImages: false,
    sourceMode: 'signed',
  },
  argTypes,
  render: ({ markdown, ...controls }) => (
    <RenderersStory
      title="Resolved image sources"
      description="resolveImageSource decides what every image, native or replaced, loads: a signed URL with headers, a pending placeholder, or a rejection that keeps the placeholder."
      markdown={markdown}
      {...(controls as RenderersControls)}
    />
  ),
};

const styles = StyleSheet.create({
  scrollView: { paddingHorizontal: 16 },
  content: { paddingVertical: 16, gap: 8 },
  title: { fontSize: 20, fontWeight: '700' },
  description: { fontSize: 14, color: '#555' },
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
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 12,
    borderRadius: 12,
    backgroundColor: '#F2F4F7',
  },
  cardIcon: {
    width: 44,
    height: 44,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#001A72',
  },
  cardIconText: { color: '#FFFFFF', fontSize: 11, fontWeight: '700' },
  cardBody: { flex: 1, gap: 2 },
  cardTitle: { color: '#101828', fontSize: 15, fontWeight: '600' },
  cardMeta: { color: '#5B6478', fontSize: 12 },
  footer: {
    marginTop: 8,
    padding: 12,
    borderRadius: 8,
    backgroundColor: '#F2F4F7',
    alignItems: 'center',
  },
  footerText: { color: '#5B6478', fontSize: 13 },
});
