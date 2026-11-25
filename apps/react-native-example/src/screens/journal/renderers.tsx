import { memo, useEffect, useState } from 'react';
import {
  Image,
  Linking,
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
  type ImageSourcePropType,
} from 'react-native';
import Animated, {
  Easing,
  Extrapolation,
  cancelAnimation,
  interpolate,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, {
  Circle,
  Defs,
  LinearGradient,
  Path,
  Rect,
  Stop,
} from 'react-native-svg';
import {
  EnrichedMarkdownText,
  type MarkdownImageBlock,
  type MarkdownLinkBlock,
  type MarkdownRenderers,
  type MarkdownStyle,
  type MarkdownVideoBlock,
} from 'react-native-enriched-markdown';
import {
  FONTS,
  INK,
  INK_SOFT,
  MOSS,
  PAPER,
  RIVER,
  VERMILION,
  jitter,
} from './theme';
import { RailLine } from './diagrams/RailLine';
import { LIGHTBOX_MARGIN, Lightbox } from './Lightbox';
import { Tappable } from './Tappable';
import { useInstant } from './source/face';
import { Mermaid } from './mermaid/Mermaid';

const PHOTOS: Record<string, ImageSourcePropType> = {
  'gion.jpg': require('../../assets/kyoto/gion.jpg'),
  'torii.jpg': require('../../assets/kyoto/torii.jpg'),
  'kinkaku.jpg': require('../../assets/kyoto/kinkaku.jpg'),
  'kiyomizu.jpg': require('../../assets/kyoto/kiyomizu.jpg'),
  'fuji-from-the-train.mp4': require('../../assets/kyoto/fuji.jpg'),
  'arashiyama-bamboo.mp4': require('../../assets/kyoto/bamboo.jpg'),
};

// Clips with real footage, played by the library's own video block.
// Fushimi Inari, Senbon torii: Nesnad, CC BY-SA 4.0, Wikimedia Commons.
const CLIPS: Record<string, number> = {
  'fushimi-inari-gates.mp4': require('../../assets/kyoto/fushimi-inari-gates.mp4'),
};

// The footage plays edge to edge in the film window, under the strip's overlays.
const FOOTAGE_STYLE: MarkdownStyle = {
  video: {
    aspectRatio: 16 / 9,
    borderRadius: 0,
    marginTop: 0,
    marginBottom: 0,
  },
};

const CLIP_CAPTIONS: Record<string, string> = {
  'fushimi-inari-gates.mp4': 'the gates at 6:40 am',
  'fuji-from-the-train.mp4': 'Fuji, from seat 12E',
  'arashiyama-bamboo.mp4': 'the grove at 7 am',
};

function fileName(url: string) {
  return url.slice(url.lastIndexOf('/') + 1);
}

function photoFor(url: string): ImageSourcePropType {
  return PHOTOS[fileName(url)] ?? { uri: url };
}

// A slot mounts a few frames before the host places it on screen, so every
// entrance waits that out instead of spending its first frames off screen.
const PLACEMENT_DELAY = 100;

const SETTLE = Easing.out(Easing.cubic);
const OVERSHOOT = Easing.out(Easing.back(1.6));
const DEVELOP = Easing.inOut(Easing.quad);

function useEntrance(duration = 800, delay = 0, easing = SETTLE) {
  const instant = useInstant();
  const progress = useSharedValue(instant.current ? 1 : 0);
  useEffect(() => {
    if (instant.current) {
      progress.value = 1;
      return;
    }
    progress.value = withDelay(
      PLACEMENT_DELAY + delay,
      withTiming(1, { duration, easing })
    );
  }, [progress, duration, delay, easing, instant]);
  return progress;
}

function replay(
  progress: SharedValue<number>,
  duration: number,
  delay = 0,
  easing = SETTLE
) {
  progress.value = withSequence(
    withTiming(0, { duration: 0 }),
    withDelay(delay, withTiming(1, { duration, easing }))
  );
}

// A polaroid dropped onto the page that develops from dark to full colour.
function Polaroid({ block }: { block: MarkdownImageBlock }) {
  const tilt = jitter(block.url) * 3;
  const drop = useEntrance(800);
  const develop = useEntrance(1800, 350, DEVELOP);
  const sheen = useEntrance(1100, 1900, Easing.inOut(Easing.cubic));

  const cardStyle = useAnimatedStyle(() => ({
    opacity: drop.value,
    transform: [
      { translateY: interpolate(drop.value, [0, 1], [-28, 0]) },
      { rotate: `${interpolate(drop.value, [0, 1], [tilt * 3, tilt])}deg` },
      { scale: interpolate(drop.value, [0, 1], [1.08, 1]) },
    ],
  }));
  const developStyle = useAnimatedStyle(() => ({
    opacity: 1 - develop.value,
  }));
  const sheenStyle = useAnimatedStyle(() => ({
    opacity: sheen.value > 0 && sheen.value < 1 ? 1 : 0,
    transform: [
      { translateX: interpolate(sheen.value, [0, 1], [-120, 320]) },
      { rotate: '18deg' },
    ],
  }));
  const [open, setOpen] = useState(false);
  const caption = block.title || block.altText;

  return (
    <View style={styles.polaroidSlot}>
      <Tappable
        onPress={() => setOpen(true)}
        label={`Open photo: ${caption}`}
        style={[
          styles.polaroidPress,
          { alignSelf: tilt < 0 ? 'flex-start' : 'flex-end' },
        ]}
      >
        <Animated.View style={[styles.polaroid, cardStyle]}>
          <View style={styles.photoFrame}>
            <Image
              source={photoFor(block.url)}
              style={styles.photo}
              resizeMode="cover"
            />
            <Animated.View
              style={[styles.develop, developStyle]}
              pointerEvents="none"
            />
            <Animated.View
              style={[styles.sheen, sheenStyle]}
              pointerEvents="none"
            >
              <Sheen />
            </Animated.View>
          </View>
          <Text style={styles.polaroidCaption} numberOfLines={1}>
            {caption}
          </Text>
          <View
            style={[
              styles.tape,
              { transform: [{ rotate: `${-tilt * 2 - 3}deg` }] },
            ]}
          />
        </Animated.View>
      </Tappable>
      <Lightbox open={open} onClose={() => setOpen(false)} label="Close photo">
        <Enlarged source={photoFor(block.url)} caption={caption} />
      </Lightbox>
    </View>
  );
}

// The light off the glossy print, once it has come up.
const Sheen = memo(function Sheen() {
  return (
    <Svg width="100%" height="100%">
      <Defs>
        <LinearGradient id="sheen" x1="0" y1="0" x2="1" y2="0">
          <Stop offset="0" stopColor="#FFFFFF" stopOpacity={0} />
          <Stop offset="0.5" stopColor="#FFFFFF" stopOpacity={0.38} />
          <Stop offset="1" stopColor="#FFFFFF" stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#sheen)" />
    </Svg>
  );
});

const ENLARGED_PADDING = 14;
// Everything on the lightbox but the photo: the frame, caption and hint.
const LIGHTBOX_CHROME = 150;

function Enlarged({
  source,
  caption,
}: {
  source: ImageSourcePropType;
  caption: string;
}) {
  const window = useWindowDimensions();
  // As wide as the screen allows, unless that would make the 4:3 photo and
  // its caption taller than the screen, as on an unfolded Duo.
  const width = Math.min(
    window.width - LIGHTBOX_MARGIN * 2,
    (window.height - LIGHTBOX_CHROME) * (4 / 3) + ENLARGED_PADDING * 2
  );
  return (
    <View style={[styles.enlarged, { width }]}>
      <View style={styles.photoFrame}>
        <Image source={source} style={styles.photo} resizeMode="cover" />
      </View>
      <Text style={styles.enlargedCaption}>{caption}</Text>
    </View>
  );
}

const FLICKER = [0.07, 0.02, 0.1, 0, 0.05, 0.01];

const PAN_MS = 7000;
const SWAY = Easing.inOut(Easing.sin);

// A Super 8 strip: real footage when the clip has it, otherwise a slow pan
// over its still that a tap pauses.
function FilmClip({ block }: { block: MarkdownVideoBlock }) {
  const name = fileName(block.url);
  const clip = CLIPS[name];
  return clip ? (
    <Footage source={clip} caption={CLIP_CAPTIONS[name] ?? name} />
  ) : (
    <PannedClip block={block} />
  );
}

// The footage in the strip's window, its player's controls on top, so a tap
// plays it.
function Footage({ source, caption }: { source: number; caption: string }) {
  const enter = useEntrance();
  const stripStyle = useAnimatedStyle(() => ({
    opacity: enter.value,
    transform: [{ translateX: interpolate(enter.value, [0, 1], [60, 0]) }],
  }));
  const uri = Image.resolveAssetSource(source)?.uri ?? '';
  return (
    <Animated.View style={[styles.film, stripStyle]}>
      <Sprockets />
      <View style={styles.filmWindow}>
        <EnrichedMarkdownText
          flavor="github"
          markdown={`<video src="${uri}"></video>`}
          markdownStyle={FOOTAGE_STYLE}
        />
        <Text style={styles.filmCaption} pointerEvents="none">
          {caption}
        </Text>
      </View>
      <Sprockets />
    </Animated.View>
  );
}

function PannedClip({ block }: { block: MarkdownVideoBlock }) {
  const name = fileName(block.url);
  const enter = useEntrance();
  const pan = useSharedValue(0);
  const flicker = useSharedValue(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused) {
      flicker.value = withTiming(0, { duration: 120 });
      return;
    }
    // Resumes towards the far end, then sways across the whole pan again.
    const to = pan.value > 0.5 ? 0 : 1;
    pan.value = withSequence(
      withTiming(to, {
        duration: PAN_MS * Math.abs(to - pan.value),
        easing: SWAY,
      }),
      withRepeat(
        withTiming(1 - to, { duration: PAN_MS, easing: SWAY }),
        -1,
        true
      )
    );
    flicker.value = withRepeat(
      withSequence(
        ...FLICKER.map((toValue, i) =>
          withTiming(toValue, { duration: 60 + i * 23 })
        )
      ),
      -1
    );
    return () => {
      cancelAnimation(pan);
      cancelAnimation(flicker);
    };
  }, [pan, flicker, paused]);

  const stripStyle = useAnimatedStyle(() => ({
    opacity: enter.value,
    transform: [{ translateX: interpolate(enter.value, [0, 1], [60, 0]) }],
  }));
  const imageStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: interpolate(pan.value, [0, 1], [1.12, 1.3]) },
      { translateX: interpolate(pan.value, [0, 1], [18, -18]) },
    ],
  }));
  const flickerStyle = useAnimatedStyle(() => ({ opacity: flicker.value }));

  return (
    <Tappable
      onPress={() => setPaused((value) => !value)}
      label={paused ? 'Play clip' : 'Pause clip'}
    >
      <Animated.View style={[styles.film, stripStyle]}>
        <Sprockets />
        <View style={styles.filmWindow}>
          <Animated.Image
            source={photoFor(block.url)}
            resizeMode="cover"
            style={[styles.filmImage, imageStyle]}
          />
          <Animated.View
            pointerEvents="none"
            style={[styles.filmFlicker, flickerStyle]}
          />
          <FilmHud paused={paused} />
          {paused && (
            <View style={styles.filmPlay}>
              <Text style={styles.filmPlayGlyph}>{'\u25B6\uFE0E'}</Text>
            </View>
          )}
          <Text style={styles.filmCaption}>{CLIP_CAPTIONS[name] ?? name}</Text>
        </View>
        <Sprockets />
      </Animated.View>
    </Tappable>
  );
}

