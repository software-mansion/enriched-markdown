import {
  createContext,
  memo,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useLayoutEffect,
  useState,
} from 'react';
import {
  LogBox,
  Platform,
  Pressable,
  Settings,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import Animated, {
  Easing,
  SharedTransitionBoundary,
  interpolate,
  interpolateColor,
  useAnimatedReaction,
  useAnimatedRef,
  useAnimatedStyle,
  useDerivedValue,
  useScrollOffset,
  useSharedValue,
  withDelay,
  cancelAnimation,
  withRepeat,
  withSpring,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useIsFocused } from '@react-navigation/native';
import { useReanimatedTransitionProgress } from 'react-native-screens/reanimated';
import Svg, { Defs, LinearGradient, Path, Rect, Stop } from 'react-native-svg';
import {
  EnrichedMarkdownText,
  type MarkdownRenderers,
} from 'react-native-enriched-markdown';
import type { RootStackScreenProps } from '../../navigation/types';
import { useDemoStream } from '../shared/useDemoStream';
import { clock, useRunClock } from './clock';
import {
  MOVEMENT_MARKDOWN,
  PART_IDS,
  isPartId,
  parseSpecs,
  type PartId,
} from './movementMarkdown';
import {
  BOARD_GAP,
  BOARD_MARGIN,
  BoardPlate,
  GLIDE,
  PAGE_MARGIN,
  PagePlate,
  PageSight,
  ALONE_MS,
  TURN_MS,
  away,
  homeIn,
  homing,
  leaving,
  opened as openedPlate,
  settled,
  toBoard,
  turn,
} from './Plate';
import {
  BLUED,
  BRASS,
  BRASS_DEEP,
  CREAM,
  CREAM_SOFT,
  FONTS,
  INK,
  INK_SOFT,
  IVORY,
  NIGHT,
  pageMarkdownStyle,
} from './theme';
import { WorksTime } from './works';

type Mode = 'page' | 'board';

const HEAD_HEIGHT = 124;

// One document, laid out two ways on one screen. Each layout sits in its own
// SharedTransitionBoundary and the switch flips which of the two is active:
// no navigator is involved, the plates fly because the active boundary changed.

// From the end of the navigator's transition to the home plate showing.
const HANDOFF_MS = 100;

export default function MovementScreen({
  navigation,
}: RootStackScreenProps<'Movement'>) {
  useRunClock();
  const focused = useIsFocused();
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const [mode, setMode] = useState<Mode>('page');
  // The plate about to open its own screen: it trades the board's staggered
  // flight for a direct one, a frame before the navigation starts.
  const [alone, setAlone] = useState<PartId | null>(null);
  const mix = useSharedValue(0);
  const opened = useSharedValue(false);
  const settle = useRef<ReturnType<typeof setTimeout>>(undefined);
  const barTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const release = useRef<ReturnType<typeof setTimeout>>(undefined);
  // Only the layout in sight runs its works; both run while the bench turns.
  const turning = useSharedValue(false);
  const pageTime = useDerivedValue(() =>
    turning.value || mix.value < 1 ? clock.value : 0
  );
  const boardTime = useDerivedValue(() =>
    turning.value || mix.value > 0 ? clock.value : 0
  );
  const modeRef = useRef(mode);
  modeRef.current = mode;

  // It joins the others again once it is home: re-rendering the plates when
  // the focus returns would land on the first frames of the flight back.
  useEffect(
    () =>
      navigation.addListener('transitionEnd', (event) => {
        // The navigator is done before the plate is: its captions go back
        // only once it has landed and the hero has taken over.
        if (event.data.closing) {
          settle.current = setTimeout(() => {
            settled.value = opened.value;
          }, ALONE_MS);
          return;
        }
        clearTimeout(settle.current);
        setAlone(null);
        settled.value = false;
        // The home plate's text is still fading in: letting go of the open
        // plate now would snap it to full.
        clearTimeout(release.current);
        release.current = setTimeout(() => {
          opened.value = false;
        }, ALONE_MS + 300);
      }),
    [navigation, opened]
  );

  // `away` follows this screen's transition under the part's, which outlives
  // the part's screen on the way back and scrubs with a back swipe. Until the
  // push moves it, `progress` still holds the end of this screen's own arrival.
  const { progress, goingForward } = useReanimatedTransitionProgress();
  const moved = useSharedValue(false);
  useAnimatedReaction(
    () => ({
      opened: opened.value,
      progress: progress.value,
      forward: goingForward.value,
    }),
    (now, before) => {
      if (!now.opened) {
        moved.value = false;
        homing.value = false;
        away.value = 0;
        return;
      }
      if (!moved.value) {
        if (!before?.opened || before.progress === now.progress) {
          away.value = 0;
          return;
        }
        moved.value = true;
      }
      homing.value = !now.forward;
      away.value = now.forward ? now.progress : 1 - now.progress;
      // The home plate takes over from the flying one a moment after this
      // transition ends: its text starts in then, on a clock of its own.
      if (
        !now.forward &&
        now.progress > 0.97 &&
        homeIn.value === 0 &&
        leaving.value === 0
      ) {
        homeIn.value = withDelay(
          HANDOFF_MS,
          withTiming(1, { duration: 240, easing: Easing.linear })
        );
      }
    }
  );

  // The hidden layout's works wake a frame before the boundaries flip, so the
  // The hidden layout's works wake a frame before the boundaries flip, so the
  // plates take off already showing the right instant.
  const show = useCallback(
    (next: Mode) => {
      turning.value = true;
      // The status bar turns in the same commit as the flip: on its own it
      // re-renders the navigator, and after landing that froze a frame.
      requestAnimationFrame(() => {
        setMode(next);
        // The bar turns when the sheet is under it, not at take-off: white
        // text over the page would vanish while the sheet is still rising.
        clearTimeout(barTimer.current);
        barTimer.current = setTimeout(
          () =>
            navigation.setOptions({
              statusBarStyle: next === 'board' ? 'light' : 'dark',
              statusBarAnimation: 'none',
            }),
          next === 'board' ? TURN_MS * 0.55 : TURN_MS * 0.2
        );
      });
    },
    [navigation, turning]
  );

  // The clocks start with the commit that flips the boundaries, as the plates
  // do, so the captions and the bench keep step with them.
  const turned = useRef(mode);
  useLayoutEffect(() => {
    if (turned.current === mode) return;
    turned.current = mode;
    const to = mode === 'board' ? 1 : 0;
    toBoard.value = mode === 'board';
    turn.value = withTiming(to, { duration: TURN_MS, easing: Easing.linear });
    mix.value = withTiming(
      to,
      { duration: TURN_MS, easing: GLIDE },
      (finished) => {
        if (finished) turning.value = false;
      }
    );
  }, [mode, mix, turning]);

  // The part's screen keeps the tone of the layout it was opened from, so the
  // screens cross-fade light to light or dark to dark around the flying plate.
  const open = useCallback(
    (id: PartId) => {
      clearTimeout(release.current);
      opened.value = true;
      settled.value = false;
      leaving.value = 0;
      openedPlate.value = PART_IDS.indexOf(id);
      setAlone(id);
      requestAnimationFrame(() =>
        navigation.navigate('MovementPart', {
          part: id,
          night: modeRef.current === 'board',
        })
      );
    },
    [navigation, opened]
  );

  const flight = useMemo(() => ({ alone, open }), [alone, open]);

  // Nothing above a plate ever fades: a flying plate takes the opacity of the
  // parents of the view it is heading for, and would go translucent in the
  // air. The two layouts stay opaque, and the bench is a sheet between them
  // that rises over the prose, so no frame is a blend of paper and night.
  const benchStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: (1 - mix.value) * height }],
    borderTopLeftRadius: interpolate(mix.value, [0, 0.85, 1], [44, 44, 0]),
    borderTopRightRadius: interpolate(mix.value, [0, 0.85, 1], [44, 44, 0]),
  }));

  // The heading stays where it ends up and fades in as the sheet reaches it,
  // rather than riding up the screen with the sheet.
  const headStyle = useAnimatedStyle(() => ({
    opacity: interpolate(mix.value, [0.86, 1], [0, 1], 'clamp'),
    transform: [{ translateY: -(1 - mix.value) * height }],
  }));

  return (
    <FlightContext.Provider value={flight}>
      <View style={styles.root}>
        <SharedTransitionBoundary isActive={focused && mode === 'page'}>
          <View
            style={styles.layer}
            pointerEvents={mode === 'page' ? 'auto' : 'none'}
            accessibilityElementsHidden={mode !== 'page'}
            importantForAccessibility={
              mode === 'page' ? 'auto' : 'no-hide-descendants'
            }
          >
            <WorksTime.Provider value={pageTime}>
              <Page top={insets.top} bottom={insets.bottom} turning={turning} />
            </WorksTime.Provider>
          </View>
        </SharedTransitionBoundary>
        <Animated.View
          style={[styles.layer, styles.bench, benchStyle]}
          pointerEvents="none"
        >
          <Animated.View
            style={[
              styles.boardHead,
              { paddingTop: insets.top + 14 },
              headStyle,
            ]}
          >
            <Text style={styles.boardKicker}>CAL. 18000 · LAID OUT</Text>
            <Text style={styles.boardTitle}>On the bench</Text>
            <Text style={styles.boardSub}>
              Six assemblies, none of them stopped.
            </Text>
          </Animated.View>
        </Animated.View>
        <SharedTransitionBoundary isActive={focused && mode === 'board'}>
          <View
            style={styles.layer}
            pointerEvents={mode === 'board' ? 'auto' : 'none'}
            accessibilityElementsHidden={mode !== 'board'}
            importantForAccessibility={
              mode === 'board' ? 'auto' : 'no-hide-descendants'
            }
          >
            <WorksTime.Provider value={boardTime}>
              <Board
                top={insets.top + HEAD_HEIGHT}
                shown={mode === 'board'}
                alone={alone}
                open={open}
              />
            </WorksTime.Provider>
          </View>
        </SharedTransitionBoundary>
        <ModeButton
          mode={mode}
          mix={mix}
          onChange={show}
          bottom={insets.bottom + 14}
        />
      </View>
    </FlightContext.Provider>
  );
}

