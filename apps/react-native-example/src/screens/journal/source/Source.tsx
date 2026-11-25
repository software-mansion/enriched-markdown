import {
  createContext,
  useContext,
  useState,
  type ReactElement,
  type ReactNode,
} from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import type {
  MarkdownBlock,
  MarkdownRenderers,
} from 'react-native-enriched-markdown';
import { rendererFor } from '../renderers';
import { FaceHidden } from './face';
import { FONTS, INK_SOFT, accentFor } from '../theme';

// Each renderer's colour, lifted for the dark card.
const TAG_COLORS: Record<string, string> = {
  RailLine: '#8FB4F0',
  Mermaid: '#F29BBE',
  FilmClip: '#B4C3DD',
  Polaroid: '#E2C49F',
  TempleSeal: '#F2957A',
  TrainTicket: '#8FD3BE',
  MapCard: '#E9C27A',
};

const CARD = '#2A211B';

// The block as the answer wrote it. A code block shows its opening fence
// until the closing one arrives, then all of it at once.
function blockSource(block: MarkdownBlock) {
  const title = 'title' in block && block.title ? ` "${block.title}"` : '';
  switch (block.kind) {
    case 'code':
      return block.isComplete
        ? `\`\`\`${block.language}\n${block.code}\n\`\`\``
        : `\`\`\`${block.language}`;
    case 'link':
      return `[${block.label}](${block.url}${title})`;
    case 'image':
      return `![${block.altText}](${block.url}${title})`;
    case 'video':
      return `<video src="${block.url}"></video>`;
  }
}

const ComponentsContext = createContext(true);

// Whether the page shows each block as its component or as its markdown.
export function SourceProvider({
  components,
  children,
}: {
  components: boolean;
  children: ReactNode;
}) {
  return (
    <ComponentsContext.Provider value={components}>
      {children}
    </ComponentsContext.Provider>
  );
}

// One block, either the component it renders as or the markdown it came from.
// Both stay mounted and the block keeps the component's footprint, so
// switching moves nothing on the page: the component holds its place out of
// sight while the markdown card lies over it, cut to the same size.
function Switchable({
  block,
  children,
}: {
  block: MarkdownBlock;
  children: ReactElement;
}) {
  const components = useContext(ComponentsContext);
  return (
    <View>
      <Face shown={components}>{children}</Face>
      <Face shown={!components} overlay>
        <SourceCard block={block} />
      </Face>
    </View>
  );
}

function Face({
  shown,
  overlay = false,
  children,
}: {
  shown: boolean;
  overlay?: boolean;
  children: ReactNode;
}) {
  return (
    <View
      style={[overlay && StyleSheet.absoluteFill, !shown && styles.hidden]}
      pointerEvents={shown ? 'auto' : 'none'}
      importantForAccessibility={shown ? 'auto' : 'no-hide-descendants'}
      accessibilityElementsHidden={!shown}
    >
      <FaceHidden.Provider value={!shown}>{children}</FaceHidden.Provider>
    </View>
  );
}

// The raw markdown on an index card, centred in a dashed outline of the slot
// its component fills, and tagged with the component's name. A source longer
// than the slot fades out at the bottom.
function SourceCard({ block }: { block: MarkdownBlock }) {
  const [room, setRoom] = useState(0);
  const [needed, setNeeded] = useState(0);
  const lines = blockSource(block).split('\n');
  const name = rendererFor(lines[0] ?? '');
  const accent = (name && TAG_COLORS[name]) || '#E9DFCF';
  const slotColor = name ? accentFor(name) : INK_SOFT;
  return (
    <View
      style={[
        styles.slot,
        { borderColor: `${slotColor}73`, backgroundColor: `${slotColor}0D` },
      ]}
    >
      <View style={styles.card}>
        <View
          style={styles.body}
          onLayout={(event) => setRoom(event.nativeEvent.layout.height)}
        >
          <View
            onLayout={(event) => setNeeded(event.nativeEvent.layout.height)}
          >
            {lines.map((line, i) => {
              const fence = line.match(/^(```)(\w*)$/);
              return (
                <Text key={i} style={styles.line}>
                  {fence ? (
                    <>
                      <Text style={styles.dim}>{fence[1]}</Text>
                      <Text style={{ color: accent }}>{fence[2]}</Text>
                    </>
                  ) : (
                    line
                  )}
                </Text>
              );
            })}
          </View>
          {room > 0 && needed > room + 1 && <Fade />}
        </View>
        {name && (
          <Text style={[styles.tag, { color: accent }]}>{`→ <${name} />`}</Text>
        )}
      </View>
    </View>
  );
}

function Fade() {
  return (
    <View style={styles.fade} pointerEvents="none">
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient id="source-fade" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={CARD} stopOpacity={0} />
            <Stop offset="1" stopColor={CARD} stopOpacity={1} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#source-fade)" />
      </Svg>
    </View>
  );
}

// Every renderer, wrapped so its element can switch to its source.
export function switchable(renderers: MarkdownRenderers): MarkdownRenderers {
  const wrap = (block: MarkdownBlock, element: ReactElement | undefined) =>
    element && <Switchable block={block}>{element}</Switchable>;
  return {
    image: (block) => wrap(block, renderers.image?.(block)),
    video: (block) => wrap(block, renderers.video?.(block)),
    link: (block) => wrap(block, renderers.link?.(block)),
    code: (block) => wrap(block, renderers.code?.(block)),
  };
}

const styles = StyleSheet.create({
  hidden: {
    opacity: 0,
  },
  slot: {
    flex: 1,
    justifyContent: 'center',
    marginVertical: 4,
    padding: 10,
    borderRadius: 14,
    borderWidth: 1.5,
    borderStyle: 'dashed',
  },
  card: {
    flexShrink: 1,
    backgroundColor: CARD,
    borderRadius: 10,
    paddingVertical: 12,
    paddingHorizontal: 14,
    overflow: 'hidden',
  },
  body: {
    flexShrink: 1,
    overflow: 'hidden',
  },
  line: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    lineHeight: 18,
    color: '#E9DFCF',
  },
  dim: {
    color: '#8F806F',
  },
  fade: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 48,
  },
  tag: {
    alignSelf: 'flex-end',
    marginTop: 6,
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
  },
});