// The ticking counter re-renders only itself; the REC dot blinks on the UI
// thread.
function FilmHud({ paused }: { paused: boolean }) {
  const [seconds, setSeconds] = useState(0);
  const blink = useSharedValue(1);
  useEffect(() => {
    if (paused) return;
    blink.value = withRepeat(
      withSequence(
        withDelay(450, withTiming(0.15, { duration: 80 })),
        withDelay(450, withTiming(1, { duration: 80 }))
      ),
      -1
    );
    const timer = setInterval(() => setSeconds((s) => s + 1), 1000);
    return () => {
      cancelAnimation(blink);
      clearInterval(timer);
    };
  }, [blink, paused]);
  const dotStyle = useAnimatedStyle(() => ({ opacity: blink.value }));

  return (
    <View style={styles.filmHud}>
      {paused ? (
        <Text style={styles.filmPaused}>❚❚</Text>
      ) : (
        <Animated.View style={[styles.recDot, dotStyle]} />
      )}
      <Text style={styles.filmTime}>
        {`00:${String(seconds % 60).padStart(2, '0')}`}
      </Text>
    </View>
  );
}

const Sprockets = memo(function Sprockets() {
  return (
    <View style={styles.sprockets}>
      {Array.from({ length: 14 }, (_, i) => (
        <View key={i} style={styles.sprocket} />
      ))}
    </View>
  );
});