// The board's tiles are measured before they are on screen: a harmless warning.
LogBox.ignoreLogs(['[Reanimated] The view has some undefined']);

// Launch with `-movementStream 1` (iOS) to see the page write itself, up to the
// second plate, for a recording.
const STREAM =
  Platform.OS === 'ios' && Number(Settings.get('movementStream')) === 1;
const STREAM_SOURCE = MOVEMENT_MARKDOWN.slice(
  0,
  MOVEMENT_MARKDOWN.indexOf('## III')
);

function useStaticPage() {
  return {
    markdown: MOVEMENT_MARKDOWN,
    scrollProps: undefined,
    streaming: false,
    stop: undefined,
  };
}

function useStreamedPage() {
  const stream = useDemoStream(STREAM_SOURCE, 900, true, 'whole', 6, 'words');
  // The rest of the page arrives a beat after the stream ends, once the
  // follow has let go of the bottom.
  const [rest, setRest] = useState(false);
  useEffect(() => {
    if (stream.streaming) return;
    const timer = setTimeout(() => setRest(true), 400);
    return () => clearTimeout(timer);
  }, [stream.streaming]);
  return {
    markdown: stream.streaming
      ? stream.markdown
      : rest
        ? MOVEMENT_MARKDOWN
        : STREAM_SOURCE,
    scrollProps: stream.scrollProps,
    streaming: stream.streaming,
    stop: stream.jump,
  };
}

