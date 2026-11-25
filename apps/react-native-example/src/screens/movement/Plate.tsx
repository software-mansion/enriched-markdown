import {
  createContext,
  memo,
  useContext,
  useMemo,
  type ReactNode,
} from 'react';
import {
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
  SharedTransition,
  makeMutable,
  measure,
  useAnimatedReaction,
  useAnimatedRef,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { PART_IDS, PART_NAMES, specsOf, type PartId } from './movementMarkdown';
import {
  BRASS,
  CREAM,
  CREAM_SOFT,
  FONTS,
  HERO,
  TILE,
  TILE_EDGE,
} from './theme';
import { WORKS_SIZE, Works, WorksTime } from './works';

export type Spec = { key: string; value: string };

export const PAGE_MARGIN = 22;
export const BOARD_MARGIN = 18;
export const BOARD_GAP = 12;
const PAGE_DISC = 150;
const PAGE_INSET = 13;
export const PAGE_PLATE_HEIGHT = PAGE_DISC + PAGE_INSET * 2;
const HERO_DISC = 300;
export const HERO_TOP = 46;
const HERO_FOOT = 96;

export function useTile() {
  const { width } = useWindowDimensions();
  const size = Math.floor((width - BOARD_MARGIN * 2 - BOARD_GAP) / 2);
  const disc = size - 54;
  return { size, disc, height: disc + 60 };
}

// The flight: one curve for every plate, in both directions. A plate keeps its
// colour from the page to the board to its own screen, so nothing blends
// through grey in the air; only its frame, corners and captions change. The
// works ride the same curve, so they travel in a straight line within the
// plate. To and from the board each plate leaves half a beat after the one
// before it.
// Between the layouts the plates ease away briefly and settle long.
const TURN_CURVE = [0.3, 0.15, 0.1, 1] as const;
export const GLIDE = Easing.bezier(...TURN_CURVE);
// The landed-on plate only shows once the flight ends, so this curve has
// little tail: the card is still for a few frames, not a quarter second.
const SOLO_GLIDE = Easing.bezier(0.3, 0, 0.3, 1);
// Launch with `-movementSlow 1.6` (iOS) to stretch the flights for a recording.
export const SLOW =
  Platform.OS === 'ios' ? Number(Settings.get('movementSlow')) || 1 : 1;
export const TOGETHER_MS = Math.round(540 * SLOW);
export const ALONE_MS = Math.round(480 * SLOW);
export const STAGGER_MS = Math.round(45 * SLOW);
// The bench turns for as long as the last plate is in the air.
export const TURN_MS = TOGETHER_MS + (PART_IDS.length - 1) * STAGGER_MS;

const together = PART_IDS.map((_, index) =>
  SharedTransition.duration(TOGETHER_MS)
    .easing(GLIDE)
    .delay(index * STAGGER_MS)
);
// Alone, to the detail screen and back: the same curve, no wait.
const solo = SharedTransition.duration(ALONE_MS).easing(SOLO_GLIDE);

// Where the flights are, on the UI thread. `turn` runs 0 to 1 in plain time
// as the bench comes up and back as it goes; `toBoard` is its direction;
// `away` follows the detail screen's transition, a back swipe included;
// `homing` is its direction, and `settled` says the detail screen is up.
export const turn = makeMutable(0);
export const toBoard = makeMutable(false);
export const away = makeMutable(0);
export const homing = makeMutable(false);
export const settled = makeMutable(false);
export const leaving = makeMutable(0);
export const homeIn = makeMutable(1);
// Which plate was opened: it outlives `alone`, which is cleared on landing.
export const opened = makeMutable(-1);

// A plate lands already wearing the captions of where it is going. The view
// that flies is the one being left, and what it is heading for only shows once
// it is down, so each plate also holds the other layouts' captions, in a box
// of that layout's size pinned to its top left corner. They fade in over the
// end of the flight, by which time the frame has all but closed on that box,
// and the swap on landing changes nothing on screen.
// The captions cross-fade on the plate's own progress, the flight's curve
// applied to its time, so they change at the pace the frame moves: the old set
// is gone before half way and the new one is whole three quarters of the way.
const glide = Easing.bezierFn(...TURN_CURVE);
const OUT_BY = 0.4;
const IN_FROM = 0.2;
const IN_BY = 0.75;
// The navigator's progress eases in where the flight does not: by a third of
// it the plate has all but landed, so these windows sit early.
const AWAY_IN_FROM = 0.06;
const AWAY_IN_BY = 0.32;

function ramp(value: number, from: number, to: number) {
  'worklet';
  return Math.min(1, Math.max(0, (value - from) / (to - from)));
}

// How far plate `index` has travelled: its own share of the turn, stagger
// included, through the flight's curve. The caller reads `turn` itself: a
// style only follows the shared values its own worklet touches.
function flown(turned: number, index: number, forward: boolean) {
  'worklet';
  const elapsed = (forward ? turned : 1 - turned) * TURN_MS;
  return glide(
    ramp(elapsed, index * STAGGER_MS, index * STAGGER_MS + TOGETHER_MS)
  );
}

type Layout = 'page' | 'board';

// The opacity of each caption set on a plate of the page or of the board.
function useCaptions(id: PartId, layout: Layout, alone: boolean | undefined) {
  const index = PART_IDS.indexOf(id);
  const fromPage = layout === 'page';
  const own = useAnimatedStyle(() => {
    // Opening, its small captions go at once: left on, they would sit in a
    // corner of the growing plate. Coming home it is the plate being landed
    // on, put back as it will stay while the detail screen still covers it:
    // a value written to it during the flight home does not survive landing.
    // After the back button it fades in as the plate lands, on its own clock.
    if (alone) {
      if (!homing.value && !settled.value) return { opacity: 0 };
      // The page card stages its own text; the board tile just fades.
      return { opacity: leaving.value > 0 && !fromPage ? homeIn.value : 1 };
    }
    if (!fromPage && opened.value === index && homeIn.value < 1) {
      return { opacity: homeIn.value };
    }
    if (toBoard.value !== fromPage) return { opacity: 1 };
    return { opacity: 1 - ramp(flown(turn.value, index, fromPage), 0, OUT_BY) };
  });
  const other = useAnimatedStyle(() => {
    if (alone || toBoard.value !== fromPage) return { opacity: 0 };
    const at = flown(turn.value, index, fromPage);
    // The page's text stages itself in, so its box is simply there.
    if (!fromPage) return { opacity: at > IN_FROM ? 1 : 0 };
    return { opacity: ramp(at, IN_FROM, IN_BY) };
  });
  // How far the page card's text is in: on a page plate, after the back
  // button; on a board tile, as it flies to the page.
  const reveal = useDerivedValue(() => {
    if (fromPage) {
      return opened.value === index ? homeIn.value : 1;
    }
    if (alone || toBoard.value) return 0;
    return ramp(flown(turn.value, index, false), IN_FROM, IN_BY);
  });
  const hero = useAnimatedStyle(() => ({
    opacity:
      alone && !homing.value && !settled.value
        ? ramp(away.value, AWAY_IN_FROM, AWAY_IN_BY)
        : 0,
  }));
  return { own, other, hero, reveal };
}

function useBoxes() {
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const tile = useTile();
  return {
    page: { width: width - PAGE_MARGIN * 2, height: PAGE_PLATE_HEIGHT },
    board: { width: tile.size, height: tile.height },
    hero: { width, height: heroHeight(insets.top) + HERO_RADIUS },
    tile,
    width,
    top: insets.top,
  };
}

function ordinal(id: PartId) {
  return String(PART_IDS.indexOf(id) + 1).padStart(2, '0');
}

type PlateProps = {
  id: PartId;
  specs?: Spec[];
  // Whether this plate is about to fly on its own, to the detail screen.
  alone?: boolean;
  onPress?: (id: PartId) => void;
};

function useFlight(id: PartId, alone: boolean | undefined) {
  return alone ? solo : together[PART_IDS.indexOf(id)];
}

type CaptionsProps = { id: PartId; specs: Spec[] };

// One step of the staged entrance: its share of `reveal`, eased out.
function step(reveal: number, from: number, to: number) {
  'worklet';
  const at = 1 - ramp(reveal, from, to);
  return 1 - at * at * at;
}

// The card's text arrives in three beats as `reveal` runs 0 to 1: the
// ordinal from the left, the name rising after it, the figures last.
const PageCaptions = memo(function PageCaptions({
  id,
  specs,
  reveal,
}: CaptionsProps & { reveal: SharedValue<number> }) {
  const first = useAnimatedStyle(() => {
    const at = step(reveal.value, 0, 0.5);
    return { opacity: at, transform: [{ translateX: -6 * (1 - at) }] };
  });
  const second = useAnimatedStyle(() => {
    const at = step(reveal.value, 0.17, 0.75);
    return { opacity: at, transform: [{ translateY: 8 * (1 - at) }] };
  });
  const third = useAnimatedStyle(() => {
    const at = step(reveal.value, 0.33, 1);
    return { opacity: at, transform: [{ translateY: 6 * (1 - at) }] };
  });
  return (
    <View style={styles.pageText}>
      <Animated.Text style={[styles.pageOrdinal, first]}>
        No. {ordinal(id)}
      </Animated.Text>
      <Animated.Text style={[styles.pageName, second]}>
        {PART_NAMES[id]}
      </Animated.Text>
      <Animated.View style={third}>
        <View style={styles.pageRule} />
        {specs.map((spec) => (
          <Text key={spec.key} style={styles.pageSpec}>
            <Text style={styles.pageSpecKey}>{spec.key.toUpperCase()}</Text>
            {'\n'}
            {spec.value}
          </Text>
        ))}
      </Animated.View>
    </View>
  );
});

const BoardCaptions = memo(function BoardCaptions({ id }: { id: PartId }) {
  return (
    <View style={styles.boardLabel}>
      <Text style={styles.boardOrdinal}>{ordinal(id)}</Text>
      <Text style={styles.boardName}>{PART_NAMES[id]}</Text>
    </View>
  );
});

const HeroCaptions = memo(function HeroCaptions({ id }: { id: PartId }) {
  return (
    <View style={styles.heroText}>
      <Text style={styles.heroOrdinal}>
        No. {ordinal(id)} <Text style={styles.heroOf}>/ 06</Text>
      </Text>
      <Text style={styles.heroName}>{PART_NAMES[id]}</Text>
    </View>
  );
});

// One caption set, in the box of the layout it belongs to.
function Captions({
  box,
  shift = 0,
  style,
  ghost,
  children,
}: {
  box: { width: number; height: number };
  // The page and board plates have a hairline border and the hero has none:
  // a set borrowed across that difference moves over by it.
  shift?: number;
  style: ReturnType<typeof useAnimatedStyle>;
  ghost?: boolean;
  children: ReactNode;
}) {
  return (
    <Animated.View
      style={[styles.captions, box, { left: shift, top: shift }, style]}
      pointerEvents="none"
      accessibilityElementsHidden={ghost}
      importantForAccessibility={ghost ? 'no-hide-descendants' : 'auto'}
    >
      {children}
    </Animated.View>
  );
}

// The works are a direct child of the plate, placed by `left`/`top` and sized
// by a scale alone, so the transition can carry them as one drawing.
function worksStyle(left: number, top: number, disc: number) {
  return [
    styles.works,
    { left, top, transform: [{ scale: disc / WORKS_SIZE }] },
  ];
}

// What a plate in the prose needs to know whether it can be seen: how far the
// page has scrolled, and whether the bench is turning.
export const PageSight = createContext<{
  scrollY: SharedValue<number>;
  turning: SharedValue<boolean>;
} | null>(null);

const SIGHT_MARGIN = 80;

// The time for a plate in the prose: stopped while it is scrolled out of
// sight, unless it is about to fly to the board.
function usePageTime() {
  const { height } = useWindowDimensions();
  const layoutTime = useContext(WorksTime);
  const sight = useContext(PageSight);
  const ref = useAnimatedRef<Animated.View>();
  const laidOut = useSharedValue(0);
  const inSight = useSharedValue(true);
  useAnimatedReaction(
    () => (sight ? sight.scrollY.value : 0) + laidOut.value,
    () => {
      const box = measure(ref);
      if (!box) return;
      inSight.value =
        box.pageY + box.height > -SIGHT_MARGIN &&
        box.pageY < height + SIGHT_MARGIN;
    }
  );
  const time = useDerivedValue(() =>
    inSight.value || sight?.turning.value ? layoutTime.value : 0
  );
  const onLayout = () => {
    laidOut.value += 1;
  };
  return { ref, time, onLayout };
}

// In the prose: a dark plate set into the page, the works on the left, the
// figures beside them.
export const PagePlate = memo(function PagePlate({
  id,
  specs = [],
  alone,
  onPress,
}: PlateProps) {
  const boxes = useBoxes();
  const flight = useFlight(id, alone);
  const captions = useCaptions(id, 'page', alone);
  const { ref, time, onLayout } = usePageTime();
  return (
    <Pressable
      onPress={() => onPress?.(id)}
      accessibilityRole="button"
      accessibilityLabel={PART_NAMES[id]}
      testID={`movement-page-${id}`}
    >
      <Animated.View
        ref={ref}
        onLayout={onLayout}
        sharedTransitionTag={`plate-${id}`}
        sharedTransitionStyle={flight}
        style={[styles.pagePlate, boxes.page]}
      >
        <Animated.View
          sharedTransitionTag={`works-${id}`}
          sharedTransitionStyle={flight}
          style={worksStyle(PAGE_INSET, PAGE_INSET, PAGE_DISC)}
        >
          <WorksTime.Provider value={time}>
            <Works id={id} />
          </WorksTime.Provider>
        </Animated.View>
        <Captions box={boxes.page} style={captions.own}>
          <PageCaptions id={id} specs={specs} reveal={captions.reveal} />
        </Captions>
        <Captions box={boxes.board} style={captions.other} ghost>
          <BoardCaptions id={id} />
        </Captions>
        <Captions box={boxes.hero} shift={-EDGE} style={captions.hero} ghost>
          <HeroCaptions id={id} />
        </Captions>
      </Animated.View>
    </Pressable>
  );
});

// On the board: a dark tile, the works above its name.
export const BoardPlate = memo(function BoardPlate({
  id,
  alone,
  onPress,
}: PlateProps) {
  const boxes = useBoxes();
  const { tile } = boxes;
  const specs = useMemo(() => specsOf(id), [id]);
  const flight = useFlight(id, alone);
  const captions = useCaptions(id, 'board', alone);
  return (
    <Pressable
      onPress={() => onPress?.(id)}
      accessibilityRole="button"
      accessibilityLabel={PART_NAMES[id]}
      testID={`movement-board-${id}`}
    >
      <Animated.View
        sharedTransitionTag={`plate-${id}`}
        sharedTransitionStyle={flight}
        style={[styles.boardPlate, boxes.board]}
      >
        <Animated.View
          sharedTransitionTag={`works-${id}`}
          sharedTransitionStyle={flight}
          style={worksStyle((tile.size - tile.disc) / 2, 14, tile.disc)}
        >
          <Works id={id} />
        </Animated.View>
        <Captions box={boxes.board} style={captions.own}>
          <BoardCaptions id={id} />
        </Captions>
        <Captions box={boxes.page} style={captions.other} ghost>
          <PageCaptions id={id} specs={specs} reveal={captions.reveal} />
        </Captions>
        <Captions box={boxes.hero} shift={-EDGE} style={captions.hero} ghost>
          <HeroCaptions id={id} />
        </Captions>
      </Animated.View>
    </Pressable>
  );
});

// The hero's corners are all one radius, with the top pair pushed above the
// screen: a uniform radius stays a plain layer corner for the whole flight,
// where mixed radii are redrawn as an image every frame.
const HERO_RADIUS = 40;
const EDGE = 1;

function heroHeight(topInset: number) {
  return topInset + HERO_TOP + HERO_DISC + HERO_FOOT;
}

// On its own screen: the plate is the top of the page, edge to edge. Going
// home it carries the captions of the layout it was opened from.
export const HeroPlate = memo(function HeroPlate({
  id,
  from,
}: {
  id: PartId;
  from: Layout;
}) {
  const boxes = useBoxes();
  const specs = useMemo(() => specsOf(id), [id]);
  // The title goes as the plate leaves; the captions of the plate it lands on
  // show only for the last of the way, once the frame has closed on them.
  // The back button fades the title first: the screen is torn down as it
  // leaves and these styles stop with it.
  const own = useAnimatedStyle(() => ({
    opacity:
      (1 - leaving.value) * (homing.value ? ramp(away.value, 0.85, 1) : 1),
  }));
  const home = useAnimatedStyle(() => {
    if (!homing.value || leaving.value > 0) return { opacity: 0 };
    if (from === 'page') return { opacity: away.value < 0.22 ? 1 : 0 };
    return { opacity: 1 - ramp(away.value, 0.03, 0.12) };
  });
  const homeReveal = useDerivedValue(() =>
    homing.value ? 1 - ramp(away.value, 0.02, 0.22) : 0
  );
  return (
    <Animated.View
      sharedTransitionTag={`plate-${id}`}
      sharedTransitionStyle={solo}
      style={[styles.heroPlate, boxes.hero]}
    >
      <Animated.View
        sharedTransitionTag={`works-${id}`}
        sharedTransitionStyle={solo}
        style={worksStyle(
          (boxes.width - HERO_DISC) / 2,
          HERO_RADIUS + boxes.top + HERO_TOP,
          HERO_DISC
        )}
      >
        <Works id={id} />
      </Animated.View>
      <Captions box={boxes.hero} style={own}>
        <HeroCaptions id={id} />
      </Captions>
      <Captions box={boxes[from]} shift={EDGE} style={home} ghost>
        {from === 'page' ? (
          <PageCaptions id={id} specs={specs} reveal={homeReveal} />
        ) : (
          <BoardCaptions id={id} />
        )}
      </Captions>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  captions: { position: 'absolute', left: 0, top: 0 },
  works: {
    position: 'absolute',
    width: WORKS_SIZE,
    height: WORKS_SIZE,
    transformOrigin: 'top left',
  },
  // Each plate clips: a caption box of another layout's size shows only as far
  // as the frame has reached.
  pagePlate: {
    overflow: 'hidden',
    borderRadius: 26,
    borderWidth: 1,
    borderColor: TILE_EDGE,
    backgroundColor: TILE,
  },
  pageText: {
    position: 'absolute',
    left: PAGE_INSET + PAGE_DISC + 18,
    right: 14,
    top: 0,
    bottom: 0,
    justifyContent: 'center',
  },
  // Ordinals are set in the display serif: the mono's slashed zero reads as
  // a stray glyph beside a title, where in the figures it reads as a gauge.
  pageOrdinal: {
    fontFamily: FONTS.display,
    fontSize: 12.5,
    letterSpacing: 0.8,
    color: BRASS,
  },
  pageName: {
    fontFamily: FONTS.display,
    fontSize: 23,
    lineHeight: 27,
    color: CREAM,
    marginTop: 3,
  },
  pageRule: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: BRASS,
    opacity: 0.45,
    marginTop: 10,
    marginBottom: 4,
  },
  // Key over value in one text view: each view inside a plate is paid for
  // again when the plate takes off.
  pageSpec: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    lineHeight: 17,
    color: CREAM,
    marginTop: 6,
  },
  pageSpecKey: {
    fontFamily: FONTS.mono,
    fontSize: 9.5,
    letterSpacing: 1.1,
    color: CREAM_SOFT,
  },
  boardPlate: {
    overflow: 'hidden',
    borderRadius: 30,
    borderWidth: 1,
    borderColor: TILE_EDGE,
    backgroundColor: TILE,
  },
  boardLabel: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 13,
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'center',
    gap: 7,
  },
  boardOrdinal: {
    fontFamily: FONTS.display,
    fontSize: 12,
    letterSpacing: 0.6,
    color: BRASS,
  },
  boardName: {
    fontFamily: FONTS.display,
    fontSize: 15.5,
    color: CREAM,
  },
  heroPlate: {
    overflow: 'hidden',
    marginTop: -HERO_RADIUS,
    borderRadius: HERO_RADIUS,
    borderWidth: 0,
    borderColor: TILE_EDGE,
    backgroundColor: HERO,
  },
  heroText: {
    position: 'absolute',
    left: 26,
    right: 26,
    bottom: 24,
  },
  heroOrdinal: {
    fontFamily: FONTS.display,
    fontSize: 13.5,
    letterSpacing: 1,
    color: BRASS,
  },
  heroOf: { color: CREAM_SOFT },
  heroName: {
    fontFamily: FONTS.display,
    fontSize: 38,
    lineHeight: 42,
    color: CREAM,
    marginTop: 2,
  },
});