const SEAT_ROWS = [10, 11, 12, 13, 14];
// Window (E) on top, the aisle between D and C.
const SEAT_LETTERS = ['E', 'D', 'C', 'B', 'A'];
const FLIP = Easing.inOut(Easing.cubic);

// "Nozomi 21 · Tokyo → Kyoto" + "07:33 → 09:47 · Car 7 · Seat 12E";
// a tap turns it over to the seat map.
function TrainTicket({ block }: { block: MarkdownLinkBlock }) {
  const [train = '', route = ''] = block.label.split(' · ');
  const [from = '', to = ''] = route.split(' → ');
  const [times = '', car = '', seat = ''] = block.title.split(' · ');
  const [departs = '', arrives = ''] = times.split(' → ');
  const seatId = seat.replace('Seat ', '');
  const enter = useEntrance();
  const punch = useEntrance(400, 800, OVERSHOOT);
  const flip = useSharedValue(0);
  const [flipped, setFlipped] = useState(false);

  useEffect(() => {
    flip.value = withTiming(flipped ? 1 : 0, { duration: 560, easing: FLIP });
  }, [flip, flipped]);

  const ticketStyle = useAnimatedStyle(() => ({
    opacity: enter.value,
    transform: [
      { translateY: interpolate(enter.value, [0, 1], [24, 0]) },
      { rotate: '-1deg' },
    ],
  }));
  const punchStyle = useAnimatedStyle(() => ({
    opacity: punch.value,
    transform: [{ scale: interpolate(punch.value, [0, 1], [2.2, 1]) }],
  }));
  // Each face shows for its half of the turn.
  const frontStyle = useAnimatedStyle(() => ({
    opacity: flip.value < 0.5 ? 1 : 0,
    transform: [{ perspective: 900 }, { rotateY: `${flip.value * 180}deg` }],
  }));
  const backStyle = useAnimatedStyle(() => ({
    opacity: flip.value < 0.5 ? 0 : 1,
    transform: [
      { perspective: 900 },
      { rotateY: `${flip.value * 180 - 180}deg` },
    ],
  }));

  return (
    <Tappable
      onPress={() => setFlipped((value) => !value)}
      label={flipped ? 'Show the ticket' : 'Show the seat map'}
    >
      <Animated.View style={[styles.ticketCard, ticketStyle]}>
        <Animated.View style={[styles.ticket, frontStyle]}>
          <View style={styles.ticketMain}>
            <Text style={styles.ticketKicker}>
              {`のぞみ  ${train.toUpperCase()}  ·  2026.10.18`}
            </Text>
            <View style={styles.ticketRoute}>
              <View>
                <Text style={styles.ticketCity}>{from}</Text>
                <Text style={styles.ticketTime}>{departs}</Text>
              </View>
              <Text style={styles.ticketArrow}>→</Text>
              <View style={styles.ticketTo}>
                <Text style={styles.ticketCity}>{to}</Text>
                <Text style={styles.ticketTime}>{arrives}</Text>
              </View>
            </View>
          </View>
          <View style={styles.ticketStub}>
            <View style={styles.perforation}>
              {Array.from({ length: 9 }, (_, i) => (
                <View key={i} style={styles.perforationDash} />
              ))}
            </View>
            <Text style={styles.stubLabel}>{car.toUpperCase()}</Text>
            <Text style={styles.stubSeat}>{seatId}</Text>
            <Text style={styles.stubNote}>Fuji side!</Text>
            <Animated.View style={[styles.punchHole, punchStyle]} />
          </View>
          <View style={[styles.notch, styles.notchTop]} />
          <View style={[styles.notch, styles.notchBottom]} />
        </Animated.View>
        <Animated.View style={[styles.ticket, styles.ticketBack, backStyle]}>
          <View style={styles.ticketBackNote}>
            <Text style={styles.ticketKicker}>
              {`${car.toUpperCase()}  ·  SEAT MAP`}
            </Text>
            <Text style={styles.ticketBackHand}>
              {`${seatId}, window,\nFuji on your right`}
            </Text>
          </View>
          <View style={styles.seatMap}>
            {SEAT_ROWS.map((row) => (
              <View key={row} style={styles.seatRow}>
                {SEAT_LETTERS.map((letter) => (
                  <View
                    key={letter}
                    style={[
                      styles.seat,
                      letter === 'C' && styles.seatPastAisle,
                      `${row}${letter}` === seatId && styles.seatMine,
                    ]}
                  />
                ))}
                <Text style={styles.seatRowLabel}>{row}</Text>
              </View>
            ))}
          </View>
        </Animated.View>
      </Animated.View>
    </Tappable>
  );
}

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