const STREAMING_CONFIG = { animation: 'fade', smooth: true } as const;

const usePage = STREAM ? useStreamedPage : useStaticPage;

// The prose. It renders once: flipping the layout does not touch it.
const Page = memo(function Page({
  top,
  bottom,
  turning,
}: {
  top: number;
  bottom: number;
  turning: SharedValue<boolean>;
}) {
  const { markdown, scrollProps, streaming, stop } = usePage();
  const ownScroll = useAnimatedRef<Animated.ScrollView>();
  const scroll = scrollProps?.ref ?? ownScroll;
  const scrollY = useScrollOffset(scroll);
  const sight = useMemo(() => ({ scrollY, turning }), [scrollY, turning]);
  // When the stream is done the follow lets go where it is, and the rest of
  // the page arrives below the fold for the other plates to fly from.
  const done = !streaming && stop !== undefined;
  useEffect(() => {
    if (done) stop(scrollY.value);
  }, [done, stop, scrollY]);
  const content = useMemo(
    () => ({
      paddingTop: top + 16,
      paddingHorizontal: PAGE_MARGIN,
      paddingBottom: bottom + 130,
    }),
    [top, bottom]
  );
  return (
    <PageSight.Provider value={sight}>
      <Animated.ScrollView
        {...scrollProps}
        ref={scroll}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={content}
      >
        <View style={styles.kickerRow}>
          <Text style={styles.kicker}>CAL. 18000</Text>
          <View style={styles.kickerRule} />
          <Text style={styles.kicker}>BENCH NOTES</Text>
        </View>
        <EnrichedMarkdownText
          flavor="github"
          markdown={markdown}
          streaming={streaming}
          streamingConfig={STREAMING_CONFIG}
          markdownStyle={pageMarkdownStyle}
          renderers={renderers}
        />
      </Animated.ScrollView>
      <EdgeFade height={top + 18} edge="top" />
      <EdgeFade height={bottom + 124} edge="bottom" />
    </PageSight.Provider>
  );
});

