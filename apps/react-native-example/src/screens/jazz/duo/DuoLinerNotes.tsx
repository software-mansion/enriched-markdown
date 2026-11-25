import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ComponentRef,
} from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { useNavigation, type ParamListBase } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useDemoStream } from '../../shared/useDemoStream';
import { AnchorProvider } from '../anchors';
import type { TrackId } from '../audio/harmony';
import type { Hinge } from '../../shared/hinge';
import {
  FollowPill,
  LinerNotes,
  Prompt,
  RunOut,
  Spotlight,
} from '../LinerNotesScreen';
import { LINER_NOTES_MARKDOWN } from '../linerNotesMarkdown';
import { usePlayer } from '../player';
import { linerNotesRenderers } from '../renderers';
import { BRASS, NIGHT, linerMarkdownStyle, linerSelection } from '../theme';
import { LabelMark } from '../LabelMark';
import { Cover } from './Cover';
import { Jukebox, SELECTIONS } from './Jukebox';
import { Source } from './Source';

// The iPhone Duo as a gatefold sleeve: folded it is the front cover, opened
// the notes run down the left page and the records sit on the right.
export function DuoLinerNotes({ hinge }: { hinge: Hinge }) {
  const [readFolded, setReadFolded] = useState(false);
  useEffect(() => {
    if (!hinge.closed) setReadFolded(false);
  }, [hinge.closed]);

  // Closing the sleeve lifts the needle, whatever was playing.
  const { stop } = usePlayer();
  useEffect(() => {
    if (hinge.closed) stop();
  }, [hinge.closed, stop]);

  // The sleeve runs edge to edge, with no clock over the cover or the pages.
  const navigation = useNavigation<NativeStackNavigationProp<ParamListBase>>();
  useEffect(() => {
    navigation.setOptions({ statusBarHidden: true });
  }, [navigation]);

  if (!hinge.closed) return <Spread open={hinge.open} />;
  if (readFolded) return <LinerNotes />;
  return <Cover onRead={() => setReadFolded(true)} />;
}

// Opening the sleeve, the answer takes a moment, as if it were being fetched.
const THINKING_MS = 1500;
// A card scrolled to sits this far below the top of the page.
const JUMP_MARGIN = 20;

function Spread({ open }: { open: Hinge['open'] }) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const player = usePlayer();
  const stream = useDemoStream(LINER_NOTES_MARKDOWN, THINKING_MS);
  const { setAutoCue, stop, toggle } = player;
  const { replay: replayStream, jump } = stream;
  // A replay cues its first record again.
  useEffect(
    () => setAutoCue(stream.streaming),
    [setAutoCue, stream.streaming, stream.run]
  );
  const replay = useCallback(() => {
    stop();
    replayStream();
  }, [stop, replayStream]);

  const [anchors] = useState(() => new Map());
  const notes = useRef<ComponentRef<typeof View>>(null);
  const notesTop = useRef(0);
  const select = useCallback(
    (track: TrackId) => {
      const card = anchors.get(track)?.current;
      if (card && notes.current) {
        card.measureLayout(notes.current, (_x: number, y: number) =>
          jump(Math.max(0, notesTop.current + y - JUMP_MARGIN))
        );
      }
      toggle(track);
    },
    [anchors, jump, toggle]
  );

  // The right page opens on the answer's markdown, to see what each card
  // was; the records are a tap away.
  const [showSource, setShowSource] = useState(true);
  const toggleSource = useCallback(() => setShowSource((shown) => !shown), []);

  const written = SELECTIONS.filter(({ marker }) =>
    stream.markdown.includes(marker)
  ).length;
  // Rotated a quarter turn the hinge runs across, and the pages stack.
  const across = width >= height;
  const contentStyle = useMemo(
    () => [
      styles.content,
      { paddingTop: insets.top + 14, paddingBottom: insets.bottom + 90 },
    ],
    [insets.top, insets.bottom]
  );

  return (
    <View style={[styles.root, !across && styles.stacked]}>
      <Spotlight />
      <View style={[styles.page, across && { paddingLeft: insets.left }]}>
        <AnchorProvider anchors={anchors}>
          <Animated.ScrollView
            {...stream.scrollProps}
            contentContainerStyle={contentStyle}
          >
            <View
              ref={notes}
              onLayout={(event) => {
                notesTop.current = event.nativeEvent.layout.y;
              }}
            >
              <View style={styles.mark}>
                <LabelMark />
              </View>
              <Prompt />
              {stream.streaming && !stream.writing && <Thinking />}
              <EnrichedMarkdownText
                key={stream.run}
                flavor="github"
                markdown={stream.markdown}
                markdownStyle={linerMarkdownStyle}
                {...linerSelection}
                renderers={linerNotesRenderers}
                streamingAnimation={stream.streaming}
              />
              {!stream.streaming && <RunOut />}
            </View>
          </Animated.ScrollView>
        </AnchorProvider>
        <View
          style={[styles.follow, { bottom: insets.bottom + 16 }]}
          pointerEvents="box-none"
        >
          {stream.streaming && stream.detached && (
            <FollowPill onFollow={stream.follow} />
          )}
        </View>
      </View>
      <Crease open={open} across={across} />
      <View style={[styles.page, across && { paddingRight: insets.right }]}>
        <Jukebox
          top={across ? insets.top : 0}
          bottom={insets.bottom}
          written={written}
          open={open}
          onSelect={select}
          onReplay={replay}
          source={
            showSource ? (
              <Source markdown={stream.markdown} streaming={stream.streaming} />
            ) : null
          }
          onToggleSource={toggleSource}
        />
      </View>
    </View>
  );
}