const ROUTE_STEPS = 16;
const ROUTE = Array.from({ length: ROUTE_STEPS }, (_, i) => {
  // Quadratic curve from the station (top left) to the shrine (bottom right).
  const t = i / (ROUTE_STEPS - 1);
  const x = (1 - t) ** 2 * 62 + 2 * (1 - t) * t * 120 + t ** 2 * 238;
  const y = (1 - t) ** 2 * 34 + 2 * (1 - t) * t * 132 + t ** 2 * 108;
  return { x, y };
});

function Footstep({
  index,
  walk,
}: {
  index: number;
  walk: SharedValue<number>;
}) {
  const animatedProps = useAnimatedProps(() => ({
    opacity: interpolate(
      walk.value,
      [index / ROUTE_STEPS, (index + 1) / ROUTE_STEPS],
      [0, 0.8],
      Extrapolation.CLAMP
    ),
  }));
  const point = ROUTE[index]!;
  return (
    <AnimatedCircle
      cx={point.x}
      cy={point.y}
      r={2.6}
      fill={INK}
      opacity={0}
      animatedProps={animatedProps}
    />
  );
}

// A hand-drawn map: footsteps walk from the station and a pin drops. A tap
// walks it again; the footer link opens the real map.
function MapCard({ block }: { block: MarkdownLinkBlock }) {
  const ll = /[?&]ll=([-\d.]+),([-\d.]+)/.exec(block.url);
  const enter = useEntrance(700);
  const walk = useEntrance(1500, 300, Easing.linear);
  const pin = useEntrance(500, 1550, OVERSHOOT);
  const walkAgain = () => {
    replay(walk, 1500, 0, Easing.linear);
    replay(pin, 500, 1250, OVERSHOOT);
  };

  const cardStyle = useAnimatedStyle(() => ({
    opacity: enter.value,
    transform: [{ scale: interpolate(enter.value, [0, 1], [0.94, 1]) }],
  }));
  const pinStyle = useAnimatedStyle(() => ({
    opacity: pin.value,
    transform: [{ translateY: interpolate(pin.value, [0, 1], [-36, 0]) }],
  }));

  return (
    <Tappable onPress={walkAgain} label={`Walk to ${block.label} again`}>
      <Animated.View style={[styles.map, cardStyle]}>
        <View style={styles.mapCanvas}>
          <Svg width="100%" height="100%" viewBox="0 0 300 150">
            {[30, 70, 110].map((y) => (
              <Path
                key={`h${y}`}
                d={`M0 ${y} L300 ${y + 8}`}
                stroke={INK_SOFT}
                strokeOpacity={0.18}
                strokeWidth={1.2}
              />
            ))}
            {[40, 110, 190, 260].map((x) => (
              <Path
                key={`v${x}`}
                d={`M${x} 0 L${x - 10} 150`}
                stroke={INK_SOFT}
                strokeOpacity={0.18}
                strokeWidth={1.2}
              />
            ))}
            <Path
              d="M150 -5 C140 40 175 70 158 100 S150 140 165 160"
              stroke={RIVER}
              strokeWidth={9}
              strokeOpacity={0.55}
              fill="none"
              strokeLinecap="round"
            />
            <Path
              d="M222 150 C228 112 262 96 300 104 L300 150 Z"
              fill={MOSS}
              fillOpacity={0.35}
            />
            {ROUTE.map((_, i) => (
              <Footstep key={i} index={i} walk={walk} />
            ))}
            <Circle
              cx={62}
              cy={34}
              r={6}
              fill={PAPER}
              stroke={INK}
              strokeWidth={2}
            />
          </Svg>
          <Text style={[styles.mapLabel, { left: 16, top: 50 }]}>
            Kyoto Sta.
          </Text>
          <Text style={[styles.mapLabel, styles.mapRiver]}>Kamo-gawa</Text>
          <Text style={[styles.mapLabel, { right: 12, bottom: 6 }]}>
            Inari-san
          </Text>
          <Animated.View style={[styles.pin, pinStyle]}>
            <View style={styles.pinHead}>
              <Text style={styles.pinGlyph}>⛩</Text>
            </View>
            <View style={styles.pinTip} />
          </Animated.View>
        </View>
        <View style={styles.mapFooter}>
          <Text style={styles.mapName}>{block.label}</Text>
          {ll && (
            <Text style={styles.mapCoords}>
              {`${Number(ll[1]).toFixed(4)}° N  ·  ${Number(ll[2]).toFixed(4)}° E`}
            </Text>
          )}
          {!!block.title && <Text style={styles.mapHint}>{block.title}</Text>}
          <Pressable
            onPress={() => Linking.openURL(block.url)}
            hitSlop={10}
            accessibilityRole="link"
            style={styles.mapOpen}
          >
            <Text style={styles.mapOpenText}>MAPS ↗</Text>
          </Pressable>
        </View>
      </Animated.View>
    </Tappable>
  );
}