// The board's tiles. They switch on with the commit that activates their
// boundary, and off again with the one that hands the plates back to the page.
const Board = memo(function Board({
  top,
  shown,
  alone,
  open,
}: {
  top: number;
  shown: boolean;
  alone: PartId | null;
  open: (id: PartId) => void;
}) {
  return (
    <View
      style={[styles.grid, { marginTop: top }, shown ? null : styles.hidden]}
      collapsable={false}
    >
      {PART_IDS.map((id) => (
        <BoardPlate key={id} id={id} alone={alone === id} onPress={open} />
      ))}
    </View>
  );
});

// Which plate is about to fly alone, and how to open one. The renderers are
// plain module-level functions, so the blocks reach the screen through this.
const FlightContext = createContext<{
  alone: PartId | null;
  open: (id: PartId) => void;
}>({ alone: null, open: () => {} });

function PageSlot({ id, code }: { id: PartId; code: string }) {
  const { alone, open } = useContext(FlightContext);
  const specs = useMemo(() => parseSpecs(code), [code]);
  return (
    <PagePlate id={id} specs={specs} alone={alone === id} onPress={open} />
  );
}

// Every fenced block that names an assembly becomes its plate, in place.
const renderers: MarkdownRenderers = {
  code: (block) =>
    isPartId(block.language) ? (
      <PageSlot id={block.language} code={block.code} />
    ) : undefined,
};

// The prose runs out under the status bar and under the switch instead of
// colliding with them.
function EdgeFade({
  height,
  edge,
}: {
  height: number;
  edge: 'top' | 'bottom';
}) {
  const id = `movement-fade-${edge}`;
  const solid = edge === 'top' ? '0.55' : STREAM ? '0.72' : '0.5';
  return (
    <Svg
      height={height}
      width="100%"
      style={edge === 'top' ? styles.topFade : styles.bottomFade}
      pointerEvents="none"
    >
      <Defs>
        <LinearGradient
          id={id}
          x1="0"
          y1={edge === 'top' ? '0' : '1'}
          x2="0"
          y2={edge === 'top' ? '1' : '0'}
        >
          <Stop offset={solid} stopColor={IVORY} stopOpacity={1} />
          <Stop offset="1" stopColor={IVORY} stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height={height} fill={`url(#${id})`} />
    </Svg>
  );
}

const BUTTON_WIDTH = 244;
const BUTTON_HEIGHT = 52;
const DOTS = [0, 1, 2]
  .flatMap((col) => [0, 1].map((row) => [3 + col * 5, 4.5 + row * 5]))
  .map(
    ([x, y]) =>
      `M ${x! - 1.3} ${y} a 1.3 1.3 0 1 0 2.6 0 a 1.3 1.3 0 1 0 -2.6 0`
  )
  .join(' ');
const LINES = 'M 2 3.5 H 14 M 2 7 H 14 M 2 10.5 H 9';