const DOTS = [0, 1, 2];

// Three brass dots that breathe in turn while the answer is on its way.
function Thinking() {
  return (
    <Animated.View
      entering={FadeIn.duration(250)}
      exiting={FadeOut.duration(150)}
      style={styles.thinking}
    >
      {DOTS.map((i) => (
        <Dot key={i} index={i} />
      ))}
    </Animated.View>
  );
}

function Dot({ index }: { index: number }) {
  const pulse = useSharedValue(0);
  useEffect(() => {
    pulse.value = withDelay(
      index * 160,
      withRepeat(
        withSequence(
          withTiming(1, { duration: 380 }),
          withTiming(0, { duration: 380 })
        ),
        -1
      )
    );
  }, [pulse, index]);
  const style = useAnimatedStyle(() => ({
    opacity: 0.35 + pulse.value * 0.65,
    transform: [{ translateY: -pulse.value * 3 }],
  }));
  return <Animated.View style={[styles.dot, style]} />;
}

// The fold between the pages, deepest while the sleeve is half open.
function Crease({ open, across }: { open: Hinge['open']; across: boolean }) {
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(open.value, [0.3, 1], [1, 0.45], 'clamp'),
  }));
  return (
    <Animated.View
      pointerEvents="none"
      style={[across ? styles.creaseAcross : styles.creaseDown, style]}
    >
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient
            id="crease"
            x1="0"
            y1="0"
            x2={across ? '1' : '0'}
            y2={across ? '0' : '1'}
          >
            <Stop offset="0" stopColor="#000" stopOpacity={0} />
            <Stop offset="0.5" stopColor="#000" stopOpacity={0.75} />
            <Stop offset="1" stopColor="#000" stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#crease)" />
      </Svg>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: NIGHT,
  },
  stacked: {
    flexDirection: 'column',
  },
  page: {
    flex: 1,
    overflow: 'hidden',
  },
  content: {
    paddingHorizontal: 22,
  },
  mark: {
    alignSelf: 'flex-start',
    marginBottom: 18,
  },
  thinking: {
    flexDirection: 'row',
    gap: 6,
    paddingLeft: 4,
    marginTop: -8,
  },
  dot: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
    backgroundColor: BRASS,
  },
  follow: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  creaseAcross: {
    width: 36,
    marginHorizontal: -18,
    zIndex: 2,
  },
  creaseDown: {
    height: 36,
    marginVertical: -18,
    zIndex: 2,
  },
});