// A seal comes down out of the air, presses into the paper with a little give,
// and leaves its ink a shade lighter than the pad.
function useThump(progress: SharedValue<number>, rotate: string) {
  return useAnimatedStyle(() => ({
    opacity: interpolate(
      progress.value,
      [0, 0.55, 0.75, 1],
      [0, 0.95, 0.92, 0.86],
      'clamp'
    ),
    transform: [
      {
        scale: interpolate(
          progress.value,
          [0, 0.6, 0.78, 1],
          [1.45, 1, 0.965, 1],
          'clamp'
        ),
      },
      { rotate },
    ],
  }));
}

// The brush's pace, a character at a time, the right-hand column first.
const BRUSH_MS = 85;
const BRUSH_DELAY = 350;
const STAMP_MS = 520;
const PRESS = Easing.inOut(Easing.quad);

// A goshuin page: the brush writes the columns right to left, then the
// temple's red seals press down and the page gives under them. A tap stamps
// them again.
function TempleSeal({ block }: { block: MarkdownLinkBlock }) {
  const name = block.title || block.label;
  const columns = ['奉拝', name, '令和八年十月十八日'];
  const strokes = columns.reduce(
    (sum, text) => sum + Array.from(text).length,
    0
  );
  const written = BRUSH_DELAY + strokes * BRUSH_MS;

  const page = useEntrance(700);
  const brush = useEntrance(strokes * BRUSH_MS, BRUSH_DELAY, Easing.linear);
  const seal = useEntrance(STAMP_MS, written + 150, PRESS);
  const smallSeal = useEntrance(STAMP_MS - 60, written + 520, PRESS);
  const stampAgain = () => {
    replay(seal, STAMP_MS, 0, PRESS);
    replay(smallSeal, STAMP_MS - 60, 380, PRESS);
  };

  const pageStyle = useAnimatedStyle(() => ({
    opacity: page.value,
    transform: [{ translateY: interpolate(page.value, [0, 1], [20, 0]) }],
  }));
  // The page sinks a hair as each seal lands.
  const giveStyle = useAnimatedStyle(() => {
    const press = (p: number) =>
      interpolate(p, [0.5, 0.65, 0.95], [0, 1, 0], 'clamp');
    return {
      transform: [
        {
          scale: 1 - (press(seal.value) + press(smallSeal.value) * 0.6) * 0.012,
        },
      ],
    };
  });
  const sealStyle = useThump(seal, '4deg');
  const smallSealStyle = useThump(smallSeal, '-8deg');

  // Columns sit right to left, so the first written is drawn last.
  let first = 0;
  const placed = columns.map((text) => {
    const column = { text, first };
    first += Array.from(text).length;
    return column;
  });

  return (
    <Animated.View style={[styles.goshuinRow, pageStyle]}>
      <Tappable
        onPress={stampAgain}
        label={`Stamp the ${block.label} seals again`}
      >
        <Animated.View style={[styles.goshuin, giveStyle]}>
          <Animated.View style={[styles.sealSquare, sealStyle]}>
            <Text style={styles.sealSquareText}>佛法僧寶</Text>
          </Animated.View>
          <Animated.View style={[styles.sealRound, smallSealStyle]}>
            <Text style={styles.sealRoundText}>音羽</Text>
          </Animated.View>
          {placed
            .slice()
            .reverse()
            .map((column, i) => (
              <VerticalText
                key={column.text}
                text={column.text}
                first={column.first}
                total={strokes}
                brush={brush}
                style={i === 1 ? styles.brushLarge : styles.brushSmall}
              />
            ))}
        </Animated.View>
      </Tappable>
      <View style={styles.goshuinNote}>
        <Text style={styles.goshuinTitle}>{block.label}</Text>
        <Text style={styles.goshuinHand}>
          {'goshuin, ¥500\nbrushed while you wait'}
        </Text>
        <Text style={styles.goshuinUrl} numberOfLines={1}>
          {block.url.replace(/^https?:\/\/(www\.)?/, '')}
        </Text>
      </View>
    </Animated.View>
  );
}