// One button that names where it takes you. It is an action, not a setting:
// the label is the destination, and it changes with the bench.
const ModeButton = memo(function ModeButton({
  mode,
  mix,
  onChange,
  bottom,
}: {
  mode: Mode;
  mix: SharedValue<number>;
  onChange: (mode: Mode) => void;
  bottom: number;
}) {
  const pressed = useSharedValue(0);
  const hint = useSharedValue(0);
  const last = useRef(0);
  // An invitation, twice, until the first tap.
  useEffect(() => {
    hint.value = withDelay(
      900,
      withRepeat(withTiming(1, { duration: 1400, easing: GLIDE }), 2, false)
    );
  }, [hint]);

  // The plates cross the button on their way: it is gone while they do, and
  // back as they land.
  const pill = useAnimatedStyle(() => {
    const gone = Math.min(1, 3 * Math.sin(Math.PI * turn.value));
    return {
      backgroundColor: interpolateColor(mix.value, [0, 1], [INK, IVORY]),
      opacity: 1 - gone,
      transform: [{ translateY: 10 * gone }],
    };
  });
  // Apart from the flight's style, so a flight never re-runs it.
  const press = useAnimatedStyle(() => ({
    borderColor: interpolateColor(
      pressed.value,
      [0, 1],
      ['rgba(205, 168, 94, 0.5)', 'rgba(240, 216, 154, 1)']
    ),
    transform: [{ scale: 1 - 0.03 * pressed.value }],
  }));
  const ring = useAnimatedStyle(() => ({
    opacity: hint.value === 0 || hint.value === 1 ? 0 : 0.6 * (1 - hint.value),
    transform: [
      { scaleX: 1 + 0.12 * hint.value },
      { scaleY: 1 + 0.36 * hint.value },
    ],
  }));
  const toParts = useAnimatedStyle(() => ({
    opacity: 1 - Math.min(1, mix.value * 2),
    transform: [{ translateY: -6 * Math.min(1, mix.value * 2) }],
  }));
  const toPage = useAnimatedStyle(() => ({
    opacity: Math.max(0, mix.value * 2 - 1),
    transform: [{ translateY: 6 * (1 - Math.max(0, mix.value * 2 - 1)) }],
  }));
  return (
    <View style={[styles.buttonSlot, { bottom }]} pointerEvents="box-none">
      <Animated.View style={[styles.ring, ring]} pointerEvents="none" />
      <Animated.View style={[styles.button, pill]}>
        <Animated.View
          style={[styles.buttonEdge, press]}
          pointerEvents="none"
        />
        <Pressable
          style={styles.buttonPress}
          onPressIn={() => {
            cancelAnimation(hint);
            hint.value = 0;
            pressed.value = withTiming(1, { duration: 90 });
          }}
          onPressOut={() => {
            pressed.value = withSpring(0, { damping: 14, stiffness: 260 });
          }}
          onPress={() => {
            // A toggle would undo itself on an accidental double tap.
            const now = Date.now();
            if (now - last.current < 300) return;
            last.current = now;
            onChange(mode === 'page' ? 'board' : 'page');
          }}
          accessibilityRole="button"
          accessibilityLabel={
            mode === 'page' ? 'Lay out the parts' : 'Back to the page'
          }
          testID="movement-switch"
        >
          <Animated.View style={[styles.buttonLabel, toParts]}>
            <Svg width={16} height={14}>
              <Path d={DOTS} fill={BRASS} />
            </Svg>
            <Text style={[styles.buttonText, styles.onInk]}>
              LAY OUT THE PARTS
            </Text>
          </Animated.View>
          <Animated.View style={[styles.buttonLabel, toPage]}>
            <Svg width={16} height={14}>
              <Path
                d={LINES}
                stroke={BRASS_DEEP}
                strokeWidth={1.6}
                strokeLinecap="round"
              />
            </Svg>
            <Text style={[styles.buttonText, styles.onIvory]}>
              BACK TO THE PAGE
            </Text>
          </Animated.View>
        </Pressable>
      </Animated.View>
    </View>
  );
});

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: IVORY },
  hidden: { opacity: 0 },
  topFade: { position: 'absolute', left: 0, top: 0 },
  bottomFade: { position: 'absolute', left: 0, bottom: 0 },
  layer: { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 },
  bench: { backgroundColor: NIGHT, overflow: 'hidden' },
  kickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 22,
  },
  kicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.6,
    color: INK_SOFT,
  },
  kickerRule: {
    flex: 1,
    height: StyleSheet.hairlineWidth,
    backgroundColor: INK_SOFT,
  },
  boardHead: { paddingHorizontal: BOARD_MARGIN + 4 },
  boardKicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.6,
    color: BLUED,
  },
  boardTitle: {
    fontFamily: FONTS.display,
    fontSize: 40,
    lineHeight: 46,
    color: CREAM,
    marginTop: 4,
  },
  boardSub: {
    fontFamily: FONTS.bodyItalic,
    fontStyle: 'italic',
    fontSize: 16,
    color: CREAM_SOFT,
    marginTop: 2,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: BOARD_GAP,
    paddingHorizontal: BOARD_MARGIN,
  },
  buttonSlot: {
    position: 'absolute',
    alignSelf: 'center',
    width: BUTTON_WIDTH,
    height: BUTTON_HEIGHT,
  },
  button: {
    width: BUTTON_WIDTH,
    height: BUTTON_HEIGHT,
    borderRadius: BUTTON_HEIGHT / 2,
    shadowColor: '#000',
    shadowOpacity: 0.22,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
  },
  ring: {
    position: 'absolute',
    width: BUTTON_WIDTH,
    height: BUTTON_HEIGHT,
    borderRadius: BUTTON_HEIGHT / 2,
    borderWidth: 1.5,
    borderColor: BRASS,
  },
  buttonEdge: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    borderRadius: BUTTON_HEIGHT / 2,
    borderWidth: 1,
  },
  buttonPress: { flex: 1 },
  buttonLabel: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  buttonText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    letterSpacing: 1.8,
  },
  onInk: { color: IVORY },
  onIvory: { color: INK },
});