function VerticalText({
  text,
  first,
  total,
  brush,
  style,
}: {
  text: string;
  first: number;
  total: number;
  brush: SharedValue<number>;
  style: object;
}) {
  return (
    <View style={styles.vertical}>
      {Array.from(text).map((char, i) => (
        <BrushStroke
          key={i}
          char={char}
          index={first + i}
          total={total}
          brush={brush}
          style={style}
        />
      ))}
    </View>
  );
}

// One character soaking into the paper as the brush reaches it.
function BrushStroke({
  char,
  index,
  total,
  brush,
  style,
}: {
  char: string;
  index: number;
  total: number;
  brush: SharedValue<number>;
  style: object;
}) {
  const inkStyle = useAnimatedStyle(() => {
    const k = Math.min(1, Math.max(0, brush.value * total - index));
    return {
      opacity: k,
      transform: [{ scale: 1.12 - k * 0.12 }, { translateY: (1 - k) * -2 }],
    };
  });
  return <Animated.Text style={[style, inkStyle]}>{char}</Animated.Text>;
}

// Named by hand: function names do not survive minification.
const CODE_RENDERERS = {
  rail: { name: 'RailLine', Renderer: RailLine },
  mermaid: { name: 'Mermaid', Renderer: Mermaid },
};

type Language = keyof typeof CODE_RENDERERS;

function isLanguage(language: string): language is Language {
  return language in CODE_RENDERERS;
}

const LINK_RENDERERS = [
  { host: 'smart-ex.jp', name: 'TrainTicket', Renderer: TrainTicket },
  { host: 'maps.apple.com', name: 'MapCard', Renderer: MapCard },
  { host: 'kiyomizudera', name: 'TempleSeal', Renderer: TempleSeal },
];

function linkRenderer(url: string) {
  return LINK_RENDERERS.find(({ host }) => url.includes(host));
}

export const journalRenderers: MarkdownRenderers = {
  image: (block) => <Polaroid block={block} />,
  video: (block) => <FilmClip block={block} />,
  link: (block) => {
    const Renderer = linkRenderer(block.url)?.Renderer;
    return Renderer ? <Renderer block={block} /> : undefined;
  },
  code: (block) => {
    if (!isLanguage(block.language)) return undefined;
    const { Renderer } = CODE_RENDERERS[block.language];
    return <Renderer block={block} />;
  },
};

// The component a line of the source becomes, by the same rules as above,
// for the Duo's source page; null for a line that stays text.
export function rendererFor(line: string) {
  const fence = line.match(/^```(\w+)/)?.[1];
  if (fence) return isLanguage(fence) ? CODE_RENDERERS[fence].name : null;
  if (line.startsWith('![')) return 'Polaroid';
  if (line.startsWith('<video')) return 'FilmClip';
  const target = line.match(/^\[[^\]]*\]\(([^\s)]+)/)?.[1];
  return target ? (linkRenderer(target)?.name ?? null) : null;
}

const styles = StyleSheet.create({
  // The markdown view clips its content, so cards keep their shadows inside it.
  polaroidSlot: {
    paddingVertical: 8,
    paddingHorizontal: 12,
  },
  polaroidPress: {
    width: '86%',
  },
  polaroid: {
    backgroundColor: '#FFFDF8',
    padding: 10,
    paddingBottom: 6,
    borderRadius: 2,
    shadowColor: '#3B2A1A',
    shadowOpacity: 0.22,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 6,
  },
  photoFrame: {
    aspectRatio: 4 / 3,
    overflow: 'hidden',
    backgroundColor: '#2E2722',
  },
  photo: {
    width: '100%',
    height: '100%',
  },
  develop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: '#3A3129',
  },
  sheen: {
    position: 'absolute',
    top: '-30%',
    bottom: '-30%',
    left: 0,
    width: 90,
  },
  polaroidCaption: {
    fontFamily: FONTS.hand,
    fontSize: 25,
    color: INK,
    marginTop: 4,
    marginLeft: 4,
  },
  enlarged: {
    backgroundColor: '#FFFDF8',
    padding: ENLARGED_PADDING,
    paddingBottom: 8,
    borderRadius: 2,
  },
  enlargedCaption: {
    fontFamily: FONTS.hand,
    fontSize: 32,
    color: INK,
    marginTop: 6,
    marginLeft: 4,
  },
  tape: {
    position: 'absolute',
    top: -12,
    left: '38%',
    width: 84,
    height: 26,
    backgroundColor: 'rgba(222, 205, 160, 0.78)',
  },
  film: {
    marginHorizontal: 10,
    backgroundColor: '#17120F',
    borderRadius: 6,
    paddingHorizontal: 8,
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 5 },
    elevation: 5,
  },
  sprockets: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6,
    paddingHorizontal: 2,
  },
  sprocket: {
    width: 11,
    height: 8,
    borderRadius: 2,
    backgroundColor: PAPER,
    opacity: 0.85,
  },
  filmWindow: {
    aspectRatio: 16 / 9,
    overflow: 'hidden',
    borderRadius: 3,
    backgroundColor: '#000',
  },
  filmImage: {
    width: '100%',
    height: '100%',
  },
  filmFlicker: {
    ...StyleSheet.absoluteFill,
    backgroundColor: '#FFF4D6',
  },
  filmHud: {
    position: 'absolute',
    top: 10,
    left: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  recDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#FF4A3A',
  },
  filmTime: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    color: '#FFE9B0',
    letterSpacing: 1,
  },
  filmPaused: {
    fontSize: 10,
    color: '#FFE9B0',
    letterSpacing: -1,
  },
  filmPlay: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    width: 56,
    height: 56,
    marginTop: -28,
    borderRadius: 28,
    backgroundColor: 'rgba(23, 18, 15, 0.55)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  filmPlayGlyph: {
    fontSize: 22,
    color: '#FFF8E8',
    marginLeft: 4,
  },
  filmCaption: {
    position: 'absolute',
    right: 12,
    bottom: 6,
    fontFamily: FONTS.handBold,
    fontSize: 24,
    color: '#FFF8E8',
    textShadowColor: 'rgba(0,0,0,0.6)',
    textShadowRadius: 6,
  },
  ticketCard: {
    marginVertical: 4,
  },
  ticket: {
    flexDirection: 'row',
    backgroundColor: '#DCEDE6',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#B7D3C8',
    overflow: 'hidden',
  },
  ticketBack: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  ticketBackNote: {
    flex: 1,
  },
  ticketBackHand: {
    fontFamily: FONTS.handBold,
    fontSize: 21,
    lineHeight: 23,
    color: VERMILION,
    marginTop: 6,
  },
  seatMap: {
    flexDirection: 'row',
    gap: 5,
  },
  seatRow: {
    alignItems: 'center',
    gap: 3,
  },
  seat: {
    width: 13,
    height: 10,
    borderRadius: 2,
    borderWidth: 1,
    borderColor: '#9DC2B4',
  },
  seatPastAisle: {
    marginTop: 7,
  },
  seatMine: {
    backgroundColor: VERMILION,
    borderColor: VERMILION,
  },
  seatRowLabel: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    color: '#3E6B5C',
    marginTop: 2,
  },
  ticketMain: {
    flex: 1,
    paddingVertical: 14,
    paddingLeft: 16,
    paddingRight: 10,
  },
  ticketKicker: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: '#3E6B5C',
    letterSpacing: 0.6,
  },
  ticketRoute: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  ticketTo: {
    alignItems: 'flex-end',
  },
  ticketCity: {
    fontFamily: FONTS.display,
    fontSize: 26,
    color: INK,
  },
  ticketTime: {
    fontFamily: FONTS.monoMedium,
    fontSize: 15,
    color: '#3E6B5C',
    marginTop: 2,
  },
  ticketArrow: {
    flex: 1,
    textAlign: 'center',
    fontFamily: FONTS.mono,
    fontSize: 22,
    color: VERMILION,
  },
  ticketStub: {
    width: 92,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
  },
  // A dashed border on one side is not drawn by the new renderer on iOS.
  perforation: {
    position: 'absolute',
    left: 0,
    top: 4,
    bottom: 4,
    justifyContent: 'space-between',
  },
  perforationDash: {
    width: 2,
    height: 6,
    borderRadius: 1,
    backgroundColor: '#9DC2B4',
  },
  stubLabel: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: '#3E6B5C',
    letterSpacing: 1,
  },
  stubSeat: {
    fontFamily: FONTS.display,
    fontSize: 30,
    color: INK,
  },
  stubNote: {
    fontFamily: FONTS.handBold,
    fontSize: 19,
    color: VERMILION,
    transform: [{ rotate: '-6deg' }],
  },
  punchHole: {
    position: 'absolute',
    top: 8,
    right: 10,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: PAPER,
    borderWidth: 1,
    borderColor: '#9DC2B4',
  },
  notch: {
    position: 'absolute',
    right: 83,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: PAPER,
    borderWidth: 1,
    borderColor: '#B7D3C8',
  },
  notchTop: { top: -10 },
  notchBottom: { bottom: -10 },
  map: {
    backgroundColor: '#F1E7D3',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#E0D2B6',
    overflow: 'hidden',
    marginVertical: 4,
  },
  mapCanvas: {
    aspectRatio: 2,
  },
  mapLabel: {
    position: 'absolute',
    fontFamily: FONTS.hand,
    fontSize: 19,
    color: INK_SOFT,
  },
  mapRiver: {
    left: '56%',
    top: 8,
    color: '#5B8798',
  },
  pin: {
    position: 'absolute',
    left: '79.3%',
    top: '72%',
    marginLeft: -17,
    marginTop: -44,
    alignItems: 'center',
  },
  pinHead: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: VERMILION,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  },
  pinGlyph: {
    fontSize: 16,
    color: '#FFF',
  },
  pinTip: {
    width: 0,
    height: 0,
    borderLeftWidth: 7,
    borderRightWidth: 7,
    borderTopWidth: 10,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderTopColor: VERMILION,
    marginTop: -2,
  },
  mapFooter: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: '#E0D2B6',
    backgroundColor: '#F7EFDF',
  },
  mapName: {
    fontFamily: FONTS.display,
    fontSize: 19,
    color: INK,
  },
  mapCoords: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: INK_SOFT,
    marginTop: 2,
    letterSpacing: 0.4,
  },
  mapOpen: {
    position: 'absolute',
    top: 14,
    right: 16,
  },
  mapOpenText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1,
    color: VERMILION,
  },
  mapHint: {
    fontFamily: FONTS.hand,
    fontSize: 20,
    color: VERMILION,
    marginTop: 2,
  },
  goshuinRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginVertical: 4,
    paddingHorizontal: 10,
  },
  goshuin: {
    width: 132,
    height: 188,
    backgroundColor: '#FFFCF4',
    borderWidth: 1,
    borderColor: '#E4D8C0',
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    paddingVertical: 12,
    shadowColor: '#3B2A1A',
    shadowOpacity: 0.14,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  vertical: {
    alignItems: 'center',
  },
  brushLarge: {
    fontFamily: FONTS.mincho,
    fontSize: 34,
    lineHeight: 40,
    color: '#1B1612',
    fontWeight: '600',
  },
  brushSmall: {
    fontFamily: FONTS.mincho,
    fontSize: 11,
    lineHeight: 14,
    color: '#1B1612',
  },
  sealSquare: {
    position: 'absolute',
    top: 54,
    left: 34,
    width: 64,
    height: 64,
    borderWidth: 3,
    borderColor: VERMILION,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 6,
  },
  sealSquareText: {
    fontFamily: FONTS.mincho,
    fontSize: 20,
    lineHeight: 22,
    color: VERMILION,
    textAlign: 'center',
    fontWeight: '700',
  },
  sealRound: {
    position: 'absolute',
    top: 10,
    right: 8,
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: VERMILION,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sealRoundText: {
    fontFamily: FONTS.mincho,
    fontSize: 11,
    color: '#FFF4EC',
    fontWeight: '700',
  },
  goshuinNote: {
    flex: 1,
  },
  goshuinTitle: {
    fontFamily: FONTS.display,
    fontSize: 21,
    color: INK,
  },
  goshuinHand: {
    fontFamily: FONTS.hand,
    fontSize: 21,
    lineHeight: 23,
    color: VERMILION,
    marginTop: 4,
  },
  goshuinUrl: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: INK_SOFT,
    marginTop: 8,
  },
});
